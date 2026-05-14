// SceneSignal — the multi-source events that BackgroundGuard reacts to.
// In the iOS app each signal is fed by a different adapter (scenePhase,
// CallKit, AVAudioSession, AVPictureInPictureController, UIScene geometry).

import Foundation

public enum SceneSignal: Equatable, Sendable {
    /// App moved to background (home screen, app switch, force-quit attempt).
    case enteredBackground
    /// App became active again from background or inactive.
    case becameActive
    /// `.inactive` transient (Control Center, notification banner). Ignored.
    case becameInactive
    /// Device locked while app was foregrounded.
    case screenLocked
    /// Device unlocked.
    case screenUnlocked
    /// Incoming or active phone call.
    case phoneCallStarted
    /// Phone call ended.
    case phoneCallEnded
    /// Non-call audio interruption (Siri, alarm).
    case audioInterruptionBegan
    case audioInterruptionEnded
    /// Picture-in-Picture started — counts as distraction.
    case pictureInPictureStarted
    case pictureInPictureEnded
    /// In Split View / Stage Manager our window shrank below 50% of its scene.
    case splitViewShrunk
    case splitViewRestored
    /// User explicitly tapped pause/resume.
    case userPaused
    case userResumed
    /// User explicitly stopped the session.
    case userEnded
    /// Lecture-mode cap (3h) reached for the current session.
    case lectureCapReached
}
