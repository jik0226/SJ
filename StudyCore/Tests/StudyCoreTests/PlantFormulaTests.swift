// PlantFormulaTests — Ocean parameter contract.
// The renderer relies on these counts/ranges; if formulas drift the canvas
// silently degrades, so lock the boundary behavior. The full-equality
// determinism test also guards the shared-chat-preview contract: a friend's
// ocean is rebuilt from (seed, nutrients) and must match byte-for-byte.

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
        // Full struct equality locks every field — including the new mood,
        // mascot, bubbles, and seabed — which is the contract the shared chat
        // preview relies on to reconstruct an identical ocean from inputs.
        XCTAssertEqual(a, b)
    }

    func testStudyVsWorkoutGivesDistinctMood() {
        // The combination axis: study-heavy → deepStudy (cool indigo) and
        // workout-heavy → deepActive (warm coral). They must yield visibly
        // different moods, palettes, and mascots.
        let allStudy = PlantFormula.parameters(
            seed: seed,
            nutrients: PlantNutrients(studyMinutes: 120, workoutMinutes: 0)
        )
        let allWorkout = PlantFormula.parameters(
            seed: seed,
            nutrients: PlantNutrients(studyMinutes: 0, workoutMinutes: 120)
        )
        XCTAssertEqual(allStudy.mood, .deepStudy)
        XCTAssertEqual(allWorkout.mood, .deepActive)
        XCTAssertNotEqual(allStudy.bgHue, allWorkout.bgHue)
        XCTAssertNotEqual(allStudy.mascot, allWorkout.mascot, "study → turtle, workout → crab")
    }

    func testMoodBucketsByStudyRatio() {
        func mood(study: Int, workout: Int) -> OceanMood {
            PlantFormula.parameters(
                seed: seed,
                nutrients: PlantNutrients(studyMinutes: study, workoutMinutes: workout)
            ).mood
        }
        XCTAssertEqual(mood(study: 100, workout: 0), .deepStudy)   // ratio 1.0
        XCTAssertEqual(mood(study: 0, workout: 100), .deepActive)  // ratio 0.0
        XCTAssertEqual(mood(study: 50, workout: 50), .balanced)    // ratio 0.5
    }

    func testMascotMatchesDominantActivity() {
        func mascot(study: Int, workout: Int) -> OceanMascot {
            PlantFormula.parameters(
                seed: seed,
                nutrients: PlantNutrients(studyMinutes: study, workoutMinutes: workout)
            ).mascot
        }
        XCTAssertEqual(mascot(study: 100, workout: 0), .turtle)   // study-dominant
        XCTAssertEqual(mascot(study: 50, workout: 50), .octopus)  // balanced
        XCTAssertEqual(mascot(study: 0, workout: 100), .crab)     // active-dominant
    }

    func testBubblesScaleWithWorkoutAndSeabedWithStudy() {
        let p = PlantFormula.parameters(
            seed: seed,
            nutrients: PlantNutrients(studyMinutes: 90, workoutMinutes: 45)
        )
        XCTAssertEqual(p.bubbles.count, min(10, 45 / 15), "workout minutes drive bubbles")
        XCTAssertEqual(p.seabed.count, min(6, 90 / 30), "study minutes drive seabed starfish")
    }

    func testActivityOrderChangesOcean() {
        // Same totals (study 60 + workout 30), different order → different
        // sequence hash → different wave phases / fish placement.
        let studyFirst = ActivitySequence.hash(of: [
            ActivityEvent(kind: .study, minutes: 60, at: Date(timeIntervalSince1970: 0)),
            ActivityEvent(kind: .workout, minutes: 30, at: Date(timeIntervalSince1970: 100)),
        ])
        let workoutFirst = ActivitySequence.hash(of: [
            ActivityEvent(kind: .workout, minutes: 30, at: Date(timeIntervalSince1970: 0)),
            ActivityEvent(kind: .study, minutes: 60, at: Date(timeIntervalSince1970: 100)),
        ])
        XCTAssertNotEqual(studyFirst, workoutFirst)

        let a = PlantFormula.parameters(
            seed: 7, nutrients: PlantNutrients(studyMinutes: 60, workoutMinutes: 30, sequenceHash: studyFirst)
        )
        let b = PlantFormula.parameters(
            seed: 7, nutrients: PlantNutrients(studyMinutes: 60, workoutMinutes: 30, sequenceHash: workoutFirst)
        )
        // Same counts (totals identical) ...
        XCTAssertEqual(a.waves.count, b.waves.count)
        XCTAssertEqual(a.fish.count, b.fish.count)
        // ... but different arrangement (at least one wave phase differs).
        let phasesA = a.waves.map(\.phase)
        let phasesB = b.waves.map(\.phase)
        XCTAssertNotEqual(phasesA, phasesB)
    }

    func testEmptySequenceHashMatchesLegacy() {
        // sequenceHash defaulting to 0 reproduces pre-sequence behavior so
        // existing installs render identically until they log new activity.
        let withZero = PlantFormula.parameters(
            seed: 99, nutrients: PlantNutrients(studyMinutes: 120, workoutMinutes: 0, sequenceHash: 0)
        )
        let legacy = PlantFormula.parameters(
            seed: 99, nutrients: PlantNutrients(studyMinutes: 120, workoutMinutes: 0)
        )
        XCTAssertEqual(withZero.waves.map(\.phase), legacy.waves.map(\.phase))
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
        // 13 base lines (wave count/amp/freq, fish, mood, mascot, DNA,
        // milestones, bubbles, starfish, sky, bgHue, activity-order seed)
        // + 1 line per wave layer.
        XCTAssertEqual(lines.count, 13 + p.waves.count)
    }

    // MARK: - Ocean DNA (permanent identity traits)

    func testDNADeterministicAndInRange() {
        let a = OceanDNA.derive(from: 0xDEAD_BEEF_CAFE)
        let b = OceanDNA.derive(from: 0xDEAD_BEEF_CAFE)
        XCTAssertEqual(a, b)
        XCTAssertTrue((0..<8).contains(a.mascotVariant))
        XCTAssertTrue((0..<4).contains(a.fishSpecies))
        XCTAssertTrue((0..<3).contains(a.fishPattern))
    }

    func testDNAStableAcrossActivityOrderAndGrowth() {
        // DNA is identity: same seed must give the same traits regardless of
        // how much was studied or in what order (unlike placement, which the
        // sequence hash intentionally shifts).
        let s1 = ActivitySequence.hash(of: [ActivityEvent(kind: .study, minutes: 60)])
        let s2 = ActivitySequence.hash(of: [ActivityEvent(kind: .workout, minutes: 90)])
        let a = PlantFormula.parameters(
            seed: 424_242, nutrients: PlantNutrients(studyMinutes: 10, workoutMinutes: 0, sequenceHash: s1)
        )
        let b = PlantFormula.parameters(
            seed: 424_242, nutrients: PlantNutrients(studyMinutes: 9_999, workoutMinutes: 500, sequenceHash: s2)
        )
        XCTAssertEqual(a.dna, b.dna)
    }

    // MARK: - Milestones (shared unlock rules)

    func testMilestoneThresholds() {
        XCTAssertEqual(MilestoneKind.unlocked(totalMinutes: 599), [])
        XCTAssertEqual(MilestoneKind.unlocked(totalMinutes: 600), [.coral])
        XCTAssertEqual(
            MilestoneKind.unlocked(totalMinutes: 18_000),
            [.coral, .seaweed, .shipwreck, .lighthouse, .whale]
        )
    }

    func testMilestonesAppearInParameters() {
        let p = PlantFormula.parameters(
            seed: seed,
            nutrients: PlantNutrients(studyMinutes: 1_500, workoutMinutes: 0)
        )
        XCTAssertEqual(p.milestones.map(\.kind), [.coral, .seaweed])
        for mark in p.milestones {
            XCTAssertTrue((0.0...1.0).contains(mark.xRatio))
        }
    }
}
