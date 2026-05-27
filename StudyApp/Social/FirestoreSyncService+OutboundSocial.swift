// FirestoreSyncService+OutboundSocial — the social-graph + chat write path:
// mutual friendship links, group membership (memberUids back the security
// rules), chat messages, and UGC content reports. Split out of
// FirestoreSyncService+Outbound.swift to keep each file focused and under the
// line limit; the profile + private-data backup writes stay there.

import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore
import StudyCore

extension FirestoreSyncService {
    // MARK: - Mutual friendship

    /// Writes the friendship to *both* users' `users/{uid}/friends/{otherUid}`
    /// subcollections so the other side sees the connection without any
    /// manual accept step. The hardened rules only allow writing an entry that
    /// identifies the caller, so neither side can forge arbitrary links.
    func publishMutualFriendship(
        meUid: String, meCode: String, meNick: String,
        otherUid: String, otherCode: String, otherNick: String
    ) async throws {
        let outgoing: [String: Any] = [
            "uid": otherUid, "friendCode": otherCode, "nickname": otherNick,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        let incoming: [String: Any] = [
            "uid": meUid, "friendCode": meCode, "nickname": meNick,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        let usersRef = db.collection("users")
        try await usersRef.document(meUid).collection("friends")
            .document(otherUid).setData(outgoing, merge: true)
        try await usersRef.document(otherUid).collection("friends")
            .document(meUid).setData(incoming, merge: true)
    }

    /// Removes the friendship from *only the caller's* side. The other user
    /// keeps the row in their list; this matches Kakao/Line semantics where
    /// "delete friend" is a personal hide, not a mutual unlink.
    func deleteFriendship(meUid: String, otherUid: String) async throws {
        try await db.collection("users").document(meUid)
            .collection("friends").document(otherUid).delete()
    }

    // MARK: - Group membership

    /// Removes a user from a group's roster server-side. When the last member
    /// leaves the group doc itself is deleted to avoid orphans.
    func updateGroupMembers(groupId: UUID, members: [String]) async throws {
        let ref = db.collection("groups").document(groupId.uuidString)
        if members.isEmpty {
            try await ref.delete()
        } else {
            var data: [String: Any] = ["memberCodes": members]
            // Drop our own auth UID from the rules-backing list when leaving so
            // we lose chat read access; arrayRemove targets only ours, so the
            // remaining members keep theirs.
            if let myUid = uid {
                data["memberUids"] = FieldValue.arrayRemove([myUid])
            }
            try await ref.setData(data, merge: true)
        }
    }

    /// Awaitable variant — callers (createGroup / joinGroup) need to know
    /// the server doc actually landed before another device can join by code.
    /// Fire-and-forget here would race the user re-typing the code on the
    /// other phone before publish completes.
    func publishGroup(_ group: StudyGroupModel) async throws {
        guard let myUid = uid else {
            throw FirestoreSyncError.notSignedIn
        }
        let id = group.id.uuidString
        let data: [String: Any] = [
            "id": id, "code": group.code, "name": group.name,
            "memberCodes": group.memberCodes,
            // Auth UIDs back the security rules — friendCode is public and so
            // can't be a trust boundary. We union our own UID with any we
            // already know (a DM seeds the friend's UID so they join as a
            // member, not via self-join, which the rules forbid for DMs).
            // arrayUnion never clobbers UIDs other members wrote and backfills
            // legacy group docs the first time a member opens them.
            "memberUids": FieldValue.arrayUnion(Array(Set(group.memberUids + [myUid]))),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await db.collection("groups").document(id).setData(data, merge: true)
    }

    /// Restricted self-join write: adds ONLY our own uid + friendCode to a room,
    /// which is exactly what the rules' `isRoomSelfJoin` branch accepts (no
    /// name/code tampering). Used both when joining by code and to backfill our
    /// membership when opening a room we're already in. For a DM the opener is
    /// already a member, so this lands via the member-edit branch instead.
    func joinGroupAddSelf(groupId: UUID, myUid: String, myCode: String) async throws {
        try await db.collection("groups").document(groupId.uuidString).setData([
            "memberUids": FieldValue.arrayUnion([myUid]),
            "memberCodes": FieldValue.arrayUnion([myCode]),
            "updatedAt": FieldValue.serverTimestamp(),
        ], merge: true)
    }

    /// Registers the join code → group id mapping (create-once; the rules
    /// reject overwrites and require the caller to be a member of `gid`).
    /// REQUIRED at group creation — createGroup rolls back if this throws, so a
    /// room is never left un-joinable by code. The GroupChatView re-register on
    /// open is best-effort (legacy-room backfill).
    func publishGroupCode(code: String, gid: String) async throws {
        try await db.collection("groupCodes").document(code).setData([
            "gid": gid,
            "createdAt": FieldValue.serverTimestamp(),
        ])
    }

    // MARK: - Chat messages

    func publishMessage(_ msg: ChatMessageModel) async throws {
        guard let myUid = uid else { throw FirestoreSyncError.notSignedIn }
        let data: [String: Any] = [
            "id": msg.id.uuidString,
            "groupId": msg.groupId.uuidString,
            "senderFriendCode": msg.senderFriendCode,
            // Server-verifiable author identity. The rules require this to equal
            // request.auth.uid on create, so a group member can't forge another
            // member's senderFriendCode.
            "senderUid": myUid,
            "text": msg.text,
            "sentAt": msg.sentAt.timeIntervalSince1970,
            "attachedKind": msg.attachedKindRaw as Any,
            "attachedSummary": msg.attachedRecordSummary as Any,
            "attachedPayload": msg.attachedPayloadJSON as Any,
        ]
        let gid = msg.groupId.uuidString
        let mid = msg.id.uuidString
        try await db.collection("chats").document(gid)
            .collection("messages").document(mid).setData(data, merge: true)
    }

    // MARK: - Content reports (UGC moderation)

    /// Mirrors a content report to a top-level `reports` collection that only
    /// the operator reads (via the Firebase console). Apple UGC guideline 1.2
    /// requires reports to actually reach the operator — a local `isReported`
    /// flag is invisible to us. Fire-and-forget: the local flag already gave
    /// the reporter feedback, so a dropped report isn't worth blocking the UI.
    func publishReport(
        messageID: String, groupID: String,
        senderFriendCode: String, text: String, summary: String?
    ) {
        guard let reporterUid = uid else { return }
        let data: [String: Any] = [
            "reporterUid": reporterUid,
            "messageId": messageID,
            "groupId": groupID,
            "senderFriendCode": senderFriendCode,
            "text": text,
            "summary": summary as Any,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        Task {
            do {
                _ = try await db.collection("reports").addDocument(data: data)
            } catch {
                Persistence.log(error, context: "firestore.publishReport")
            }
        }
    }
}
