// FriendProfileModel — both the local "me" profile and added friends.
// `isMe` distinguishes the single self-row from added friends. CloudKit sync
// will later mirror `isMe == false` rows into the user's private DB.

import Foundation
import SwiftData
import StudyCore

@Model
final class FriendProfileModel {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var friendCode: String
    var nickname: String
    var mascotSpeciesRaw: String
    var mascotStage: Int
    var isMinor: Bool
    var isMe: Bool
    var isBlocked: Bool
    var addedAt: Date
    var todayStudyMinutes: Int
    /// The friend's Firebase Auth UID. Backs member-based DM security: when we
    /// open a 1:1 DM we seed the group's memberUids with both parties' UIDs so
    /// the friend joins as a member, not via self-join (which the rules forbid
    /// for DMs). Empty on legacy rows until the friends listener backfills it.
    /// Stored default REQUIRED for SwiftData lightweight migration.
    var serverUID: String = ""

    init(
        id: UUID = UUID(),
        friendCode: String,
        nickname: String,
        mascotSpecies: MascotSpecies,
        mascotStage: Int = 0,
        isMinor: Bool = false,
        isMe: Bool = false,
        isBlocked: Bool = false,
        addedAt: Date = Date(),
        todayStudyMinutes: Int = 0,
        serverUID: String = ""
    ) {
        self.id = id
        self.friendCode = friendCode
        self.nickname = nickname
        self.mascotSpeciesRaw = mascotSpecies.rawValue
        self.mascotStage = mascotStage
        self.isMinor = isMinor
        self.isMe = isMe
        self.isBlocked = isBlocked
        self.addedAt = addedAt
        self.todayStudyMinutes = todayStudyMinutes
        self.serverUID = serverUID
    }

    var mascotSpecies: MascotSpecies {
        MascotSpecies(rawValue: mascotSpeciesRaw) ?? .rabbit
    }
}
