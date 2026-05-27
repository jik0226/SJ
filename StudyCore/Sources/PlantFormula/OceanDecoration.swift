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
