// PomodoroSettings — global pomodoro config persisted in UserDefaults.
// Single config for the whole app; the timer auto-pauses + notifies after
// `workMinutes`. The user manually resumes after a break.

import Foundation

@MainActor
enum PomodoroSettings {
    private static let defaults = UserDefaults.standard
    private static let enabledKey = "pomodoro.enabled"
    private static let workKey = "pomodoro.workMinutes"
    private static let restKey = "pomodoro.restMinutes"

    static var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    static var workMinutes: Int {
        get {
            let v = defaults.integer(forKey: workKey)
            return v == 0 ? 25 : v
        }
        set { defaults.set(max(1, newValue), forKey: workKey) }
    }

    static var restMinutes: Int {
        get {
            let v = defaults.integer(forKey: restKey)
            return v == 0 ? 5 : v
        }
        set { defaults.set(max(1, newValue), forKey: restKey) }
    }
}
