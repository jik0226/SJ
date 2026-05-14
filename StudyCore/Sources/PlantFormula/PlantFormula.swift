// PlantFormula — deterministic procedural-plant parameters.
//
// A plant is fully described by (seed, studyMinutes, workoutMinutes).
// Given those three numbers, every renderer should produce the same shape.
// No images, no AI assets — the entire mascot is a small set of math
// expressions the user can later inspect.

import Foundation

public struct PlantNutrients: Equatable, Sendable {
    public var studyMinutes: Int
    public var workoutMinutes: Int

    public init(studyMinutes: Int = 0, workoutMinutes: Int = 0) {
        self.studyMinutes = max(0, studyMinutes)
        self.workoutMinutes = max(0, workoutMinutes)
    }

    public var totalMinutes: Int { studyMinutes + workoutMinutes }

    public var studyRatio: Double {
        guard totalMinutes > 0 else { return 0.5 }
        return Double(studyMinutes) / Double(totalMinutes)
    }
}

/// Everything a renderer needs to draw the plant.
public struct PlantParameters: Equatable, Sendable {
    /// Vertical extent of the stem in unit space. Renderers scale this to
    /// fit their canvas.
    public let stemHeight: Double
    /// Stem amplitude — how curvy the stem is (sin wave).
    public let stemAmplitude: Double
    /// Frequency of the stem sin wave.
    public let stemFrequency: Double
    /// How many discrete leaves to place along the stem.
    public let leafCount: Int
    /// Rose-curve petal count for each leaf (r = a·cos(n·θ)).
    public let leafPetals: Int
    /// Base leaf size.
    public let leafSize: Double
    /// HSL hue in 0..1.
    public let stemHue: Double
    public let leafHue: Double
    /// Whether the plant has reached the flowering stage.
    public let hasFlower: Bool
    /// Seed reused by renderers to add deterministic jitter (leaf offset etc.).
    public let seed: UInt64
}

public enum PlantFormula {
    public static func parameters(seed: UInt64, nutrients: PlantNutrients) -> PlantParameters {
        let total = Double(nutrients.totalMinutes)
        let study = Double(nutrients.studyMinutes)
        let workout = Double(nutrients.workoutMinutes)

        // Stem height grows logarithmically so the plant doesn't disappear
        // off the top of the screen after a few weeks.
        let stemHeight = log10(total + 1.0) * 30.0 + 20.0
        let stemAmplitude = 4.0 + sqrt(workout / 30.0)
        let stemFrequency = 1.2 + (Double(seed % 100) / 100.0) * 0.6   // seed jitter
        let leafCount = min(20, 2 + Int(log10(total + 1.0) * 4.0))
        let leafPetals = 3 + Int(workout / 60.0) % 5                    // 3..7 petals
        let leafSize = 4.0 + log(workout + 1.0) * 1.5

        // Study leans green (0.30), workout leans amber (0.12). Mix by ratio.
        let leafHue = 0.12 + (0.30 - 0.12) * nutrients.studyRatio
        let stemHue = max(0.25, leafHue - 0.05)

        // Bonus flower when both pillars are well-fed.
        let hasFlower = study >= 6 * 60 && workout >= 90

        return PlantParameters(
            stemHeight: stemHeight,
            stemAmplitude: stemAmplitude,
            stemFrequency: stemFrequency,
            leafCount: leafCount,
            leafPetals: leafPetals,
            leafSize: leafSize,
            stemHue: stemHue,
            leafHue: leafHue,
            hasFlower: hasFlower,
            seed: seed
        )
    }

    /// Human-readable formula string the user can inspect in the detail sheet.
    public static func formulaDescription(
        seed: UInt64, nutrients: PlantNutrients
    ) -> [PlantFormulaLine] {
        let p = parameters(seed: seed, nutrients: nutrients)
        return [
            .init(label: "줄기 높이",
                  formula: "log₁₀(총분 + 1) × 30 + 20",
                  value: String(format: "%.1f", p.stemHeight)),
            .init(label: "줄기 진폭",
                  formula: "4 + √(운동 분 ÷ 30)",
                  value: String(format: "%.2f", p.stemAmplitude)),
            .init(label: "줄기 진동수",
                  formula: "1.2 + (seed mod 100) ÷ 100 × 0.6",
                  value: String(format: "%.2f", p.stemFrequency)),
            .init(label: "잎 개수",
                  formula: "min(20, 2 + ⌊log₁₀(총분 + 1) × 4⌋)",
                  value: "\(p.leafCount)"),
            .init(label: "잎 모양 (장미곡선 꽃잎)",
                  formula: "3 + ⌊운동 분 ÷ 60⌋ mod 5",
                  value: "\(p.leafPetals)"),
            .init(label: "잎 크기",
                  formula: "4 + ln(운동 분 + 1) × 1.5",
                  value: String(format: "%.2f", p.leafSize)),
            .init(label: "잎 색 (HSL hue)",
                  formula: "0.12 + (0.30 − 0.12) × 공부비율",
                  value: String(format: "%.3f", p.leafHue)),
            .init(label: "꽃 개화",
                  formula: "공부 ≥ 360분 ∧ 운동 ≥ 90분",
                  value: p.hasFlower ? "예" : "아직"),
        ]
    }
}

public struct PlantFormulaLine: Hashable, Sendable {
    public let label: String
    public let formula: String
    public let value: String

    public init(label: String, formula: String, value: String) {
        self.label = label
        self.formula = formula
        self.value = value
    }
}
