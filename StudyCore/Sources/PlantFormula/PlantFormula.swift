// OceanFormula — deterministic procedural ocean parameters.
//
// (seed, studyMinutes, workoutMinutes) → waves + fish + mascot + mood palette
// + bubbles + seabed + sky token. Pure math only; no images, no RNG, no Date().
// Supplementary types (OceanMood, OceanMascot, BubbleMark, …) live in
// OceanDecoration.swift in the same module.

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

// MARK: - Wave / Fish primitives

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

// MARK: - OceanParameters

public struct OceanParameters: Equatable, Sendable {
    /// 1..4 wave layers, back-to-front order.
    public let waves: [WaveLayer]
    /// 0..N fish (ambient school).
    public let fish: [FishMark]
    /// Background gradient base hue (back-compat; equals mood.topHue).
    public let bgHue: Double
    public let seed: UInt64

    // --- Differentiation fields (new) ---

    /// Mood bucket derived from studyRatio; drives palette + sky + mascot.
    public let mood: OceanMood
    /// Signature mascot creature for this user's activity combo.
    public let mascot: OceanMascot
    /// Where the mascot is placed on the canvas.
    public let mascotPlacement: MascotPlacement
    /// Sky decoration token shown in the top corner.
    public let skyToken: SkyToken
    /// Rising bubbles; count = min(10, workoutMinutes / 15).
    public let bubbles: [BubbleMark]
    /// Seabed starfish; count = min(6, studyMinutes / 30).
    public let seabed: [SeabedMark]
    /// Permanent per-user appearance traits (mascot color, fish species/pattern).
    public let dna: OceanDNA
    /// Long-term decorations unlocked by total minutes (coral → … → whale).
    public let milestones: [MilestoneMark]
}

/// Convenience alias so existing PlantWidget / PlantCanvas call sites compile.
public typealias PlantParameters = OceanParameters

// MARK: - Formula

public enum PlantFormula {
    public static func parameters(seed: UInt64, nutrients: PlantNutrients) -> OceanParameters {
        let total = Double(nutrients.totalMinutes)
        let study = Double(nutrients.studyMinutes)
        let workout = Double(nutrients.workoutMinutes)

        // DNA comes from the RAW seed — permanent identity traits that must
        // never drift as activity accumulates or reorders.
        let dna = OceanDNA.derive(from: seed)

        // Fold activity ordering into the seed used for *placement* (phase +
        // fish jitter). Layer/fish COUNTS still come from totals, but the
        // arrangement now depends on the order you studied vs. worked out.
        let seed = seed ^ nutrients.sequenceHash

        // Deterministic sub-seeds for each decoration category (LCG steps).
        let seedA = seed &* 6364136223846793005 &+ 1442695040888963407
        let seedB = seedA &* 6364136223846793005 &+ 1442695040888963407
        let seedC = seedB &* 6364136223846793005 &+ 1442695040888963407

        // MARK: Mood
        let mood = OceanMood.from(studyRatio: nutrients.studyRatio)

        // MARK: Waves — 1..4 layers
        let layerCount = min(4, max(1, 1 + Int(log10(total + 1.0) * 1.5)))
        var waves: [WaveLayer] = []
        for i in 0..<layerCount {
            let depth = Double(i) / Double(max(1, layerCount - 1))
            // Amplitude grows with workout (energy); frequency with study (detail).
            let amplitude = 4.0 + sqrt(workout / 20.0) + Double(i) * 1.5
            let frequency = 0.4 + log(study + 1.0) * 0.08 + Double(i) * 0.15
            let phase = Double((seed &+ UInt64(i * 7919)) % 1000) / 1000.0 * (2 * .pi)
            waves.append(WaveLayer(amplitude: amplitude, frequency: frequency, phase: phase, depth: depth))
        }

        // MARK: Fish — ambient school tinted by mood accent
        let fishCount = min(12, max(0, Int(log10(total + 1.0) * 3.0) - 1))
        let golden = 0.6180339887
        var fish: [FishMark] = []
        for i in 0..<fishCount {
            let jx = (Double(i) * golden + Double(seed % 100) / 100.0).truncatingRemainder(dividingBy: 1)
            let jy = (Double(i) * golden * 2 + Double((seed >> 8) % 100) / 100.0).truncatingRemainder(dividingBy: 1)
            let size = 0.04 + Double(i % 3) * 0.015
            let hue = (mood.accentHue + jy * 0.08).truncatingRemainder(dividingBy: 1)
            fish.append(FishMark(
                xRatio: jx,
                yRatio: 0.45 + jy * 0.45,
                sizeRatio: size,
                bodyHue: hue,
                facingRight: (i % 2 == 0)
            ))
        }

        // MARK: Bubbles — count = min(10, workoutMinutes / 15)
        let bubbleCount = min(10, nutrients.workoutMinutes / max(1, 15))
        var bubbles: [BubbleMark] = []
        for i in 0..<bubbleCount {
            let bx = (Double(i) * golden + Double(seedA % 97) / 97.0).truncatingRemainder(dividingBy: 1)
            let by = 0.4 + (Double(i) * golden * 1.3 + Double((seedA >> 16) % 53) / 53.0)
                .truncatingRemainder(dividingBy: 1) * 0.5
            let bSize = 0.008 + Double((seedA &+ UInt64(i * 3)) % 20) / 20.0 * 0.012
            bubbles.append(BubbleMark(xRatio: bx, yRatio: by, sizeRatio: bSize))
        }

        // MARK: Seabed — count = min(6, studyMinutes / 30)
        let seabedCount = min(6, nutrients.studyMinutes / max(1, 30))
        var seabed: [SeabedMark] = []
        for i in 0..<seabedCount {
            let sx = (Double(i) * golden * 1.7 + Double(seedB % 83) / 83.0).truncatingRemainder(dividingBy: 1)
            let hue = (mood.accentHue + Double((seedB &+ UInt64(i * 11)) % 30) / 30.0 * 0.2)
                .truncatingRemainder(dividingBy: 1)
            let sSize = 0.04 + Double((seedB &+ UInt64(i * 5)) % 15) / 15.0 * 0.025
            seabed.append(SeabedMark(kind: .starfish, xRatio: sx, hue: hue, sizeRatio: sSize))
        }

        // MARK: Mascot placement — deterministic by seed
        let mascot = OceanMascot.from(studyRatio: nutrients.studyRatio)
        let mascotX = 0.15 + Double(seedC % 71) / 71.0 * 0.70      // 0.15 .. 0.85
        let mascotY = 0.48 + Double((seedC >> 24) % 30) / 30.0 * 0.25  // mid-lower
        let mascotSize = 0.11 + Double((seedC >> 40) % 20) / 20.0 * 0.04  // 0.11..0.15
        let placement = MascotPlacement(xRatio: mascotX, yRatio: mascotY, sizeRatio: mascotSize)

        // MARK: Milestones — shared unlock thresholds, seed-derived placement.
        let milestones = MilestoneKind.unlocked(totalMinutes: nutrients.totalMinutes)
            .enumerated().map { (i, kind) in
                MilestoneMark(
                    kind: kind,
                    xRatio: 0.08 + Double((seedC >> (i * 7)) % 61) / 61.0 * 0.84
                )
            }

        return OceanParameters(
            waves: waves,
            fish: fish,
            bgHue: mood.topHue,
            seed: seed,
            mood: mood,
            mascot: mascot,
            mascotPlacement: placement,
            skyToken: SkyToken.from(mood: mood),
            bubbles: bubbles,
            seabed: seabed,
            dna: dna,
            milestones: milestones
        )
    }

    // formulaDescription (the "내 바다의 식" sheet) lives in
    // PlantFormulaDescription.swift to keep this file within the size limit.
}
