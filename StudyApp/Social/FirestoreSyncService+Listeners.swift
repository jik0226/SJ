// FirestoreSyncService+Listeners — realtime listeners + code lookups.
//
// Split out of the core file: friends/groups/chat snapshot listeners, the
// inbox sync that watches every group I belong to, and the friend/group
// code lookups. These call each other (apply* helpers stay private to this
// file). Stored properties they touch (db, groupListeners, friendsListener,
// myGroupsListener) live on the core type.

import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore
import StudyCore

extension FirestoreSyncService {

    // MARK: - Friends listener

    /// Starts a snapshot listener on the current user's `friends` subcollection.
    /// Each incoming doc that doesn't yet have a matching FriendProfileModel
    /// gets mirrored into SwiftData so the friends list updates in real time.
    /// Idempotent — re-calling stops the previous listener first.
    func startListeningFriends(context: ModelContext) {
        guard let uid else { return }
        friendsListener?.remove()
        friendsListener = db.collection("users").document(uid)
            .collection("friends")
            .addSnapshotListener { [weak self] snap, error in
                if let error {
                    Persistence.log(error, context: "firestore.friendsListener")
                    return
                }
                guard let docs = snap?.documentChanges else { return }
                Task { @MainActor in
                    self?.applyIncomingFriends(docs, context: context)
                }
            }
    }

    func stopListeningFriends() {
        friendsListener?.remove()
        friendsListener = nil
    }

    // MARK: - Inbox: all my groups (incl. DMs)

    /// Subscribes to every group whose `memberCodes` contains my friendCode —
    /// including 1:1 DM groups created by the *other* person. New/updated
    /// groups are mirrored into local SwiftData, and each one gets a message
    /// listener so an incoming DM lands as an unread thread without me having
    /// to open it first. This is what makes "친구가 먼저 말 걸기"가 동작.
    func startListeningMyGroups(myFriendCode: String, context: ModelContext) {
        guard Auth.auth().currentUser != nil, !myFriendCode.isEmpty else { return }
        myGroupsListener?.remove()
        myGroupsListener = db.collection("groups")
            .whereField("memberCodes", arrayContains: myFriendCode)
            .addSnapshotListener { [weak self] snap, error in
                if let error {
                    Persistence.log(error, context: "firestore.myGroupsListener")
                    return
                }
                guard let docs = snap?.documents else { return }
                Task { @MainActor in
                    self?.applyIncomingGroups(docs, context: context)
                }
            }
    }

    func stopListeningMyGroups() {
        myGroupsListener?.remove()
        myGroupsListener = nil
        for (_, l) in groupListeners { l.remove() }
        groupListeners.removeAll()
    }

    private func applyIncomingGroups(
        _ docs: [QueryDocumentSnapshot], context: ModelContext
    ) {
        for doc in docs {
            let data = doc.data()
            guard let idString = data["id"] as? String,
                  let gid = UUID(uuidString: idString) else { continue }
            let code = data["code"] as? String ?? ""
            let name = data["name"] as? String ?? "그룹"
            let members = data["memberCodes"] as? [String] ?? []

            let predicate = #Predicate<StudyGroupModel> { $0.id == gid }
            if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
                existing.memberCodes = members
                if existing.name != name, !code.hasPrefix(SocialService.directMessageCodePrefix) {
                    existing.name = name
                }
            } else {
                context.insert(StudyGroupModel(
                    id: gid, code: code, name: name, memberCodes: members
                ))
            }
            // Attach a message listener to this group if not already watching.
            if groupListeners[gid] == nil {
                attachMessageListener(groupId: gid, context: context)
            }
        }
        Persistence.save({ try context.save() }, context: "firestore.applyIncomingGroups")
    }

    /// Lower-level message listener keyed by groupId (used by inbox sync).
    /// `startListening(group:)` reuses this so a thread the user opens and a
    /// thread discovered via inbox share one registration.
    private func attachMessageListener(groupId: UUID, context: ModelContext) {
        groupListeners[groupId]?.remove()
        let listener = db.collection("chats").document(groupId.uuidString)
            .collection("messages")
            .order(by: "sentAt")
            .addSnapshotListener { [weak self] snap, error in
                if let error {
                    Persistence.log(error, context: "firestore.chatListener")
                    return
                }
                guard let changes = snap?.documentChanges else { return }
                Task { @MainActor in
                    self?.applyIncomingMessages(changes, groupId: groupId, context: context)
                }
            }
        groupListeners[groupId] = listener
    }

    private func applyIncomingFriends(
        _ changes: [DocumentChange], context: ModelContext
    ) {
        for change in changes where change.type == .added || change.type == .modified {
            let data = change.document.data()
            guard let code = data["friendCode"] as? String else { continue }
            let nickname = data["nickname"] as? String ?? "친구"
            let predicate = #Predicate<FriendProfileModel> { $0.friendCode == code }
            if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
                // Refresh nickname in case the other side renamed.
                if existing.nickname.hasPrefix("(데모)") || existing.nickname != nickname {
                    existing.nickname = nickname
                }
                continue
            }
            context.insert(FriendProfileModel(
                friendCode: code,
                nickname: nickname,
                mascotSpecies: .cat,
                mascotStage: 0
            ))
        }
        Persistence.save({ try context.save() }, context: "firestore.applyIncomingFriends")
    }

    // MARK: - Lookups

    func lookupFriend(byCode code: String) async -> LookupOutcome<RemoteFriend> {
        guard Auth.auth().currentUser != nil else { return .error(.unauthenticated) }
        do {
            let snap = try await db.collection("users")
                .whereField("friendCode", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()
            guard let doc = snap.documents.first else { return .notFound }
            return .found(RemoteFriend(
                uid: doc.data()["uid"] as? String ?? doc.documentID,
                friendCode: code,
                nickname: doc.data()["nickname"] as? String ?? "친구"
            ))
        } catch {
            Persistence.log(error, context: "firestore.lookupFriend")
            return .error(.from(error))
        }
    }

    func lookupGroup(byCode code: String) async -> LookupOutcome<RemoteGroup> {
        guard Auth.auth().currentUser != nil else { return .error(.unauthenticated) }
        do {
            let snap = try await db.collection("groups")
                .whereField("code", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()
            guard let doc = snap.documents.first else { return .notFound }
            let idString = doc.data()["id"] as? String ?? doc.documentID
            guard let uuid = UUID(uuidString: idString) else { return .notFound }
            return .found(RemoteGroup(
                id: uuid,
                code: code,
                name: doc.data()["name"] as? String ?? "그룹",
                memberCodes: doc.data()["memberCodes"] as? [String] ?? []
            ))
        } catch {
            Persistence.log(error, context: "firestore.lookupGroup")
            return .error(.from(error))
        }
    }

    // MARK: - Per-thread chat listener (opened thread)

    func startListening(group: StudyGroupModel, context: ModelContext) {
        guard Auth.auth().currentUser != nil else { return }
        // Reuse the shared message-listener path. If the inbox sync already
        // attached one for this group, this refreshes it harmlessly.
        attachMessageListener(groupId: group.id, context: context)
    }

    /// Only tears down a per-thread listener when the inbox sync isn't the
    /// owner. With inbox sync active we keep listeners alive so unread DMs
    /// keep arriving in the background; the global stopListeningMyGroups
    /// handles teardown on sign-out.
    func stopListening(group: StudyGroupModel) {
        guard myGroupsListener == nil else { return }
        groupListeners[group.id]?.remove()
        groupListeners.removeValue(forKey: group.id)
    }

    private func applyIncomingMessages(
        _ changes: [DocumentChange], groupId: UUID, context: ModelContext
    ) {
        for change in changes where change.type == .added {
            let data = change.document.data()
            guard let idString = data["id"] as? String,
                  let msgId = UUID(uuidString: idString),
                  let sender = data["senderFriendCode"] as? String,
                  let text = data["text"] as? String,
                  let sentInterval = data["sentAt"] as? TimeInterval
            else { continue }
            let predicate = #Predicate<ChatMessageModel> { $0.id == msgId }
            let exists = (try? context.fetch(FetchDescriptor(predicate: predicate)).first) != nil
            if exists { continue }
            let mirrored = ChatMessageModel(
                id: msgId,
                groupId: groupId,
                senderFriendCode: sender,
                text: text,
                sentAt: Date(timeIntervalSince1970: sentInterval),
                attachedRecordSummary: data["attachedSummary"] as? String,
                attachedKind: (data["attachedKind"] as? String).flatMap(AttachedKind.init(rawValue:)),
                attachedPayloadJSON: data["attachedPayload"] as? String
            )
            context.insert(mirrored)
        }
        Persistence.save({ try context.save() }, context: "firestore.applyIncoming")
    }
}
