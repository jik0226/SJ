// CloudKitService — skeleton for the W3.D wire.
//
// Stage 1 (this commit): availability probe + record-type constants + safe
// no-op publish/fetch entrypoints so call sites can be wired now and the real
// CKQueryOperation paths fill in next.
//
// Why a skeleton: shipping CloudKit needs an Apple Developer Program account,
// a registered iCloud container, and a logged-in iCloud user. Until that's
// available, calls here return `.disabled` and the local SwiftData mock keeps
// driving the UI.

import Foundation
import CloudKit
import StudyCore

@MainActor
final class CloudKitService {
    static let shared = CloudKitService()

    /// Container is intentionally nil until iCloud entitlement is actually
    /// signed into the binary (Apple Developer Program account + registered
    /// container). Constructing `CKContainer(identifier:)` without the
    /// entitlement traps the process, so we keep this off until the W3.D
    /// wire-up swaps it back in.
    private let container: CKContainer? = nil

    // Record-type vocabulary the eventual schema will use.
    enum RecordType {
        static let profile = "UserProfile"
        static let group = "StudyGroup"
        static let chatMessage = "ChatMessage"
        static let report = "Report"
    }

    enum Availability: Equatable {
        case ready          // iCloud account + container reachable
        case noAccount      // user not signed in to iCloud
        case restricted     // parental / MDM block
        case temporarilyUnavailable
        case disabled       // CK not wired for this build (no Apple Dev account yet)
    }

    private(set) var availability: Availability = .disabled

    /// Probes the iCloud account status. Safe to call at app boot; never throws.
    func probeAvailability() async {
        // Container is nil until W3.D — keep disabled and bail.
        guard let container else {
            availability = .disabled
            return
        }
        do {
            let status = try await container.accountStatus()
            switch status {
                case .available:
                    availability = .ready
                case .noAccount:
                    availability = .noAccount
                case .restricted:
                    availability = .restricted
                case .couldNotDetermine, .temporarilyUnavailable:
                    availability = .temporarilyUnavailable
                @unknown default:
                    availability = .temporarilyUnavailable
            }
        } catch {
            availability = .temporarilyUnavailable
        }
    }

    // MARK: - Publish stubs

    /// Pushes the local "me" UserProfile to the Public DB so other devices can
    /// discover by friendCode. Stage 1: returns false without doing work.
    @discardableResult
    func publishProfile(friendCode: String, nickname: String) async -> Bool {
        guard container != nil, availability == .ready else { return false }
        // TODO(W3.D-2): CKRecord(recordType: RecordType.profile) save in publicCloudDatabase.
        return false
    }

    /// Mirrors a chat message to the Shared DB so recipients in the same group
    /// see it after sync. Stage 1: returns false.
    @discardableResult
    func publishChatMessage(
        groupId: UUID, senderFriendCode: String, text: String, sentAt: Date
    ) async -> Bool {
        guard container != nil, availability == .ready else { return false }
        // TODO(W3.D-3): CKShare wire-up for the group, then CKRecord save.
        return false
    }

    // MARK: - Fetch stubs

    /// Resolves a friendCode to a remote UserProfile (or nil when unavailable).
    /// Stage 1: returns nil; the local SwiftData lookup is authoritative.
    func fetchProfile(friendCode: String) async -> (nickname: String, mascotSpecies: String, mascotStage: Int)? {
        guard container != nil, availability == .ready else { return nil }
        // TODO(W3.D-2): public predicate "friendCode == %@", fetch the first match.
        return nil
    }
}
