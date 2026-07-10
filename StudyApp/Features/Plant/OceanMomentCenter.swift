// OceanMomentCenter — publishes a "your ocean just changed" moment right
// after a session's minutes are pumped into the plant, so the growth is felt
// at the instant of effort instead of being discovered later on the home tab.
// RootView observes `current` and presents OceanMomentSheet.

import Foundation
import Observation
import StudyCore

struct OceanMoment: Identifiable {
    let id = UUID()
    let before: OceanParameters
    let after: OceanParameters
    let addedMinutes: Int
    let kind: ActivityEvent.Kind

    /// Short celebratory lines derived from what visibly changed. Ordered by
    /// how exciting the change is; the sheet shows at most two.
    var changeCallouts: [String] {
        var lines: [String] = []
        if before.mascot != after.mascot {
            lines.append("새 친구 \(after.mascot.koreanName)\(after.mascot.emoji)가 찾아왔어요!")
        }
        if after.fish.count > before.fish.count {
            lines.append("물고기가 \(after.fish.count - before.fish.count)마리 늘었어요 🐟")
        }
        if after.seabed.count > before.seabed.count {
            lines.append("불가사리가 생겼어요 ⭐")
        }
        if after.waves.count > before.waves.count {
            lines.append("파도가 한 겹 깊어졌어요 🌊")
        }
        if after.mood != before.mood {
            lines.append("바다의 분위기가 바뀌었어요 ✨")
        }
        return lines
    }
}

extension OceanMascot {
    var koreanName: String {
        switch self {
            case .turtle: return "거북이"
            case .octopus: return "문어"
            case .crab: return "게"
        }
    }
    var emoji: String {
        switch self {
            case .turtle: return "🐢"
            case .octopus: return "🐙"
            case .crab: return "🦀"
        }
    }
}

@MainActor
@Observable
final class OceanMomentCenter {
    static let shared = OceanMomentCenter()
    var current: OceanMoment?
    private init() {}
}
