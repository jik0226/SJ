// DailyPage — the right-hand page from photo 1 (goal/key point/feedback/progress).
// One per planner day.

import Foundation

public struct DailyPage: Identifiable, Hashable, Codable, Sendable {
    public var id: Int { plannerDay }
    public let plannerDay: Int
    public var todayGoal: String
    public var keyPoint: String
    public var feedback: String
    public var progressPercent: Int

    public init(
        plannerDay: Int,
        todayGoal: String = "",
        keyPoint: String = "",
        feedback: String = "",
        progressPercent: Int = 0
    ) {
        self.plannerDay = plannerDay
        self.todayGoal = todayGoal
        self.keyPoint = keyPoint
        self.feedback = feedback
        self.progressPercent = max(0, min(100, progressPercent))
    }
}
