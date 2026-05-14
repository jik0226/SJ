// MascotEngineTests — evolution thresholds and stage-up detection.

import XCTest
@testable import StudyCore

final class MascotEngineTests: XCTestCase {
    private let engine = MascotEngine()

    private func makeMascot(exp: Int = 0, stage: Int = 0) -> Mascot {
        Mascot(species: .rabbit, name: "Mochi", exp: exp, stage: stage)
    }

    func testStageThresholds() {
        XCTAssertEqual(EvolutionRules.stage(for: 0), 0)
        XCTAssertEqual(EvolutionRules.stage(for: 99), 0)
        XCTAssertEqual(EvolutionRules.stage(for: 100), 1)
        XCTAssertEqual(EvolutionRules.stage(for: 299), 1)
        XCTAssertEqual(EvolutionRules.stage(for: 300), 2)
        XCTAssertEqual(EvolutionRules.stage(for: 700), 3)
        XCTAssertEqual(EvolutionRules.stage(for: 1500), 4)
        XCTAssertEqual(EvolutionRules.stage(for: 2999), 4)
        XCTAssertEqual(EvolutionRules.stage(for: 3000), 5)
        XCTAssertEqual(EvolutionRules.stage(for: 9999), Mascot.maxStage) // capped at 5
    }

    func testDailyGoalEventGives50Exp() {
        let m = makeMascot()
        let t = engine.apply(.dailyGoalMet, to: m)
        XCTAssertEqual(t.after.exp, 50)
        XCTAssertFalse(t.stageUp)
    }

    func testStageUpDetected() {
        let m = makeMascot(exp: 80, stage: 0)
        let t = engine.apply(.dailyGoalMet, to: m)
        XCTAssertEqual(t.after.exp, 130)
        XCTAssertEqual(t.after.stage, 1)
        XCTAssertTrue(t.stageUp)
    }

    func testCellogSentSmallExp() {
        let m = makeMascot()
        let t = engine.apply(.cellogSent, to: m)
        XCTAssertEqual(t.after.exp, 5)
    }

    func testWeeklyStreakBumps() {
        let m = makeMascot(exp: 90, stage: 0)
        let t = engine.apply(.weeklyStreak7, to: m)
        XCTAssertEqual(t.after.exp, 290)
        XCTAssertEqual(t.after.stage, 1)
        XCTAssertTrue(t.stageUp)
    }

    func testExpToNextStage() {
        XCTAssertEqual(EvolutionRules.expToNextStage(currentExp: 50), 50)
        XCTAssertEqual(EvolutionRules.expToNextStage(currentExp: 100), 200)
        XCTAssertEqual(EvolutionRules.expToNextStage(currentExp: 1500), 1500)
        XCTAssertNil(EvolutionRules.expToNextStage(currentExp: 3000))
    }
}
