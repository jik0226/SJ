// BackgroundGuardAdapter — aggregates iOS observers and pipes them as
// SceneSignals into the core BackgroundGuard.

import Foundation
import StudyCore

@MainActor
final class BackgroundGuardAdapter {
    private let guard_: BackgroundGuard
    private let screenLock = ScreenLockObserver()
    private let calls = CallObserver()
    private let audio = AudioInterruptionObserver()
    private let geometry = SceneGeometryObserver()

    private var started = false

    init(guard_: BackgroundGuard) {
        self.guard_ = guard_
        wire()
    }

    private func wire() {
        screenLock.onSignal = { [weak self] in self?.guard_.ingest($0) }
        calls.onSignal      = { [weak self] in self?.guard_.ingest($0) }
        audio.onSignal      = { [weak self] in self?.guard_.ingest($0) }
        geometry.onSignal   = { [weak self] in self?.guard_.ingest($0) }
    }

    func start() {
        guard !started else { return }
        started = true
        screenLock.start()
        calls.start()
        audio.start()
        geometry.start()
    }

    func stop() {
        guard started else { return }
        started = false
        screenLock.stop()
        calls.stop()
        audio.stop()
        geometry.stop()
    }
}
