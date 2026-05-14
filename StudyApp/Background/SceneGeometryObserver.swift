// SceneGeometryObserver — detects Split View / Stage Manager shrink.
// Coarse polling (30s) since the event isn't on a publishable path; sceneDidActivate
// notification gives an instant check when the user comes back to our app
// (covers the "switch back from Stage Manager" boundary at ≪ 30s).

import Foundation
import UIKit
import Combine
import StudyCore

@MainActor
final class SceneGeometryObserver {
    var onSignal: ((SceneSignal) -> Void)?

    @MainActor
    private var cancellable: AnyCancellable?
    @MainActor
    private var lastIsShrunk: Bool = false
    @MainActor
    private var activationObserver: NSObjectProtocol?

    func start() {
        stop()
        cancellable = Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.check() }
        activationObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
        check()
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
        if let token = activationObserver {
            NotificationCenter.default.removeObserver(token)
        }
        activationObserver = nil
        lastIsShrunk = false
    }

    private func check() {
        guard let scene = activeWindowScene() else { return }
        let sceneWidth = scene.coordinateSpace.bounds.width
        let screenWidth = scene.screen.bounds.width
        guard screenWidth > 0 else { return }
        let isShrunk = sceneWidth < (screenWidth * 0.5)
        if isShrunk != lastIsShrunk {
            lastIsShrunk = isShrunk
            onSignal?(isShrunk ? .splitViewShrunk : .splitViewRestored)
        }
    }

    private func activeWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
}
