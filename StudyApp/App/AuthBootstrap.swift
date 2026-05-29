// AuthBootstrap — owns the app's Firebase Authentication state.
//
// Strategy: anonymous-first, optional Google upgrade.
//   - First launch: silently mint an anonymous UID. No login screen.
//   - User opts in: link the anon credential to a Google account. The UID
//     is preserved so all existing groups/messages/data stay attached.
//   - Sign-in is restored from keychain on subsequent launches.
//
// Anonymous-only UIDs are fragile: they evaporate if the user reinstalls or
// changes phones without iCloud keychain sync. Linking to Google promotes the
// account to a permanent identity tied to a Google email.

import Foundation
import FirebaseAuth
import FirebaseCore
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class AuthBootstrap {
    static let shared = AuthBootstrap()

    /// nil until the first sign-in attempt resolves. Non-nil + valid means
    /// any caller can safely write to Firestore with `currentUID`.
    private(set) var currentUID: String?

    /// Set when the last sign-in attempt failed. Surfaced in the friends
    /// view footer so users understand why server features aren't working.
    private(set) var lastError: String?

    /// Raw nonce generated for an in-flight Sign in with Apple request. It must
    /// survive between the request callback (where its SHA256 is sent to Apple)
    /// and the completion callback (where the raw value proves the token).
    /// See AuthBootstrap+Apple.swift.
    var currentAppleNonce: String?

    /// True iff the current user has linked their anon credential to a
    /// permanent provider (Google). When false, data is only as durable as
    /// the keychain on the current device.
    var isLinked: Bool {
        guard let user = Auth.auth().currentUser else { return false }
        // `isAnonymous` flips to false the moment a provider is linked.
        return !user.isAnonymous
    }

    /// e-mail of the linked Google account when present.
    var linkedEmail: String? {
        Auth.auth().currentUser?.providerData.first(where: {
            $0.providerID == "google.com"
        })?.email
    }

    private init() {
        currentUID = Auth.auth().currentUser?.uid
    }

    func signInIfNeeded() async {
        if let cached = Auth.auth().currentUser {
            currentUID = cached.uid
            lastError = nil
            ServerMode.shared.reportOnline()
            return
        }
        do {
            let result = try await Auth.auth().signInAnonymously()
            currentUID = result.user.uid
            lastError = nil
            ServerMode.shared.reportOnline()
        } catch {
            currentUID = nil
            lastError = error.localizedDescription
            ServerMode.shared.reportOffline(reason: "익명 로그인 실패: \(error.localizedDescription)")
        }
    }

    enum LinkError: LocalizedError {
        case notSignedIn
        case googleClientNotConfigured
        case googleTokenMissing
        case appleTokenMissing
        case unknown(String)

        var errorDescription: String? {
            switch self {
                case .notSignedIn:
                    return "익명 로그인이 아직 끝나지 않았어요. 잠시 후 다시 시도해주세요."
                case .googleClientNotConfigured:
                    return "Google 로그인이 Firebase 콘솔에서 활성화되지 않았어요. (관리자에게 문의)"
                case .googleTokenMissing:
                    return "Google 토큰을 받지 못했어요. 다시 시도해주세요."
                case .appleTokenMissing:
                    return "Apple 인증 토큰을 받지 못했어요. 다시 시도해주세요."
                case .unknown(let msg):
                    return msg
            }
        }
    }

    /// Resets local auth state and mints a fresh anonymous identity. Called
    /// after account deletion so the app keeps working with an empty account.
    func resetAndReSignInAnonymously() async {
        currentUID = nil
        lastError = nil
        await signInIfNeeded()
    }

    /// Adopts a freshly linked UID. Exposed so the Apple-linking extension (a
    /// separate file) can update the `private(set)` UID after `user.link`.
    func noteLinkedUID(_ uid: String) {
        currentUID = uid
        lastError = nil
    }

    /// Promotes the anonymous user to a Google-backed account. The UID is
    /// preserved so friends/groups/messages stay attached. Caller passes the
    /// presenting UIViewController so the Google sheet has somewhere to land.
    func linkWithGoogle() async throws {
        #if canImport(GoogleSignIn) && canImport(UIKit)
        guard let user = Auth.auth().currentUser else { throw LinkError.notSignedIn }
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw LinkError.googleClientNotConfigured
        }
        guard let presenter = Self.topViewController() else {
            throw LinkError.unknown("표시할 화면을 찾지 못했어요.")
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        } catch {
            throw LinkError.unknown(error.localizedDescription)
        }
        guard let idToken = result.user.idToken?.tokenString else {
            throw LinkError.googleTokenMissing
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        do {
            let linked = try await user.link(with: credential)
            currentUID = linked.user.uid
            lastError = nil
        } catch {
            throw LinkError.unknown(error.localizedDescription)
        }
        #else
        throw LinkError.googleClientNotConfigured
        #endif
    }

    #if canImport(UIKit)
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
        let root = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        var current = root
        while let presented = current?.presentedViewController {
            current = presented
        }
        return current
    }
    #endif

    var isSignedIn: Bool { currentUID != nil }
}
