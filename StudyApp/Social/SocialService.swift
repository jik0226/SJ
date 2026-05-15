// SocialService — local SwiftData ops on FriendProfileModel, StudyGroupModel,
// and ChatMessageModel. Designed so the CloudKit-backed implementation can
// drop in behind the same surface later (see W3.D track).

import Foundation
import SwiftData
import CryptoKit
import StudyCore

@MainActor
enum SocialService {
    // MARK: - Me / Friends

    @discardableResult
    static func me(in context: ModelContext) -> FriendProfileModel {
        let predicate = #Predicate<FriendProfileModel> { $0.isMe == true }
        let descriptor = FetchDescriptor<FriendProfileModel>(predicate: predicate)
        let mes = (try? context.fetch(descriptor)) ?? []
        if let primary = mes.first {
            // Defensive: SwiftData has no way to constrain "at most one isMe
            // row", and legacy installs that called me(...) before unique
            // friendCode enforcement could have produced two. Demote any
            // extras so mes.first across the app is stable.
            for extra in mes.dropFirst() {
                extra.isMe = false
            }
            if mes.count > 1 {
                Persistence.save({ try context.save() }, context: "social.me.dedupe")
            }
            // Re-publish on every call so a nickname change made offline is
            // eventually surfaced to other devices. publishMe is a server-side
            // setData(merge:) so this is cheap.
            FirestoreSyncService.shared.publishMe(primary)
            return primary
        }

        let me = FriendProfileModel(
            friendCode: FriendCode.generate(),
            nickname: "나",
            mascotSpecies: .rabbit,
            mascotStage: 0,
            isMinor: false,
            isMe: true
        )
        context.insert(me)
        Persistence.save({ try context.save() }, context: "social.seedMe")
        FirestoreSyncService.shared.publishMe(me)
        return me
    }

    static func seedDemoFriendsIfNeeded(in context: ModelContext) {
        let predicate = #Predicate<FriendProfileModel> { $0.isMe == false }
        let descriptor = FetchDescriptor<FriendProfileModel>(predicate: predicate)
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        let demos: [FriendProfileModel] = [
            FriendProfileModel(
                friendCode: "STUDY7", nickname: "민서",
                mascotSpecies: .fox, mascotStage: 2,
                todayStudyMinutes: 145
            ),
            FriendProfileModel(
                friendCode: "FOCUS3", nickname: "준호",
                mascotSpecies: .bear, mascotStage: 1,
                todayStudyMinutes: 38
            ),
        ]
        demos.forEach(context.insert)
        Persistence.save({ try context.save() }, context: "social.seedDemoFriends")
    }

    @discardableResult
    static func addFriend(byCode raw: String, in context: ModelContext) async throws -> FriendProfileModel {
        let code = FriendCode.sanitize(raw)
        guard FriendCode.isValid(code) else { throw SocialError.invalidCode }
        // Reject the user's own code outright. Previously this matched the
        // `isMe` row silently, which made the sheet dismiss with no visible
        // friend added — confusing.
        let meRow = me(in: context)
        if code == meRow.friendCode { throw SocialError.selfCode }
        if let existing = try lookupFriend(code: code, in: context) {
            existing.isBlocked = false
            Persistence.save({ try context.save() }, context: "social.addFriend.existing")
            return existing
        }

        // Server-backed path: verify the code maps to a real user before
        // creating a local row. Offline fallback only happens when Firebase
        // auth hasn't bootstrapped yet — that path keeps the (데모) suffix so
        // the user never confuses an unverified entry for a real friend.
        if AuthBootstrap.shared.isSignedIn,
           let meUid = AuthBootstrap.shared.currentUID {
            switch await FirestoreSyncService.shared.lookupFriend(byCode: code) {
                case .notFound:
                    throw SocialError.codeNotFound
                case .error(let err):
                    throw SocialError.lookupError(err)
                case .found(let remote):
                    let real = FriendProfileModel(
                        friendCode: remote.friendCode,
                        nickname: remote.nickname,
                        mascotSpecies: .cat,
                        mascotStage: 0
                    )
                    context.insert(real)
                    guard Persistence.save({ try context.save() }, context: "social.addFriend.remote") != nil else {
                        context.delete(real)
                        throw SocialError.saveFailed
                    }
                    // Mirror the friendship to both sides — `await` so the
                    // other device sees us before this returns. If publish
                    // fails (rules/network), roll the local row back so the
                    // user never sees an "added but invisible" friend.
                    do {
                        try await FirestoreSyncService.shared.publishMutualFriendship(
                            meUid: meUid,
                            meCode: meRow.friendCode,
                            meNick: meRow.nickname,
                            otherUid: remote.uid,
                            otherCode: remote.friendCode,
                            otherNick: remote.nickname
                        )
                    } catch {
                        context.delete(real)
                        Persistence.save({ try context.save() }, context: "social.addFriend.rollback")
                        Persistence.log(error, context: "firestore.publishMutualFriendship")
                        throw SocialError.serverPublishFailed
                    }
                    return real
            }
        }

        // Offline / pre-auth fallback: keep the demo stub but tag it visibly.
        let stub = FriendProfileModel(
            friendCode: code,
            nickname: "(데모) 친구 \(code.prefix(3))",
            mascotSpecies: .cat,
            mascotStage: 0
        )
        context.insert(stub)
        guard Persistence.save({ try context.save() }, context: "social.addFriend.new") != nil else {
            context.delete(stub)
            throw SocialError.saveFailed
        }
        return stub
    }

    static func block(_ friend: FriendProfileModel, in context: ModelContext) {
        friend.isBlocked = true
        Persistence.save({ try context.save() }, context: "social.block")
    }

    static func unblock(_ friend: FriendProfileModel, in context: ModelContext) {
        friend.isBlocked = false
        Persistence.save({ try context.save() }, context: "social.unblock")
    }

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

    /// Reserved prefix marking a group that backs a 1:1 DM. The "code" field
    /// is built deterministically from both members' friendCodes so it isn't
    /// a real join code; UI hides these groups from the join-by-code path.
    static let directMessageCodePrefix = "DM:"

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

    /// Removes a friend from the caller's side only (Kakao/Line semantics).
    /// Deletes both the local SwiftData row and the caller's server-side
    /// `users/{me}/friends/{other}` doc so the friends listener doesn't
    /// resurrect the row on next launch.
    static func removeFriend(_ friend: FriendProfileModel, in context: ModelContext) {
        let otherCode = friend.friendCode
        context.delete(friend)
        Persistence.save({ try context.save() }, context: "friend.delete")
        guard let meUid = AuthBootstrap.shared.currentUID else { return }
        Task {
            // Lookup the friend's UID by friendCode to delete the right doc.
            switch await FirestoreSyncService.shared.lookupFriend(byCode: otherCode) {
                case .found(let remote):
                    do {
                        try await FirestoreSyncService.shared.deleteFriendship(
                            meUid: meUid, otherUid: remote.uid
                        )
                    } catch {
                        Persistence.log(error, context: "firestore.deleteFriendship")
                    }
                case .notFound, .error:
                    break
            }
        }
    }

    static func seedDemoGroupIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<StudyGroupModel>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }
        let me = me(in: context)
        let group = StudyGroupModel(
            code: "MATE42",
            name: "공부 메이트",
            memberCodes: [me.friendCode, "STUDY7", "FOCUS3"]
        )
        context.insert(group)

        // Seed a couple of demo messages so the chat thread isn't empty.
        let now = Date()
        let demos: [ChatMessageModel] = [
            ChatMessageModel(
                groupId: group.id, senderFriendCode: "STUDY7",
                text: "오늘 수학 인강 다 들었어 🎓",
                sentAt: now.addingTimeInterval(-60 * 60)
            ),
            ChatMessageModel(
                groupId: group.id, senderFriendCode: "FOCUS3",
                text: "굿! 나도 영어 단어 30개 외움 💪",
                sentAt: now.addingTimeInterval(-30 * 60)
            ),
        ]
        demos.forEach(context.insert)
        Persistence.save({ try context.save() }, context: "group.seedDemo")
    }

    // MARK: - Chat

    @discardableResult
    static func sendChat(
        text: String,
        to group: StudyGroupModel,
        attachedKind: AttachedKind? = nil,
        attachedRecordSummary: String? = nil,
        in context: ModelContext
    ) async -> ChatSendResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || attachedRecordSummary != nil else {
            return .empty
        }
        if case .blocked(let reason) = ProfanityFilter.check(trimmed) {
            return .blockedByFilter(reason: reason)
        }
        let me = me(in: context)

        // PLAN §9 minor safety: 14세 미만 사용자에게는 메시지 길이를 더 짧게
        // 잡고 (200자, anonymous-style 변종 금지 부담 대신 단순 cap), 욕설 외에도
        // 외부 링크 차단을 추가한다.
        let effectiveMaxLength = me.isMinor ? 200 : 500
        let capped = String(trimmed.prefix(effectiveMaxLength))
        if me.isMinor, containsURL(capped) {
            return .blockedByFilter(reason: "만 14세 미만 사용자는 외부 링크를 공유할 수 없어요.")
        }

        let msg = ChatMessageModel(
            groupId: group.id,
            senderFriendCode: me.friendCode,
            text: capped,
            attachedRecordSummary: attachedRecordSummary,
            attachedKind: attachedKind,
            deliveryState: .sending
        )
        context.insert(msg)
        guard Persistence.save({ try context.save() }, context: "chat.send") != nil else {
            return .saveFailed
        }
        // Await the Firestore publish so the bubble flips from "sending" to
        // "sent" only after the server actually has it. Network/permission
        // failures land the row in `.failed` so the UI can offer retry.
        do {
            try await FirestoreSyncService.shared.publishMessage(msg)
            msg.deliveryState = .sent
            Persistence.save({ try context.save() }, context: "chat.send.delivered")
            return .sent
        } catch {
            msg.deliveryState = .failed
            Persistence.save({ try context.save() }, context: "chat.send.failed")
            Persistence.log(error, context: "firestore.publishMessage.send")
            return .serverPublishFailed
        }
    }

    /// Re-attempts publish for a message previously stuck in `.failed`.
    /// Returns `.sent` when delivery now succeeds, `.serverPublishFailed`
    /// otherwise. Idempotent — Firestore setData(merge:) safely re-writes.
    @discardableResult
    static func retrySend(
        _ msg: ChatMessageModel, in context: ModelContext
    ) async -> ChatSendResult {
        msg.deliveryState = .sending
        Persistence.save({ try context.save() }, context: "chat.retry.start")
        do {
            try await FirestoreSyncService.shared.publishMessage(msg)
            msg.deliveryState = .sent
            Persistence.save({ try context.save() }, context: "chat.retry.sent")
            return .sent
        } catch {
            msg.deliveryState = .failed
            Persistence.save({ try context.save() }, context: "chat.retry.failed")
            Persistence.log(error, context: "firestore.publishMessage.retry")
            return .serverPublishFailed
        }
    }

    static func reportMessage(_ msg: ChatMessageModel, in context: ModelContext) {
        msg.isReported = true
        Persistence.save({ try context.save() }, context: "chat.report")
    }

    enum ChatSendResult: Equatable {
        case sent
        case empty
        case blockedByFilter(reason: String)
        case saveFailed
        /// Local saved as `.sending`/`.failed` but Firestore publish errored.
        /// UI keeps the bubble and offers retry instead of losing the text.
        case serverPublishFailed
    }

    // MARK: - Helpers

    private static func lookupFriend(code: String, in context: ModelContext) throws -> FriendProfileModel? {
        let predicate = #Predicate<FriendProfileModel> { $0.friendCode == code }
        let descriptor = FetchDescriptor<FriendProfileModel>(predicate: predicate)
        return try context.fetch(descriptor).first
    }

    private static func containsURL(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("http://") || lower.contains("https://") || lower.contains("www.")
    }
}

enum SocialError: Error {
    case invalidCode
    case invalidGroupCode
    case emptyGroupName
    case groupNotFound
    case saveFailed
    /// User entered their own friend code. We don't silently no-op because
    /// the FriendsView would close the sheet and leave them confused.
    case selfCode
    /// Firestore lookup returned no matching user/group. Surface this so the
    /// user can correct a typo instead of silently creating a demo stub.
    case codeNotFound
    /// Local SwiftData write succeeded but the Firestore publish that other
    /// devices rely on failed. Surfaced as a distinct case so the UI can
    /// nudge the user to check internet / Rules.
    case serverPublishFailed
    /// Firestore lookup hit a categorised error (permission, network, …).
    /// Carries the typed cause so UI can show a specific reason.
    case lookupError(LookupError)
}

enum GroupCode {
    private static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate() -> String {
        var rng = SystemRandomNumberGenerator()
        return String((0..<6).map { _ in alphabet.randomElement(using: &rng)! })
    }

    static func sanitize(_ raw: String) -> String {
        let filtered = raw.uppercased().filter { c in alphabet.contains(c) }
        return String(filtered.prefix(6))
    }

    static func isValid(_ raw: String) -> Bool {
        let s = sanitize(raw)
        return s.count == 6 && s.allSatisfy { alphabet.contains($0) }
    }
}
