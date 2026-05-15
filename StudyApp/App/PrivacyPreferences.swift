// PrivacyPreferences — per-field opt-in for sharing summary data with friends.
//
// Stored in UserDefaults so toggles survive relaunch. FirestoreSyncService
// reads these gates before publishing to the user's *public* document; the
// private (per-uid) backup is always synced regardless of these flags.

import Foundation

@MainActor
enum PrivacyPreferences {
    private static let defaults = UserDefaults.standard

    enum Field: String, CaseIterable, Sendable {
        case todayStudyMinutes
        case weekStudyMinutes
        case streakDays
        case oceanShape
        case plannerToday

        var key: String { "privacy.\(rawValue)" }

        var label: String {
            switch self {
                case .todayStudyMinutes: return "오늘 순공시간"
                case .weekStudyMinutes: return "이번주 누적 순공시간"
                case .streakDays: return "연속 학습 일수"
                case .oceanShape: return "내 바다 모양"
                case .plannerToday: return "오늘 플래너 슬롯"
            }
        }

        var detail: String {
            switch self {
                case .todayStudyMinutes: return "친구가 내 오늘 공부 시간을 볼 수 있어요."
                case .weekStudyMinutes: return "친구가 내 이번주 누적 시간을 볼 수 있어요."
                case .streakDays: return "친구가 내 연속 학습 일수를 볼 수 있어요."
                case .oceanShape: return "친구가 내 바다 모양 (파도·물고기 배치)을 볼 수 있어요. 영양분 수치는 공유되지 않습니다."
                case .plannerToday: return "친구가 내 오늘 플래너의 색상 그리드를 볼 수 있어요. 어떤 과목인지는 표시되지 않습니다."
            }
        }

        /// Defaults to off — opt-in beats opt-out for privacy.
        var defaultValue: Bool { false }
    }

    static func isEnabled(_ field: Field) -> Bool {
        if defaults.object(forKey: field.key) == nil {
            return field.defaultValue
        }
        return defaults.bool(forKey: field.key)
    }

    static func setEnabled(_ field: Field, _ value: Bool) {
        defaults.set(value, forKey: field.key)
    }
}
