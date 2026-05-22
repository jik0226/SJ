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
        let group = StudyGroupModel(
            code: GroupCode.generate(),
            name: trimmed,
            memberCodes: [me.friendCode]
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

        // Local-first lookup so a previously-seen group joins instantly.
        let predicate = #Predicate<StudyGroupModel> { $0.code == code }
        let descriptor = FetchDescriptor<StudyGroupModel>(predicate: predicate)
        if let group = try context.fetch(descriptor).first {
            if !group.memberCodes.contains(meRow.friendCode) {
                group.memberCodes.append(meRow.friendCode)
                Persistence.save({ try context.save() }, context: "group.join.local")
                try? await FirestoreSyncService.shared.publishGroup(group)
            }
            return group
        }

        // Server-backed lookup: mirror the remote group into local storage so
        // GroupListView can render it offline next time.
        if AuthBootstrap.shared.isSignedIn {
            switch await FirestoreSyncService.shared.lookupGroup(byCode: code) {
                case .notFound:
                    throw SocialError.groupNotFound
                case .error(let err):
                    throw SocialError.lookupError(err)
                case .found(let remote):
                    let mirrored = StudyGroupModel(
                        id: remote.id,
                        code: remote.code,
                        name: remote.name,
                        memberCodes: Array(Set(remote.memberCodes + [meRow.friendCode]))
                    )
                    context.insert(mirrored)
                    guard Persistence.save({ try context.save() }, context: "group.join.remote") != nil else {
                        context.delete(mirrored)
                        throw SocialError.saveFailed
                    }
                    do {
                        try await FirestoreSyncService.shared.publishGroup(mirrored)
                    } catch {
                        context.delete(mirrored)
                        Persistence.save({ try context.save() }, context: "group.join.rollback")
                        Persistence.log(error, context: "firestore.publishGroup.join")
                        throw SocialError.serverPublishFailed
                    }
                    return mirrored
            }
        }
        throw SocialError.groupNotFound
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
        let groupID = directMessageGroupID(for: pair)

        let predicate = #Predicate<StudyGroupModel> { $0.id == groupID }
        if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
            // Refresh memberCodes & name in case the friend renamed.
            existing.memberCodes = pair
            if existing.name != friend.nickname { existing.name = friend.nickname }
            Persistence.save({ try context.save() }, context: "dm.refresh")
            try? await FirestoreSyncService.shared.publishGroup(existing)
            return existing
        }

        let group = StudyGroupModel(
            id: groupID,
            code: directMessageCodePrefix + pair.joined(separator: "-"),
            name: friend.nickname,
            memberCodes: pair
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

    /// SHA256-derived UUID from the two friendCodes. Both members compute
    /// the same value regardless of who initiates the chat. Idempotent.
    private static func directMessageGroupID(for sortedCodes: [String]) -> UUID {
        let key = "dm|" + sortedCodes.joined(separator: "|")
        let digest = SHA256.hash(data: Data(key.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        // 8-4-4-4-12 layout from the first 32 hex chars of the digest.
        let s = Array(hex)
        let formatted = "\(String(s[0..<8]))-\(String(s[8..<12]))-\(String(s[12..<16]))-\(String(s[16..<20]))-\(String(s[20..<32]))"
        return UUID(uuidString: formatted) ?? UUID()
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
