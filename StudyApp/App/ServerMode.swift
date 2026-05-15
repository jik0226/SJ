// ServerMode — global observable for "is the server reachable + signed in?".
//
// The app's core (timer, planner, ocean, widgets) works without any server.
// Social features (friends, DMs, group chat) require Firestore + Auth. When
// either is offline we render a small banner so users understand why the
// social tab might be inert; the rest of the app keeps running.

import Foundation
import SwiftUI

@MainActor
@Observable
final class ServerMode {
    static let shared = ServerMode()

    enum State: Equatable {
        case bootstrapping
        case online
        case offline(reason: String)
    }

    private(set) var state: State = .bootstrapping

    func reportOnline() {
        state = .online
    }

    func reportOffline(reason: String) {
        // Avoid flapping the banner during normal sign-in races: once we're
        // online don't downgrade to offline unless something explicit failed.
        switch state {
            case .online:
                state = .offline(reason: reason)
            default:
                state = .offline(reason: reason)
        }
    }

    var isOnline: Bool {
        if case .online = state { return true }
        return false
    }
}
