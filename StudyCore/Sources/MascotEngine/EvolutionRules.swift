// EvolutionRules — pure functions deciding mascot progression.
// Thresholds are tunable here without touching the engine code.

import Foundation
import Models

public struct EvolutionRules: Sendable {
    /// EXP needed to reach each stage (cumulative). Index = stage.
    /// stage 0 (egg) is the starting state; reach stage 1 at 100 EXP, etc.
    public static let stageThresholds: [Int] = [0, 100, 300, 700, 1500, 3000]

    public static let expDailyGoalMet: Int = 50
    public static let expCellogSent: Int = 5
    public static let expWeeklyStreak7: Int = 200

    public static func stage(for exp: Int) -> Int {
        var stage = 0
        for (i, threshold) in stageThresholds.enumerated() {
            if exp >= threshold { stage = i }
        }
        return min(stage, Mascot.maxStage)
    }

    public static func expToNextStage(currentExp: Int) -> Int? {
        let s = stage(for: currentExp)
        guard s < Mascot.maxStage else { return nil }
        return max(0, stageThresholds[s + 1] - currentExp)
    }
}
