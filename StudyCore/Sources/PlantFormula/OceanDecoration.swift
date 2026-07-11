// OceanDecoration — supplementary types for the extended ocean system.
//
// Mood palette, mascot, sky token, bubbles, seabed marks, and mascot placement.
// All types are pure value types: Equatable + Sendable, no side effects.

import Foundation

// MARK: - Mood palette

/// The headline differentiator: five buckets mapped to study/workout ratio.
/// Drives background gradient hues, wave tint, mascot, and sky token.
public enum OceanMood: String, Equatable, Sendable, CaseIterable {
    /// studyRatio ≥ 0.72 — deep night-sea indigo; very study-focused.
    case deepStudy
    /// studyRatio 0.58 ..< 0.72 — cool blue-teal; study-leaning.
    case study
    /// studyRatio 0.42 ..< 0.58 — aqua-green; balanced.
    case balanced
    /// studyRatio 0.28 ..< 0.42 — warm turquoise→coral; active-leaning.
    case active
    /// studyRatio < 0.28 — sunset coral; very workout-focused.
    case deepActive

    public static func from(studyRatio: Double) -> OceanMood {
        switch studyRatio {
        case 0.72...:      return .deepStudy
        case 0.58..<0.72:  return .study
        case 0.42..<0.58:  return .balanced
        case 0.28..<0.42:  return .active
        default:           return .deepActive
        }
    }

    /// Top background hue (sky/surface). Values are HSB hue in 0..1.
    public var topHue: Double {
        switch self {
        case .deepStudy:   return 0.70  // deep indigo night
        case .study:       return 0.63  // cool blue
        case .balanced:    return 0.52  // aqua-green
        case .active:      return 0.47  // warm turquoise
        case .deepActive:  return 0.07  // sunset coral/orange
        }
    }

    /// Bottom background hue (deep water).
    public var bottomHue: Double {
        switch self {
        case .deepStudy:   return 0.67  // dark indigo
        case .study:       return 0.60  // ocean blue
        case .balanced:    return 0.50  // teal
        case .active:      return 0.42  // coral-teal
        case .deepActive:  return 0.03  // deep coral
        }
    }

    /// Accent hue for fish tint, wave overlay, and decorations.
    public var accentHue: Double {
        switch self {
        case .deepStudy:   return 0.75  // violet accent
        case .study:       return 0.58  // sky blue
        case .balanced:    return 0.45  // mint
        case .active:      return 0.10  // warm orange
        case .deepActive:  return 0.05  // coral-red
        }
    }
}

// MARK: - Mascot

/// The signature creature uniquely representing the user's dominant activity.
public enum OceanMascot: String, Equatable, Sendable {
    /// study-dominant (ratio ≥ 0.58) — turtle with round shell + flippers.
    case turtle
    /// balanced (0.42 ..< 0.58) — octopus with wavy tentacles.
    case octopus
    /// active-dominant (ratio < 0.42) — crab with claws + legs.
    case crab

    public static func from(studyRatio: Double) -> OceanMascot {
        switch studyRatio {
        case 0.58...:      return .turtle
        case 0.42..<0.58:  return .octopus
        default:           return .crab
        }
    }

    public var koreanName: String {
        switch self {
        case .turtle: return "거북이"
        case .octopus: return "문어"
        case .crab: return "게"
        }
    }

    public var emoji: String {
        switch self {
        case .turtle: return "🐢"
        case .octopus: return "🐙"
        case .crab: return "🦀"
        }
    }
}

// MARK: - Sky token

/// The top-corner sky decoration matching the mood.
public enum SkyToken: String, Equatable, Sendable {
    /// study-side moods — crescent moon + 2-3 tiny stars.
    case moon
    /// balanced mood — fluffy cloud (overlapping circles).
    case cloud
    /// active-side moods — sun with short rays.
    case sun

    public static func from(mood: OceanMood) -> SkyToken {
        switch mood {
        case .deepStudy, .study:    return .moon
        case .balanced:             return .cloud
        case .active, .deepActive:  return .sun
        }
    }
}

// MARK: - Ocean DNA

/// Permanent per-user appearance traits derived from the RAW seed (before the
/// activity-order XOR), so they never change as the user studies — this is the
/// ocean's identity: "my turtle is mint, my fish are chubby with stripes".
/// Purely derived → the shared-ocean payload needs no new fields.
public struct OceanDNA: Equatable, Sendable {
    /// 0..7 mascot color variant. Applied as a hue offset to the mood accent.
    public let mascotVariant: Int
    /// 0..3 fish body shape shared by the whole school (round/long/tall/chubby).
    public let fishSpecies: Int
    /// 0..2 fish pattern: 0 = plain, 1 = stripes, 2 = dots.
    public let fishPattern: Int

    /// Evenly spaced around the color wheel; pastel saturation in the
    /// renderer keeps even the wild hues cute.
    public var mascotHueShift: Double { Double(mascotVariant) * 0.125 }

    /// Independent bit windows of the seed so traits don't correlate.
    public static func derive(from seed: UInt64) -> OceanDNA {
        OceanDNA(
            mascotVariant: Int((seed >> 3) % 8),
            fishSpecies: Int((seed >> 11) % 4),
            fishPattern: Int((seed >> 17) % 3)
        )
    }

    /// Friendly Korean species name — identity must be speakable ("통통이").
    public var speciesName: String {
        ["둥글이", "길쭉이", "볼록이", "통통이"][fishSpecies % 4]
    }

    public var patternName: String {
        ["민무늬", "줄무늬", "점박이"][fishPattern % 3]
    }

    /// One-line speakable identity, e.g. "민트 거북이 · 줄무늬 통통이".
    /// `accentHue` is the mood accent so the color name matches what's on
    /// screen (the same variant shifts different base hues).
    public func summary(mascot: OceanMascot, accentHue: Double) -> String {
        let tinted = (accentHue + mascotHueShift).truncatingRemainder(dividingBy: 1)
        return "\(OceanHueName.name(forHue: tinted)) \(mascot.koreanName) · \(patternName) \(speciesName)"
    }
}

/// Buckets an HSB hue (0..1) into a friendly Korean color name.
public enum OceanHueName {
    public static func name(forHue hue: Double) -> String {
        let h = (hue.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
        switch h {
        case ..<0.045:      return "코랄"
        case 0.045..<0.11:  return "주황"
        case 0.11..<0.19:   return "레몬"
        case 0.19..<0.40:   return "연두"
        case 0.40..<0.52:   return "민트"
        case 0.52..<0.62:   return "하늘"
        case 0.62..<0.80:   return "라벤더"
        case 0.80..<0.93:   return "핑크"
        default:            return "코랄"
        }
    }
}

// MARK: - Milestones

/// Long-term decorations unlocked by TOTAL accumulated minutes. Thresholds
/// are shared rules (not seed-dependent) so "내 바다에 등대 떴어" is a
/// comparable brag; only the placement varies per user.
public enum MilestoneKind: String, CaseIterable, Equatable, Sendable {
    case coral       // 10 hours
    case seaweed     // 25 hours
    case shipwreck   // 50 hours
    case lighthouse  // 100 hours
    case whale       // 300 hours

    public var thresholdMinutes: Int {
        switch self {
        case .coral:      return 600
        case .seaweed:    return 1_500
        case .shipwreck:  return 3_000
        case .lighthouse: return 6_000
        case .whale:      return 18_000
        }
    }

    public var koreanName: String {
        switch self {
        case .coral:      return "산호"
        case .seaweed:    return "해초"
        case .shipwreck:  return "난파선"
        case .lighthouse: return "등대"
        case .whale:      return "고래"
        }
    }

    /// Celebration line for the session-end moment sheet when this milestone
    /// first appears (grammar-correct particles per word).
    public var celebrationText: String {
        switch self {
        case .coral:      return "🪸 산호가 자라났어요!"
        case .seaweed:    return "🌿 해초가 자라났어요!"
        case .shipwreck:  return "⚓ 난파선이 나타났어요!"
        case .lighthouse: return "🗼 등대가 세워졌어요!"
        case .whale:      return "🐋 고래가 찾아왔어요!"
        }
    }

    public static func unlocked(totalMinutes: Int) -> [MilestoneKind] {
        allCases.filter { totalMinutes >= $0.thresholdMinutes }
    }
}

/// One placed milestone decoration (x position is seed-derived).
public struct MilestoneMark: Equatable, Sendable {
    public let kind: MilestoneKind
    /// Horizontal position 0..1.
    public let xRatio: Double

    public init(kind: MilestoneKind, xRatio: Double) {
        self.kind = kind
        self.xRatio = xRatio
    }
}

// MARK: - Decoration marks

/// A rising bubble — count driven by workout minutes (energy).
public struct BubbleMark: Hashable, Sendable {
    /// Horizontal position 0..1.
    public let xRatio: Double
    /// Vertical start position 0..1 (higher value = lower on canvas).
    public let yRatio: Double
    /// Normalized radius as fraction of canvas min-dimension.
    public let sizeRatio: Double
}

/// Kind of seabed creature (extensible, only starfish for now).
public enum SeabedKind: String, Equatable, Sendable {
    case starfish
}

/// A seabed ornament resting near the bottom — count driven by study minutes.
public struct SeabedMark: Hashable, Sendable {
    public let kind: SeabedKind
    /// Horizontal position 0..1.
    public let xRatio: Double
    /// Accent hue for the creature's color (HSB 0..1).
    public let hue: Double
    /// Normalized scale as fraction of canvas min-dimension.
    public let sizeRatio: Double
}

/// Position and scale for the mascot creature (all normalized 0..1).
public struct MascotPlacement: Equatable, Sendable {
    public let xRatio: Double
    public let yRatio: Double
    /// Size as a fraction of min(canvasWidth, canvasHeight).
    public let sizeRatio: Double
}
