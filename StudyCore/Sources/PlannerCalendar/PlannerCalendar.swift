// PlannerCalendar — converts between Date and (plannerDay, slotIndex).
// Cutoff hour shifts late-night timestamps back to the previous planner day
// so a 1 AM session counts as part of "yesterday's" study log.

import Foundation
import Models

public struct PlannerCalendar: Sendable {
    public let cutoffHour: Int
    public let calendar: Calendar

    public init(cutoffHour: Int = 3, calendar: Calendar = .current) {
        precondition((0...6).contains(cutoffHour), "cutoffHour must be 0..6")
        self.cutoffHour = cutoffHour
        self.calendar = calendar
    }

    /// Returns the cutoff-adjusted planner day as YYYYMMDD integer.
    public func plannerDay(for date: Date) -> Int {
        let hour = calendar.component(.hour, from: date)
        let anchor: Date
        if hour < cutoffHour {
            anchor = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        } else {
            anchor = date
        }
        let comps = calendar.dateComponents([.year, .month, .day], from: anchor)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return y * 10000 + m * 100 + d
    }

    /// Absolute slot index (0..143) where 0 = 00:00, 143 = 23:50.
    public func slotIndex(for date: Date) -> Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return hour * 6 + minute / PlannerBlock.minutesPerSlot
    }

    /// Truncates `date` down to the start of its 10-minute slot.
    public func startOfSlot(containing date: Date) -> Date {
        var comps = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        let m = comps.minute ?? 0
        comps.minute = (m / PlannerBlock.minutesPerSlot) * PlannerBlock.minutesPerSlot
        comps.second = 0
        return calendar.date(from: comps) ?? date
    }

    /// Walks the session's elapsed range and yields every 10-min slot it occupies.
    /// `pausedRanges` are subtracted: a slot fully inside a pause is omitted.
    public func slots(for session: StudySession) -> [(plannerDay: Int, slotIndex: Int)] {
        let end = session.endedAt ?? Date()
        guard end > session.startedAt else { return [] }

        var result: [(Int, Int)] = []
        var cursor = startOfSlot(containing: session.startedAt)
        while cursor < end {
            let next = calendar.date(
                byAdding: .minute, value: PlannerBlock.minutesPerSlot, to: cursor
            ) ?? end
            if !isFullySwallowedByPause(start: cursor, end: next, pauses: session.pausedRanges) {
                result.append((plannerDay(for: cursor), slotIndex(for: cursor)))
            }
            cursor = next
        }
        return result
    }

    private func isFullySwallowedByPause(
        start: Date, end: Date, pauses: [PausedRange]
    ) -> Bool {
        for pause in pauses {
            let pStart = pause.start
            let pEnd = pause.end ?? end
            if pStart <= start && pEnd >= end { return true }
        }
        return false
    }
}
