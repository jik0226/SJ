// TimerState — state machine vocabulary for TimerEngine.

import Foundation

public enum TimerState: Equatable, Sendable {
    case idle
    case running
    case paused
    case ended
}

public enum TimerError: Error, Equatable, Sendable {
    case alreadyRunning
    case notRunning
    case notPaused
    case noActiveSession
}
