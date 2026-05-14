// StudySession — a single timer run.
// `plannerDay` reflects the cutoff-adjusted day (see PlannerCalendar).

import Foundation

public struct PausedRange: Hashable, Codable, Sendable {
    public var start: Date
    public var end: Date?
    public var reason: PauseReason

    public init(start: Date, end: Date? = nil, reason: PauseReason) {
        self.start = start
        self.end = end
        self.reason = reason
    }

    public var seconds: Int {
        let until = end ?? Date()
        return max(0, Int(until.timeIntervalSince(start)))
    }
}

public enum PauseReason: String, Codable, Sendable {
    case userManual
    case backgroundEntered
    case screenLocked
    case phoneCall
    case audioInterruption
    case pipStarted
    case splitViewShrunk
    case lectureCapReached
}

public struct StudySession: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var subjectID: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var totalSeconds: Int
    public var plannerDay: Int
    public var pausedRanges: [PausedRange]

    public init(
        id: UUID = UUID(),
        subjectID: UUID,
        startedAt: Date,
        endedAt: Date? = nil,
        totalSeconds: Int = 0,
        plannerDay: Int,
        pausedRanges: [PausedRange] = []
    ) {
        self.id = id
        self.subjectID = subjectID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalSeconds = totalSeconds
        self.plannerDay = plannerDay
        self.pausedRanges = pausedRanges
    }

    public var isActive: Bool { endedAt == nil }
}
