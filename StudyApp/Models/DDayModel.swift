// DDayModel — SwiftData persistence for DDay.

import Foundation
import SwiftData
import StudyCore

@Model
final class DDayModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var targetDate: Date
    var emoji: String
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        title: String,
        targetDate: Date,
        emoji: String = "📅",
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.emoji = emoji
        self.isPinned = isPinned
    }

    var coreValue: DDay {
        DDay(id: id, title: title, targetDate: targetDate, emoji: emoji, isPinned: isPinned)
    }
}
