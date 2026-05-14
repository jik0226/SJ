// ScreenLockObserver — emits SceneSignal.screenLocked / .screenUnlocked.
//
// Primary signal: `protectedDataWillBecomeUnavailable` (fires on lock when the
// device has a passcode). Passcode-less devices don't publish the protectedData
// notification, but they DO transition through `scenePhase == .background` when
// locked, which `AppState.handleScenePhase` already maps to `.enteredBackground`
// → `.stop`. So this observer is intentionally narrow: it adds a stronger lock
// label on passcode'd devices and stays silent otherwise.

import Foundation
import UIKit
import StudyCore

@MainActor
final class ScreenLockObserver {
    var onSignal: ((SceneSignal) -> Void)?
    private var lockObserver: NSObjectProtocol?
    private var unlockObserver: NSObjectProtocol?

    func start() {
        stop()
        let center = NotificationCenter.default
        lockObserver = center.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onSignal?(.screenLocked) }
        }
        unlockObserver = center.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onSignal?(.screenUnlocked) }
        }
    }

    func stop() {
        if let l = lockObserver { NotificationCenter.default.removeObserver(l) }
        if let u = unlockObserver { NotificationCenter.default.removeObserver(u) }
        lockObserver = nil
        unlockObserver = nil
    }
}
