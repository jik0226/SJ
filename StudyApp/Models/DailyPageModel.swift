// DailyPageModel — photo-1 right-page persistence.

import Foundation
import SwiftData

@Model
final class DailyPageModel {
    @Attribute(.unique) var plannerDay: Int
    var todayGoal: String
    var keyPoint: String
    var feedback: String
    var progressPercent: Int

    init(
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
