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
        todayStudyMinutes: Int = 0
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
    }

    var mascotSpecies: MascotSpecies {
        MascotSpecies(rawValue: mascotSpeciesRaw) ?? .rabbit
    }
}
