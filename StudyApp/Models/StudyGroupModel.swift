// StudyGroupModel — a study room shared by friends.
// Members are tracked as friend codes (string array) so a group can survive a
// friend being deleted or re-added.

import Foundation
import SwiftData

@Model
final class StudyGroupModel {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var code: String          // 6-char join code
    var name: String
    var memberCodes: [String]                     // friend codes of every member (including me)
    /// Firebase Auth UIDs of known members — the trust boundary the Firestore
    /// rules actually enforce (friendCode is public, so it can't be one). For
    /// a DM this is seeded with the friend's UID at creation so they join as a
    /// member rather than self-joining. publishGroup unions our own UID in.
    /// Stored default REQUIRED for SwiftData lightweight migration.
    var memberUids: [String] = []
    var createdAt: Date

    init(
        id: UUID = UUID(),
        code: String,
        name: String,
        memberCodes: [String],
        memberUids: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.memberCodes = memberCodes
        self.memberUids = memberUids
        self.createdAt = createdAt
    }

    func contains(friendCode: String) -> Bool {
        memberCodes.contains(friendCode)
    }
}
