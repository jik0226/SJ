// SocialService — local SwiftData ops on FriendProfileModel, StudyGroupModel,
// and ChatMessageModel. Designed so the CloudKit-backed implementation can
// drop in behind the same surface later (see W3.D track).
//
// The surface is split across extensions by concern:
//   SocialService+Friends.swift — add/remove friends
//   SocialService+Groups.swift  — create/join/leave + DM channels
//   SocialService+Chat.swift    — send/retry/report messages

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

        // Empty nickname = "not set yet". The friends UI gates code-sharing,
        // friend-add, and chat on a real nickname so we never publish a
        // placeholder like "나" that confuses the other side of a 1:1 chat.
        let me = FriendProfileModel(
            friendCode: FriendCode.generate(),
            nickname: "",
            mascotSpecies: .rabbit,
            mascotStage: 0,
            isMinor: false,
            isMe: true
        )
        context.insert(me)
        Persistence.save({ try context.save() }, context: "social.seedMe")
        // Only publish once a nickname exists (publishMe self-guards too).
        FirestoreSyncService.shared.publishMe(me)
        return me
    }

    /// True once the user has chosen a display name. Friend features stay
    /// locked until this is set so other people never see "" or a placeholder.
    static func hasNickname(in context: ModelContext) -> Bool {
        !me(in: context).nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Demo data is gated behind an explicit launch argument (`--seed-demo`),
    /// not just DEBUG. The simulator/TestFlight build is something real users
    /// see, so a fresh install must start empty — "민서/준호/공부 메이트"
    /// appearing unprompted reads as test-data leakage. Set the arg in the
    /// Xcode scheme only when you want demo data for screenshots.
    static var demoSeedingEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--seed-demo")
    }

    static func seedDemoFriendsIfNeeded(in context: ModelContext) {
        guard demoSeedingEnabled else { return }
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

    static func block(_ friend: FriendProfileModel, in context: ModelContext) {
        friend.isBlocked = true
        Persistence.save({ try context.save() }, context: "social.block")
    }

    static func unblock(_ friend: FriendProfileModel, in context: ModelContext) {
        friend.isBlocked = false
        Persistence.save({ try context.save() }, context: "social.unblock")
    }

    // MARK: - Direct messages (1:1 channels)

    /// Reserved prefix marking a group that backs a 1:1 DM. The "code" field
    /// is built deterministically from both members' friendCodes so it isn't
    /// a real join code; UI hides these groups from the join-by-code path.
    static let directMessageCodePrefix = "DM:"

    static func seedDemoGroupIfNeeded(in context: ModelContext) {
        // Gated behind --seed-demo (see seedDemoFriendsIfNeeded). Real users
        // start with an empty group list and create/join their own.
        guard demoSeedingEnabled else { return }
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

    // MARK: - Helpers

    static func lookupFriend(code: String, in context: ModelContext) throws -> FriendProfileModel? {
        let predicate = #Predicate<FriendProfileModel> { $0.friendCode == code }
        let descriptor = FetchDescriptor<FriendProfileModel>(predicate: predicate)
        return try context.fetch(descriptor).first
    }

    static func containsURL(_ text: String) -> Bool {
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
