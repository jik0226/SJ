// SocialLogicTests — pure social/chat logic that previously lived in the app
// target with no coverage: DM id determinism, attachment payload JSON
// round-trips, and activity-sequence hashing.

import XCTest
@testable import StudyCore

final class SocialLogicTests: XCTestCase {

    // MARK: - Direct message id determinism

    func testDMIDStableForSameSortedPair() {
        let a = DirectMessageKey.deterministicID(forSortedCodes: ["ABC123", "DEF456"])
        let b = DirectMessageKey.deterministicID(forSortedCodes: ["ABC123", "DEF456"])
        XCTAssertEqual(a, b, "Same sorted codes must yield the same group id")
    }

    func testDMIDBothMembersConverge() {
        // Each device builds the pair as [self, other].sorted(), so regardless
        // of who initiates, the sorted input — and thus the id — matches.
        let fromA = ["ME0001", "FRND02"].sorted()
        let fromB = ["FRND02", "ME0001"].sorted()
        XCTAssertEqual(
            DirectMessageKey.deterministicID(forSortedCodes: fromA),
            DirectMessageKey.deterministicID(forSortedCodes: fromB)
        )
    }

    func testDMIDDiffersByPair() {
        let pair1 = DirectMessageKey.deterministicID(forSortedCodes: ["ABC123", "DEF456"])
        let pair2 = DirectMessageKey.deterministicID(forSortedCodes: ["ABC123", "GHI789"])
        XCTAssertNotEqual(pair1, pair2)
    }

    func testDMIDIsValidUUID() {
        // The hand-formatted 8-4-4-4-12 string must parse as a real UUID
        // (not silently fall back to a random one).
        let id = DirectMessageKey.deterministicID(forSortedCodes: ["ZZZ999", "AAA111"])
        let again = DirectMessageKey.deterministicID(forSortedCodes: ["ZZZ999", "AAA111"])
        XCTAssertEqual(id, again)  // determinism implies the parse succeeded
    }

    // MARK: - Attachment payload JSON round-trip

    func testPlannerPayloadRoundTrip() throws {
        let original = AttachmentPayload.Planner(slots: ["30": "#4DABF7", "31": "#FF6B6B"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AttachmentPayload.Planner.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testOceanPayloadRoundTrip() throws {
        let original = AttachmentPayload.Ocean(
            seed: 12345, study: 60, workout: 30, name: "내 바다", sequenceHash: 999
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AttachmentPayload.Ocean.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testOceanPayloadSequenceHashRoundTripsLosslessly() throws {
        // UInt64.max loses precision if encoded through a Double. The share
        // path JSON-encodes the hash, so assert the full 64-bit value survives
        // — otherwise the receiver rebuilds a subtly different ocean.
        let original = AttachmentPayload.Ocean(
            seed: -42, study: 120, workout: 0, name: "x", sequenceHash: .max
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AttachmentPayload.Ocean.self, from: data)
        XCTAssertEqual(decoded.sequenceHash, .max)
        XCTAssertEqual(original, decoded)
    }

    func testOceanPayloadLegacyJSONDecodesWithNilSequenceHash() throws {
        // Messages sent before sequenceHash existed carry no such key; decoding
        // must still succeed (nil → treated as 0 / legacy unordered shape) so
        // old chat history doesn't break.
        let legacy = #"{"seed":1,"study":2,"workout":3,"name":"old"}"#
        let decoded = try JSONDecoder().decode(
            AttachmentPayload.Ocean.self, from: XCTUnwrap(legacy.data(using: .utf8))
        )
        XCTAssertNil(decoded.sequenceHash)
        XCTAssertEqual(decoded.seed, 1)
    }

    func testStreakPayloadRoundTrip() throws {
        let original = AttachmentPayload.Streak(days: 7)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AttachmentPayload.Streak.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testPayloadDecodeFromStringRoundsTripViaUTF8() throws {
        // Mirrors the app path: encode → String(utf8) → store → data(utf8) → decode.
        let ocean = AttachmentPayload.Ocean(seed: 7, study: 10, workout: 0, name: "x")
        let json = String(data: try JSONEncoder().encode(ocean), encoding: .utf8)
        let back = try JSONDecoder().decode(
            AttachmentPayload.Ocean.self,
            from: XCTUnwrap(json?.data(using: .utf8))
        )
        XCTAssertEqual(ocean, back)
    }

    // MARK: - Activity sequence hashing

    func testActivitySequenceEmptyIsStable() {
        XCTAssertEqual(ActivitySequence.hash(of: []), ActivitySequence.hash(of: []))
    }

    func testActivitySequenceOrderSensitive() {
        let e1 = ActivityEvent(kind: .study, minutes: 60)
        let e2 = ActivityEvent(kind: .workout, minutes: 30)
        XCTAssertNotEqual(
            ActivitySequence.hash(of: [e1, e2]),
            ActivitySequence.hash(of: [e2, e1])
        )
    }

    func testActivitySequenceValueSensitive() {
        // "1,23" must not collide with "12,3" — the separator byte guards this.
        let a = ActivitySequence.hash(of: [
            ActivityEvent(kind: .study, minutes: 1),
            ActivityEvent(kind: .study, minutes: 23),
        ])
        let b = ActivitySequence.hash(of: [
            ActivityEvent(kind: .study, minutes: 12),
            ActivityEvent(kind: .study, minutes: 3),
        ])
        XCTAssertNotEqual(a, b)
    }
}
