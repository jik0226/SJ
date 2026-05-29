// AuthBootstrap+Apple — Sign in with Apple linking.
//
// Apple ID is linked onto the existing anonymous user so the UID (and all
// friends/groups/chat attached to it) is preserved, exactly like the Google
// path. Firebase requires the raw nonce to match the SHA256 nonce that was
// sent to Apple, so we generate it in `prepareAppleRequest` and consume it in
// `linkWithApple`. Required by App Review guideline 4.8 (a privacy option
// alongside Google).

import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

extension AuthBootstrap {
    /// Configure an Apple ID request: generate a fresh nonce, stash the raw
    /// value, and send only its SHA256 hash to Apple. Call from the
    /// SignInWithAppleButton `onRequest` closure.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Links the returned Apple credential onto the current (anonymous) user.
    /// Call from the SignInWithAppleButton `onCompletion` success branch.
    func linkWithApple(authorization: ASAuthorization) async throws {
        guard let user = Auth.auth().currentUser else { throw LinkError.notSignedIn }
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentAppleNonce,
              let tokenData = appleCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw LinkError.appleTokenMissing
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )
        do {
            let linked = try await user.link(with: credential)
            noteLinkedUID(linked.user.uid)
            currentAppleNonce = nil
        } catch {
            currentAppleNonce = nil
            throw LinkError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Nonce helpers (Apple-recommended boilerplate)

    /// Cryptographically secure random nonce string from a fixed alphabet.
    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess { continue }
            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
