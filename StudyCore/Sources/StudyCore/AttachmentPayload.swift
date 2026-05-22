// AttachmentPayload — decoded payloads for rich chat attachments.
//
// Encoded into ChatMessageModel.attachedPayloadJSON and decoded by the chat
// bubble per AttachedKind. Pure Codable (Foundation only) so the JSON
// round-trip is unit-testable without the app target.

import Foundation

public enum AttachmentPayload {
    /// slotIndex(0..143) → colorHex, for a mini planner grid.
    public struct Planner: Codable, Equatable {
        public var slots: [String: String]
        public init(slots: [String: String]) { self.slots = slots }
    }

    /// Reproduces the sender's ocean from deterministic inputs.
    public struct Ocean: Codable, Equatable {
        public var seed: Int
        public var study: Int
        public var workout: Int
        public var name: String
        public init(seed: Int, study: Int, workout: Int, name: String) {
            self.seed = seed
            self.study = study
            self.workout = workout
            self.name = name
        }
    }

    public struct Streak: Codable, Equatable {
        public var days: Int
        public init(days: Int) { self.days = days }
    }
}
