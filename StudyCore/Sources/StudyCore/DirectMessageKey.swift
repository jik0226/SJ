// DirectMessageKey — deterministic 1:1 chat identifier.
//
// Both participants compute the SAME group UUID from their two friendCodes,
// regardless of who starts the chat, so messages converge on one document.
// Pure + Foundation/CryptoKit only → unit-testable without the app target.

import Foundation
import CryptoKit

public enum DirectMessageKey {
    /// SHA256-derived UUID from the participants' friendCodes. Callers MUST
    /// pass the codes pre-sorted so both sides agree on the value — the
    /// function does not sort, keeping the contract explicit.
    public static func deterministicID(forSortedCodes sortedCodes: [String]) -> UUID {
        let key = "dm|" + sortedCodes.joined(separator: "|")
        let digest = SHA256.hash(data: Data(key.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        // 8-4-4-4-12 layout from the first 32 hex chars of the digest.
        let s = Array(hex)
        let formatted = "\(String(s[0..<8]))-\(String(s[8..<12]))-\(String(s[12..<16]))-\(String(s[16..<20]))-\(String(s[20..<32]))"
        return UUID(uuidString: formatted) ?? UUID()
    }
}
