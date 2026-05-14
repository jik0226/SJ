// FriendCode — 6-character alnum code (A-Z + 2-9, no easily-confused chars).

import Foundation

enum FriendCode {
    private static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate() -> String {
        var rng = SystemRandomNumberGenerator()
        return String((0..<6).map { _ in alphabet.randomElement(using: &rng)! })
    }

    static func sanitize(_ raw: String) -> String {
        // Strip forbidden chars, cap at 6 so the visible TextField never drifts
        // past what `isValid` accepts.
        let filtered = raw.uppercased().filter { c in alphabet.contains(c) }
        return String(filtered.prefix(6))
    }

    static func isValid(_ raw: String) -> Bool {
        let s = sanitize(raw)
        return s.count == 6 && s.allSatisfy { alphabet.contains($0) }
    }
}
