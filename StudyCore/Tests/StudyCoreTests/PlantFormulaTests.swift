// PlantFormulaTests — Ocean parameter contract.
// The renderer relies on these counts/ranges; if formulas drift the canvas
// silently degrades, so lock the boundary behavior.

import XCTest
@testable import StudyCore

final class PlantFormulaTests: XCTestCase {
    private let seed: UInt64 = 0xC0DE_BEEF

    func testZeroMinutesGivesSingleWaveAndNoFish() {
        let p = PlantFormula.parameters(
            seed: seed,
            nutrients: PlantNutrients(studyMinutes: 0, workoutMinutes: 0)
        )
        XCTAssertEqual(p.waves.count, 1, "log10(0+1)*1.5 floors to 0 → 1 layer")
        XCTAssertEqual(p.fish.count, 0, "fish count clamps to ≥ 0 when total is zero")
    }

    func testWaveLayerCapsAtFour() {
        // Push total minutes large enough that log10(total+1)*1.5 > 3.
        let p = PlantFormula.parameters(
            seed: seed,
            nutrients: PlantNutrients(studyMinutes: 100_000, workoutMinutes: 100_000)
        )
        XCTAssertEqual(p.waves.count, 4, "wave layers must hard-cap at 4")
    }

    func testFishCountCapsAtTwelve() {
        let p = PlantFormula.parameters(
            seed: seed,
            nutrients: PlantNutrients(studyMinutes: 1_000_000, workoutMinutes: 0)
        )
        XCTAssertEqual(p.fish.count, 12, "fish count must hard-cap at 12")
    }

    func testDeterministicForSameSeedAndNutrients() {
        let nutrients = PlantNutrients(studyMinutes: 300, workoutMinutes: 60)
        let a = PlantFormula.parameters(seed: 42, nutrients: nutrients)
        let b = PlantFormula.parameters(seed: 42, nutrients: nutrients)
        XCTAssertEqual(a.waves.count, b.waves.count)
        XCTAssertEqual(a.fish.count, b.fish.count)
        XCTAssertEqual(a.bgHue, b.bgHue, accuracy: 1e-9)
        // Spot-check first wave for byte-level equality.
        XCTAssertEqual(a.waves.first?.frequency, b.waves.first?.frequency)
        XCTAssertEqual(a.waves.first?.phase, b.waves.first?.phase)
    }

    func testStudyHeavyShiftsHueCooler() {
        // bgHue = 0.58 - studyRatio * 0.05  → all-study should hit 0.53.
        let allStudy = PlantFormula.parameters(
            seed: seed,
            nutrients: PlantNutrients(studyMinutes: 120, workoutMinutes: 0)
        )
        let allWorkout = PlantFormula.parameters(
            seed: seed,
            nutrients: PlantNutrients(studyMinutes: 0, workoutMinutes: 120)
        )
        XCTAssertLessThan(allStudy.bgHue, allWorkout.bgHue, "study-heavy bgHue must be cooler (lower hue) than workout-heavy")
    }

    func testFormulaDescriptionExposesAllLayers() {
        let p = PlantFormula.parameters(
            seed: seed,
            nutrients: PlantNutrients(studyMinutes: 200, workoutMinutes: 100)
        )
        let lines = PlantFormula.formulaDescription(
            seed: seed,
            nutrients: PlantNutrients(studyMinutes: 200, workoutMinutes: 100)
        )
        // 5 base lines + 1 line per wave layer.
        XCTAssertEqual(lines.count, 5 + p.waves.count)
    }
}
