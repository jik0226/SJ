// AudioInterruptionObserver — Siri / alarm / other non-call interruptions.
// CallKit covers actual phone calls; this catches everything else (Siri, etc).
//
// `NotificationCenter` is injected so tests can post synthetic interruption
// notifications without touching `AVAudioSession`.

import Foundation
import AVFAudio
import StudyCore

@MainActor
final class AudioInterruptionObserver {
    var onSignal: ((SceneSignal) -> Void)?
    private var observer: NSObjectProtocol?
    private let center: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.center = notificationCenter
    }

    func start() {
        stop()
        observer = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handle(note) }
        }
    }

    func stop() {
        if let o = observer { center.removeObserver(o) }
        observer = nil
    }

    func handle(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else {
            return
        }
        switch type {
            case .began: onSignal?(.audioInterruptionBegan)
            case .ended: onSignal?(.audioInterruptionEnded)
            @unknown default: break
        }
    }
}
