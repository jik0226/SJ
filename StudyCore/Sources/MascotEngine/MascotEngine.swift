// MascotEngine — applies events to a Mascot and emits stage-up transitions.

import Foundation
import Models

public enum MascotEvent: Equatable, Sendable {
    case dailyGoalMet
    case cellogSent
    case weeklyStreak7
    case rawExp(Int)
}

public struct MascotTransition: Equatable, Sendable {
    public let before: Mascot
    public let after: Mascot
    public let stageUp: Bool
    public var newStage: Int { after.stage }
}

public struct MascotEngine: Sendable {
    public init() {}

    public func apply(_ event: MascotEvent, to mascot: Mascot) -> MascotTransition {
        let delta: Int
        switch event {
            case .dailyGoalMet: delta = EvolutionRules.expDailyGoalMet
            case .cellogSent: delta = EvolutionRules.expCellogSent
            case .weeklyStreak7: delta = EvolutionRules.expWeeklyStreak7
            case .rawExp(let v): delta = v
        }
        let newExp = max(0, mascot.exp + delta)
        let newStage = EvolutionRules.stage(for: newExp)

        var updated = mascot
        updated.exp = newExp
        updated.stage = newStage

        return MascotTransition(
            before: mascot,
            after: updated,
            stageUp: newStage > mascot.stage
        )
    }
}
