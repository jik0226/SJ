// SocialService — local SwiftData ops on FriendProfileModel, StudyGroupModel,
// and ChatMessageModel. Designed so the CloudKit-backed implementation can
// drop in behind the same surface later (see W3.D track).

import Foundation
import SwiftData
import StudyCore

@MainActor
enum SocialService {
    // MARK: - Me / Friends

    @discardableResult
    static func me(in context: ModelContext) -> FriendProfileModel {
        let predicate = #Predicate<FriendProfileModel> { $0.isMe == true }
        let descriptor = FetchDescriptor<FriendProfileModel>(predicate: predicate)
        if let existing = try? context.fetch(descriptor).first { return existing }

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
    static func addFriend(byCode raw: String, in context: ModelContext) throws -> FriendProfileModel {
        let code = FriendCode.sanitize(raw)
        guard FriendCode.isValid(code) else { throw SocialError.invalidCode }
        if let existing = try lookupFriend(code: code, in: context) {
            existing.isBlocked = false
            Persistence.save({ try context.save() }, context: "social.addFriend.existing")
            return existing
        }
        let stub = FriendProfileModel(
            friendCode: code,
            nickname: "친구 \(code.prefix(3))",
            mascotSpecies: .cat,
            mascotStage: 0
        )
        context.insert(stub)
        Persistence.save({ try context.save() }, context: "social.addFriend.new")
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

    /// Creates a new study group with the current user as the sole initial member.
    @discardableResult
    static func createGroup(name: String, in context: ModelContext) throws -> StudyGroupModel {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialError.emptyGroupName }
        let me = me(in: context)
        let group = StudyGroupModel(
            code: GroupCode.generate(),
            name: trimmed,
            memberCodes: [me.friendCode]
        )
        context.insert(group)
        Persistence.save({ try context.save() }, context: "group.create")
        return group
    }

    /// Joins an existing group by code. PoC has no remote registry, so we
    /// require the group to already exist locally (seeded or shared between
    /// installs via CloudKit later).
    @discardableResult
    static func joinGroup(byCode raw: String, in context: ModelContext) throws -> StudyGroupModel {
        let code = GroupCode.sanitize(raw)
        guard GroupCode.isValid(code) else { throw SocialError.invalidGroupCode }
        let predicate = #Predicate<StudyGroupModel> { $0.code == code }
        let descriptor = FetchDescriptor<StudyGroupModel>(predicate: predicate)
        guard let group = try context.fetch(descriptor).first else {
            throw SocialError.groupNotFound
        }
        let me = me(in: context)
        if !group.memberCodes.contains(me.friendCode) {
            group.memberCodes.append(me.friendCode)
            Persistence.save({ try context.save() }, context: "group.join")
        }
        return group
    }

    static func leaveGroup(_ group: StudyGroupModel, in context: ModelContext) {
        let me = me(in: context)
        group.memberCodes.removeAll { $0 == me.friendCode }
        if group.memberCodes.isEmpty {
            context.delete(group)
        }
        Persistence.save({ try context.save() }, context: "group.leave")
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
    ) -> ChatSendResult {
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
            attachedKind: attachedKind
        )
        context.insert(msg)
        if Persistence.save({ try context.save() }, context: "chat.send") != nil {
            return .sent
        }
        return .saveFailed
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
