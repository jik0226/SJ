// SocialService+Groups — create/join/leave study groups and the deterministic
// 1:1 DM channel. Each mutating op mirrors to Firestore and rolls back the
// local row if the server publish fails, so no group is left unreachable.

import Foundation
import SwiftData
import CryptoKit
import StudyCore

extension SocialService {
    // MARK: - Study Groups

    /// Creates a new study group with the current user as the sole initial
    /// member. Awaits the Firestore publish so the join code is resolvable
    /// from another device the moment this returns. If the server publish
    /// fails after the local insert succeeded, the local group is rolled back
    /// to avoid orphan rows the other side can never reach.
    @discardableResult
    static func createGroup(name: String, in context: ModelContext) async throws -> StudyGroupModel {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialError.emptyGroupName }
        let me = me(in: context)
        let myUid = AuthBootstrap.shared.currentUID ?? ""
        let group = StudyGroupModel(
            code: GroupCode.generate(),
            name: trimmed,
            memberCodes: [me.friendCode],
            memberUids: myUid.isEmpty ? [] : [myUid]
        )
        context.insert(group)
        guard Persistence.save({ try context.save() }, context: "group.create") != nil else {
            context.delete(group)
            throw SocialError.saveFailed
        }
        do {
            try await FirestoreSyncService.shared.publishGroup(group)
        } catch {
            // Server publish failed (auth not ready, rules deny, network).
            // Roll back the local row too — otherwise the user sees a group
            // in their list that no one else can join, which is the exact
            // confusion we just hit during testing.
            context.delete(group)
            Persistence.save({ try context.save() }, context: "group.create.rollback")
            Persistence.log(error, context: "firestore.publishGroup.create")
            throw SocialError.serverPublishFailed
        }
        // Register the join-code → gid mapping so others can resolve the code
        // without reading the (member-only) group doc. REQUIRED for A안 — a room
        // no one can join by code is worse than no room — so a failure rolls the
        // whole creation back (delete the server doc + local row).
        do {
            try await FirestoreSyncService.shared.publishGroupCode(
                code: group.code, gid: group.id.uuidString
            )
        } catch {
            try? await FirestoreSyncService.shared.updateGroupMembers(groupId: group.id, members: [])
            context.delete(group)
            Persistence.save({ try context.save() }, context: "group.create.code.rollback")
            Persistence.log(error, context: "firestore.publishGroupCode.create")
            throw SocialError.serverPublishFailed
        }
        return group
    }

    /// Joins an existing group by code. PoC has no remote registry, so we
    /// require the group to already exist locally (seeded or shared between
    /// installs via CloudKit later).
    @discardableResult
    static func joinGroup(byCode raw: String, in context: ModelContext) async throws -> StudyGroupModel {
        let code = GroupCode.sanitize(raw)
        guard GroupCode.isValid(code) else { throw SocialError.invalidGroupCode }
        let meRow = me(in: context)
        guard let myUid = AuthBootstrap.shared.currentUID else { throw SocialError.serverPublishFailed }

        // Local-first: already joined this room. Re-assert membership
        // (idempotent self-join) so a legacy row predating memberUids heals.
        let predicate = #Predicate<StudyGroupModel> { $0.code == code }
        if let group = try context.fetch(FetchDescriptor(predicate: predicate)).first {
            try? await FirestoreSyncService.shared.joinGroupAddSelf(
                groupId: group.id, myUid: myUid, myCode: meRow.friendCode
            )
            if !group.memberCodes.contains(meRow.friendCode) { group.memberCodes.append(meRow.friendCode) }
            if !group.memberUids.contains(myUid) { group.memberUids.append(myUid) }
            Persistence.save({ try context.save() }, context: "group.join.local")
            return group
        }

        // Resolve code → gid via the public groupCodes lookup — we can't read
        // the member-only group doc until we've joined. The real name/roster
        // arrive via the inbox listener once the self-join lands.
        switch await FirestoreSyncService.shared.lookupGroupCode(code) {
            case .notFound:
                throw SocialError.groupNotFound
            case .error(let err):
                throw SocialError.lookupError(err)
            case .found(let gid):
                let joined = StudyGroupModel(
                    id: gid, code: code, name: "그룹 \(code)",
                    memberCodes: [meRow.friendCode], memberUids: [myUid]
                )
                context.insert(joined)
                guard Persistence.save({ try context.save() }, context: "group.join.remote") != nil else {
                    context.delete(joined)
                    throw SocialError.saveFailed
                }
                do {
                    try await FirestoreSyncService.shared.joinGroupAddSelf(
                        groupId: gid, myUid: myUid, myCode: meRow.friendCode
                    )
                } catch {
                    context.delete(joined)
                    Persistence.save({ try context.save() }, context: "group.join.rollback")
                    Persistence.log(error, context: "firestore.joinGroupAddSelf")
                    throw SocialError.serverPublishFailed
                }
                return joined
        }
    }

    // MARK: - Direct messages (1:1 channels)

    /// Returns the (auto-created if missing) study group that backs the 1:1
    /// chat between `me` and `friend`. Both devices independently call this
    /// with the same pair of friendCodes — the deterministic UUID guarantees
    /// they land on the *same* group document, so messages from both sides
    /// converge in one Firestore path.
    @discardableResult
    static func ensureDirectMessageGroup(
        with friend: FriendProfileModel, in context: ModelContext
    ) async throws -> StudyGroupModel {
        let meRow = me(in: context)
        let pair = [meRow.friendCode, friend.friendCode].sorted()
        let groupID = DirectMessageKey.deterministicID(forSortedCodes: pair)

        // Resolve the friend's auth UID so the DM doc carries BOTH members'
        // UIDs from creation. The hardened rules forbid self-join into DMs, so
        // the second party must already be a member — which only holds if the
        // creator seeds memberUids with the friend's UID too. Fetch + persist
        // it once for legacy friend rows that predate the field.
        var friendUID = friend.serverUID
        if friendUID.isEmpty {
            if case .found(let remote) = await FirestoreSyncService.shared.lookupFriend(byCode: friend.friendCode) {
                friendUID = remote.uid
                friend.serverUID = remote.uid
            }
        }
        let dmUids = friendUID.isEmpty ? [] : [friendUID]

        let predicate = #Predicate<StudyGroupModel> { $0.id == groupID }
        if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
            // Refresh memberCodes & name in case the friend renamed. Only
            // overwrite memberUids when we actually resolved one — never clobber
            // an existing DM's UIDs with an empty list (e.g. offline refresh).
            existing.memberCodes = pair
            if !dmUids.isEmpty { existing.memberUids = dmUids }
            if existing.name != friend.nickname { existing.name = friend.nickname }
            Persistence.save({ try context.save() }, context: "dm.refresh")
            try? await FirestoreSyncService.shared.publishGroup(existing)
            return existing
        }

        // A brand-new DM must carry the friend's UID — otherwise the locked
        // self-join rule leaves the friend permanently unable to read it. Fail
        // loud so the user retries once online instead of creating a dead
        // thread that looks fine on our side but the friend can never open.
        guard !dmUids.isEmpty else { throw SocialError.serverPublishFailed }

        let group = StudyGroupModel(
            id: groupID,
            code: directMessageCodePrefix + pair.joined(separator: "-"),
            name: friend.nickname,
            memberCodes: pair,
            memberUids: dmUids
        )
        context.insert(group)
        guard Persistence.save({ try context.save() }, context: "dm.create") != nil else {
            context.delete(group)
            throw SocialError.saveFailed
        }
        do {
            try await FirestoreSyncService.shared.publishGroup(group)
        } catch {
            context.delete(group)
            Persistence.save({ try context.save() }, context: "dm.create.rollback")
            Persistence.log(error, context: "firestore.publishGroup.dm")
            throw SocialError.serverPublishFailed
        }
        return group
    }

    static func leaveGroup(_ group: StudyGroupModel, in context: ModelContext) {
        let me = me(in: context)
        let gid = group.id
        group.memberCodes.removeAll { $0 == me.friendCode }
        let remainingMembers = group.memberCodes
        if remainingMembers.isEmpty {
            context.delete(group)
        }
        Persistence.save({ try context.save() }, context: "group.leave")
        // Server-side: update memberCodes so the *other* members' devices
        // stop seeing us, or delete the group doc if we were the last one.
        // Fire-and-forget intentionally — failure here doesn't roll back the
        // local action (the user pressed "나가기" and expects it to feel done).
        Task {
            do {
                try await FirestoreSyncService.shared.updateGroupMembers(
                    groupId: gid, members: remainingMembers
                )
            } catch {
                Persistence.log(error, context: "firestore.updateGroupMembers.leave")
            }
        }
    }
}
