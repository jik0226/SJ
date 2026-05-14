// DDay — countdown to a user-defined target date.

import Foundation

public struct DDay: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var targetDate: Date
    public var emoji: String
    public var isPinned: Bool

    public init(
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

    /// Negative when the target is in the past. Uses calendar-day diff to avoid
    /// time-of-day fluctuations.
    public func daysRemaining(from now: Date, calendar: Calendar = .current) -> Int {
        let startOfNow = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        let comps = calendar.dateComponents([.day], from: startOfNow, to: startOfTarget)
        return comps.day ?? 0
    }
}
