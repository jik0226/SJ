// GuardPolicy — pure decision table mapping (signal, context) -> action.
// Keeping this separate from BackgroundGuard makes the rules trivially testable
// and tweakable by product without touching the runtime adapter.

import Foundation

public enum GuardAction: Equatable, Sendable {
    case ignore
    case pause(reason: PauseTrigger)
    case stop(reason: PauseTrigger)
    case resume
    case end
}

public enum PauseTrigger: String, Equatable, Sendable {
    case userManual
    case background
    case screenLock
    case phoneCall
    case audio
    case pip
    case splitView
    case lectureCap
}

public struct GuardContext: Equatable, Sendable {
    public var subjectAllowsPhoneUse: Bool
    public var lockedScreenAllowed: Bool
    public var lectureSecondsElapsed: Int

    public init(
        subjectAllowsPhoneUse: Bool,
        lockedScreenAllowed: Bool = false,
        lectureSecondsElapsed: Int = 0
    ) {
        self.subjectAllowsPhoneUse = subjectAllowsPhoneUse
        self.lockedScreenAllowed = lockedScreenAllowed
        self.lectureSecondsElapsed = lectureSecondsElapsed
    }
}

public struct GuardPolicy: Sendable {
    public init() {}

    public func decide(
        signal: SceneSignal, context: GuardContext
    ) -> GuardAction {
        // Lecture mode wins for distraction-style signals — but the 3h cap
        // is enforced separately so users can't sit on it forever.
        if context.subjectAllowsPhoneUse, isDistractionSignal(signal) {
            return .ignore
        }

        switch signal {
            case .enteredBackground:
                return .stop(reason: .background)
            case .screenLocked:
                return context.lockedScreenAllowed ? .ignore : .stop(reason: .screenLock)
            case .pictureInPictureStarted:
                return .stop(reason: .pip)
            case .splitViewShrunk:
                return .stop(reason: .splitView)

            case .phoneCallStarted:
                return .pause(reason: .phoneCall)
            case .phoneCallEnded:
                return .resume
            case .audioInterruptionBegan:
                return .pause(reason: .audio)
            case .audioInterruptionEnded:
                return .resume

            case .becameInactive, .becameActive,
                 .screenUnlocked, .pictureInPictureEnded, .splitViewRestored:
                return .ignore

            case .userPaused:
                return .pause(reason: .userManual)
            case .userResumed:
                return .resume
            case .userEnded:
                return .end
            case .lectureCapReached:
                return .stop(reason: .lectureCap)
        }
    }

    private func isDistractionSignal(_ signal: SceneSignal) -> Bool {
        switch signal {
            case .enteredBackground, .screenLocked,
                 .pictureInPictureStarted, .splitViewShrunk:
                return true
            default:
                return false
        }
    }
}
