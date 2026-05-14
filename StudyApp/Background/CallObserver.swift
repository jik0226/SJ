// CallObserver — bridges CXCallObserver into SceneSignal.
// Permission-free; tracks any incoming or outgoing call.

import Foundation
import CallKit
import StudyCore

@MainActor
final class CallObserver: NSObject {
    var onSignal: ((SceneSignal) -> Void)?
    private let observer = CXCallObserver()
    private var activeCallUUIDs: Set<UUID> = []

    func start() {
        observer.setDelegate(self, queue: nil)
    }

    func stop() {
        observer.setDelegate(nil, queue: nil)
        activeCallUUIDs.removeAll()
    }
}

extension CallObserver: CXCallObserverDelegate {
    nonisolated func callObserver(_ observer: CXCallObserver, callChanged call: CXCall) {
        let id = call.uuid
        let ended = call.hasEnded
        Task { @MainActor in
            let wasActive = self.activeCallUUIDs.contains(id)
            if ended {
                guard wasActive else { return }
                self.activeCallUUIDs.remove(id)
                if self.activeCallUUIDs.isEmpty {
                    self.onSignal?(.phoneCallEnded)
                }
            } else {
                guard !wasActive else { return }
                self.activeCallUUIDs.insert(id)
                if self.activeCallUUIDs.count == 1 {
                    self.onSignal?(.phoneCallStarted)
                }
            }
        }
    }
}
