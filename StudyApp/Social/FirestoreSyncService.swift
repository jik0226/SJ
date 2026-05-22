// FirestoreSyncService — owns the outbound + inbound bridge to Firestore.
//
// Local SwiftData remains the source of truth so the app keeps working
// offline. This service mirrors every relevant write to Firestore and pulls
// down the user's own data when a fresh device signs in.
//
// Structure:
//   users/{uid}                            — public profile + opt-in summary
//   users/{uid}/private/sessions/{id}      — study sessions (back-up only)
//   users/{uid}/private/runs/{id}          — run sessions
//   users/{uid}/private/subjects/{id}      — subject definitions
//   users/{uid}/private/ddays/{id}         — d-day entries
//   users/{uid}/private/planner/{slotKey}  — planner block assignments
//   users/{uid}/private/plant/state        — ocean nutrient counters
//   groups/{gid}                           — group meta
//   chats/{gid}/messages/{mid}             — chat messages
//
// Privacy: writes to `users/{uid}` (public) gate every field on
// PrivacyPreferences. The /private subtree is always synced — only the owner
// can read it (enforced by Firestore rules).
//
// The outbound publish path lives in FirestoreSyncService+Outbound.swift and
// the inbound pull/listener path in FirestoreSyncService+Inbound.swift. Stored
// properties and the shared ref helpers must stay here because Swift
// extensions cannot declare stored properties.

import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore
import StudyCore

@MainActor
final class FirestoreSyncService {
    static let shared = FirestoreSyncService()

    let db = Firestore.firestore()
    var groupListeners: [UUID: ListenerRegistration] = [:]
    var friendsListener: ListenerRegistration?
    var myGroupsListener: ListenerRegistration?

    private init() {}

    var uid: String? { Auth.auth().currentUser?.uid }
    func userRef() -> DocumentReference? {
        guard let uid else { return nil }
        return db.collection("users").document(uid)
    }
    func privateDoc(_ collection: String, _ id: String) -> DocumentReference? {
        userRef()?.collection("private").document(collection).collection("items").document(id)
    }

    // MARK: - Lookups

    /// Lookup outcomes are explicit so callers can distinguish "no such
    /// record" from "server unreachable / permission denied". Collapsing
    /// both into nil previously made network errors masquerade as typos.
    enum LookupOutcome<T> {
        case found(T)
        case notFound
        case error(LookupError)
    }
}

enum FirestoreSyncError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        switch self {
            case .notSignedIn:
                return "익명 로그인이 완료되기 전이에요. 잠시 후 다시 시도해주세요."
        }
    }
}

/// Categorises Firestore failures so UI can show the *real* reason rather
/// than collapsing everything into "코드 없음" or "추가에 실패했습니다".
enum LookupError: LocalizedError {
    case unauthenticated
    case permissionDenied
    case network
    case unknown(String)

    static func from(_ error: Error) -> LookupError {
        let ns = error as NSError
        // FirestoreErrorCode: 7 = permissionDenied, 14 = unavailable, 4 = deadlineExceeded.
        switch ns.code {
            case 7: return .permissionDenied
            case 4, 14: return .network
            default:
                return .unknown(error.localizedDescription)
        }
    }

    /// User-facing copy only — no developer jargon ("Firestore", error codes).
    /// The technical cause is already written to OSLog via Persistence.log at
    /// the call site, so support can still diagnose without alarming the user.
    var errorDescription: String? {
        switch self {
            case .unauthenticated:
                return "서버 연결을 준비 중이에요. 잠시 후 다시 시도해주세요."
            case .permissionDenied:
                return "서버 연결에 문제가 있어요. 잠시 후 다시 시도하거나 문의해주세요."
            case .network:
                return "인터넷 연결을 확인하고 다시 시도해주세요."
            case .unknown:
                return "일시적인 오류가 발생했어요. 잠시 후 다시 시도해주세요."
        }
    }
}

struct RemoteFriend: Sendable {
    let uid: String
    let friendCode: String
    let nickname: String
}

struct RemoteGroup: Sendable {
    let id: UUID
    let code: String
    let name: String
    let memberCodes: [String]
}
