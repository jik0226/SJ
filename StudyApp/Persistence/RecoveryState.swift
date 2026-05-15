// RecoveryState — surfaces ModelContainer boot status so the UI can warn
// the user when their data was sidelined into a backup, or when this session
// is running in a non-persisting in-memory fallback.
//
// Singleton because `AppModelContainer.shared` is created before the SwiftUI
// `@Environment` graph exists; the home view reads from this on first frame.

import Foundation
import SwiftUI

@MainActor
@Observable
final class RecoveryState {
    static let shared = RecoveryState()

    /// nil when boot was normal. Non-nil when the user should see a warning.
    private(set) var warning: Warning?

    enum Warning: Equatable {
        /// The previous SwiftData store could not be opened; it was archived
        /// to `backupURL` and the app started with a fresh store.
        case archivedAfterFailedOpen(backupURL: URL)
        /// Both the primary and recovery disk paths failed. The app is
        /// running in an in-memory store — writes won't survive a restart.
        case inMemorySession
    }

    func report(_ status: AppModelContainer.BootStatus) {
        switch status {
            case .normal:
                warning = nil
            case .startedFreshAfterBackup(let url):
                warning = .archivedAfterFailedOpen(backupURL: url)
            case .inMemoryFallback:
                warning = .inMemorySession
        }
    }

    /// User dismissed the banner. The warning won't surface again this run;
    /// next launch will re-evaluate because `AppModelContainer` reports on
    /// every boot.
    func acknowledge() {
        warning = nil
    }
}
