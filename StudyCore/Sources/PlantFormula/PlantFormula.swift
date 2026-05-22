// OceanFormula — deterministic procedural ocean parameters.
//
// (seed, studyMinutes, workoutMinutes) → multi-layered wave + fish school.
// Renderer is pure math: superposed sin waves for the surface, parametric
// bezier-like curves for fish. No images.
//
// Naming note: the file lives in PlantFormula/ for git-history continuity,
// but everything inside is the ocean system. The old plant types are gone.

import Foundation

public struct PlantNutrients: Equatable, Sendable {
    public var studyMinutes: Int
    public var workoutMinutes: Int
    /// Hash derived from the *order* the user accumulated study/workout time.
    /// Two users with identical totals but different activity orderings get
    /// different wave phases + fish placement, so the ocean reflects "how"
    /// you studied, not just "how much". 0 = no sequence info (legacy).
    public var sequenceHash: UInt64

    public init(studyMinutes: Int = 0, workoutMinutes: Int = 0, sequenceHash: UInt64 = 0) {
        self.studyMinutes = max(0, studyMinutes)
        self.workoutMinutes = max(0, workoutMinutes)
        self.sequenceHash = sequenceHash
    }

    public var totalMinutes: Int { studyMinutes + workoutMinutes }

    public var studyRatio: Double {
        guard totalMinutes > 0 else { return 0.5 }
        return Double(studyMinutes) / Double(totalMinutes)
    }
}

/// One logged activity. The ordered list of these is what makes the ocean
/// order-sensitive — see `PlantNutrients.sequenceHash`.
public struct ActivityEvent: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case study, workout }
    public let kind: Kind
    public let minutes: Int
    public let at: Date

    public init(kind: Kind, minutes: Int, at: Date = Date()) {
        self.kind = kind
        self.minutes = minutes
        self.at = at
    }

    /// Compact token folded into the sequence hash.
    public var token: String { "\(kind.rawValue):\(minutes)" }
}

public enum ActivitySequence {
    /// FNV-1a over the ordered event tokens. Deterministic, order-sensitive:
    /// reordering events changes the hash, which changes wave phases + fish.
    public static func hash(of events: [ActivityEvent]) -> UInt64 {
        var h: UInt64 = 14695981039346656037
        for ev in events {
            for byte in ev.token.utf8 {
                h ^= UInt64(byte)
                h = h &* 1099511628211
            }
            h ^= 0x2C  // comma separator so "1,23" ≠ "12,3"
            h = h &* 1099511628211
        }
        return h
    }
}

/// One sinusoidal wave layer: `y = baseY + amplitude·sin(frequency·x + phase)`.
public struct WaveLayer: Hashable, Sendable {
    public let amplitude: Double
    public let frequency: Double
    public let phase: Double
    /// 0 (back) .. 1 (front). Drives both vertical placement and color saturation.
    public let depth: Double
}

/// One fish drawn as a parametric closed curve.
/// Position is normalized 0..1 within the canvas.
public struct FishMark: Hashable, Sendable {
    public let xRatio: Double
    public let yRatio: Double
    public let sizeRatio: Double
    public let bodyHue: Double
    /// true = facing right, false = facing left.
    public let facingRight: Bool
}

public struct OceanParameters: Equatable, Sendable {
    /// 1..4 wave layers, back-to-front order.
    public let waves: [WaveLayer]
    /// 0..N fish.
    public let fish: [FishMark]
    /// Background gradient base hue (rough → calm blue band).
    public let bgHue: Double
    public let seed: UInt64
}

/// Convenience alias so existing PlantWidget / PlantCanvas call sites compile.
public typealias PlantParameters = OceanParameters

public enum PlantFormula {
    public static func parameters(seed: UInt64, nutrients: PlantNutrients) -> OceanParameters {
        let total = Double(nutrients.totalMinutes)
        let study = Double(nutrients.studyMinutes)
        let workout = Double(nutrients.workoutMinutes)

        // Fold activity ordering into the seed used for *placement* (phase +
        // fish jitter). Layer/fish COUNTS still come from totals, but the
        // arrangement now depends on the order you studied vs. worked out.
        let seed = seed ^ nutrients.sequenceHash

        // 1..4 wave layers, more layers as the user accumulates time.
        let layerCount = min(4, max(1, 1 + Int(log10(total + 1.0) * 1.5)))
        var waves: [WaveLayer] = []
        for i in 0..<layerCount {
            let depth = Double(i) / Double(max(1, layerCount - 1))
            // Amplitude grows with workout minutes (more "energy" in the sea),
            // frequency grows with study minutes (more "detail" / focus).
            let amplitude = 4.0 + sqrt(workout / 20.0) + Double(i) * 1.5
            let frequency = 0.4 + log(study + 1.0) * 0.08 + Double(i) * 0.15
            // Seed-driven phase so two users with the same totals still
            // get different-looking surfaces.
            let phase = Double((seed &+ UInt64(i * 7919)) % 1000) / 1000.0 * (2 * .pi)
            waves.append(WaveLayer(amplitude: amplitude, frequency: frequency, phase: phase, depth: depth))
        }

        // Fish count grows with total minutes; a milestone-based rule so it
        // doesn't get crowded but every hour of study is a visible win.
        let fishCount = min(12, max(0, Int(log10(total + 1.0) * 3.0) - 1))
        var fish: [FishMark] = []
        for i in 0..<fishCount {
            // Distribute deterministically using golden-ratio jitter.
            let golden = 0.6180339887
            let jx = (Double(i) * golden + Double(seed % 100) / 100.0).truncatingRemainder(dividingBy: 1)
            let jy = (Double(i) * golden * 2 + Double((seed >> 8) % 100) / 100.0).truncatingRemainder(dividingBy: 1)
            let size = 0.04 + (Double(i % 3) * 0.015)
            // Hue varies by study/workout ratio so the school colors shift over time.
            let hue = (0.55 + nutrients.studyRatio * 0.10 + jy * 0.05).truncatingRemainder(dividingBy: 1)
            fish.append(FishMark(
                xRatio: jx,
                yRatio: 0.45 + jy * 0.45,    // mid → deep water
                sizeRatio: size,
                bodyHue: hue,
                facingRight: (i % 2 == 0)
            ))
        }

        // Background base color: more workout → warmer (sunset), more study → cooler (dawn).
        let bgHue = 0.58 - nutrients.studyRatio * 0.05

        return OceanParameters(waves: waves, fish: fish, bgHue: bgHue, seed: seed)
    }

    /// Human-readable formula description shown in the detail sheet.
    public static func formulaDescription(
        seed: UInt64, nutrients: PlantNutrients
    ) -> [PlantFormulaLine] {
        let p = parameters(seed: seed, nutrients: nutrients)
        var lines: [PlantFormulaLine] = [
            .init(label: "파도 레이어 수",
                  formula: "min(4, 1 + ⌊log₁₀(총분 + 1) × 1.5⌋)",
                  value: "\(p.waves.count)"),
            .init(label: "파도 진폭 (기본)",
                  formula: "4 + √(운동 분 ÷ 20)",
                  value: String(format: "%.2f", 4.0 + sqrt(Double(nutrients.workoutMinutes) / 20.0))),
            .init(label: "파도 진동수 (기본)",
                  formula: "0.4 + ln(공부 분 + 1) × 0.08",
                  value: String(format: "%.2f", 0.4 + log(Double(nutrients.studyMinutes) + 1.0) * 0.08)),
            .init(label: "물고기 수",
                  formula: "min(12, max(0, ⌊log₁₀(총분 + 1) × 3⌋ - 1))",
                  value: "\(p.fish.count)"),
            .init(label: "배경 색조 (HSL hue)",
                  formula: "0.58 - 공부비율 × 0.05",
                  value: String(format: "%.3f", p.bgHue)),
            .init(label: "활동 순서 시드",
                  formula: "FNV-1a(공부·운동 발생 순서) XOR 씨앗",
                  value: String(nutrients.sequenceHash % 100000)),
        ]
        for (i, wave) in p.waves.enumerated() {
            lines.append(.init(
                label: "파도 #\(i + 1)",
                formula: "y = \(String(format: "%.1f", wave.amplitude)) · sin(\(String(format: "%.2f", wave.frequency))x + \(String(format: "%.2f", wave.phase)))",
                value: "depth \(String(format: "%.2f", wave.depth))"
            ))
        }
        return lines
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
