// Subject — study/workout category configured by the user.
// Pure value type so the core engine remains storage-agnostic.

import Foundation

public enum SubjectCategory: String, Codable, Sendable, CaseIterable {
    case study
    case workout
}

public enum WorkoutType: String, Codable, Sendable, CaseIterable {
    case running
    case walking
    case cycling
    case gym
    case free

    public var label: String {
        switch self {
            case .running: return "러닝"
            case .walking: return "걷기"
            case .cycling: return "자전거"
            case .gym: return "헬스"
            case .free: return "자유 운동"
        }
    }

    public var completedLabel: String {
        switch self {
            case .running: return "러닝 완료"
            case .walking: return "걷기 완료"
            case .cycling: return "자전거 완료"
            case .gym: return "운동 완료"
            case .free: return "운동 완료"
        }
    }

    public var usesGPS: Bool {
        self == .running || self == .walking || self == .cycling
    }

    public var defaultSFSymbol: String {
        switch self {
            case .running: return "figure.run"
            case .walking: return "figure.walk"
            case .cycling: return "bicycle"
            case .gym: return "dumbbell.fill"
            case .free: return "figure.flexibility"
        }
    }

    /// Rough Metabolic Equivalent of Task values for kcal estimation.
    /// Source: 2011 Compendium of Physical Activities, moderate-intensity
    /// rows. The values are deliberately conservative.
    public var metValue: Double {
        switch self {
            case .running: return 9.8      // ~8 km/h
            case .walking: return 3.5      // ~5 km/h
            case .cycling: return 7.5      // 16–19 km/h
            case .gym:     return 6.0
            case .free:    return 5.0
        }
    }
}

public struct Subject: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var colorHex: String
    public var sfSymbol: String
    /// When true, BackgroundGuard ignores stop signals for sessions on this subject.
    /// Capped per session by `Subject.lectureModeMaxSeconds`.
    public var allowPhoneUse: Bool
    public var category: SubjectCategory
    public var dailyTargetMinutes: Int
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        sfSymbol: String,
        allowPhoneUse: Bool = false,
        category: SubjectCategory,
        dailyTargetMinutes: Int = 60,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sfSymbol = sfSymbol
        self.allowPhoneUse = allowPhoneUse
        self.category = category
        self.dailyTargetMinutes = dailyTargetMinutes
        self.createdAt = createdAt
    }

    /// Hard cap on a single lecture-mode session (3 hours).
    public static let lectureModeMaxSeconds: Int = 3 * 60 * 60
}
