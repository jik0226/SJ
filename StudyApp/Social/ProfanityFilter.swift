// ProfanityFilter — V1 keyword block list for cellog messages.
// PoC scope: a small Korean + English seed list, case-insensitive,
// whitespace/punctuation-tolerant. Not a complete moderation system —
// the W3.D / W3.F tracks will add ML-based scoring + report SLA.

import Foundation

enum ProfanityFilter {
    private static let blockedKeywords: [String] = [
        // Korean — common slurs / harassment seeds. Intentionally short.
        "씨발", "ㅅㅂ", "씹", "개새끼", "병신", "ㅂㅅ", "좆", "ㅈ같", "엿먹",
        // English
        "fuck", "shit", "bitch", "asshole",
    ]

    enum CheckResult: Equatable {
        case clean
        case blocked(reason: String)
    }

    static func check(_ text: String) -> CheckResult {
        let normalized = normalize(text)
        for keyword in blockedKeywords {
            if normalized.contains(normalize(keyword)) {
                return .blocked(reason: "메시지에 부적절한 표현이 포함되어 있어요.")
            }
        }
        return .clean
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .components(separatedBy: .whitespacesAndNewlines).joined()
            .components(separatedBy: .punctuationCharacters).joined()
    }
}
