// SocialService+Friends — add/remove a friend by code. Server-backed when
// auth is ready (verify the code maps to a real user, mirror the friendship
// to both sides); falls back to a visibly-tagged demo stub when offline.

import Foundation
import SwiftData
import StudyCore

extension SocialService {
    @discardableResult
    static func addFriend(byCode raw: String, in context: ModelContext) async throws -> FriendProfileModel {
        let code = FriendCode.sanitize(raw)
        guard FriendCode.isValid(code) else { throw SocialError.invalidCode }
        // Reject the user's own code outright. Previously this matched the
        // `isMe` row silently, which made the sheet dismiss with no visible
        // friend added — confusing.
        let meRow = me(in: context)
        if code == meRow.friendCode { throw SocialError.selfCode }
        if let existing = try lookupFriend(code: code, in: context) {
            existing.isBlocked = false
            Persistence.save({ try context.save() }, context: "social.addFriend.existing")
            return existing
        }

        // Server-backed path: verify the code maps to a real user before
        // creating a local row. Offline fallback only happens when Firebase
        // auth hasn't bootstrapped yet — that path keeps the (데모) suffix so
        // the user never confuses an unverified entry for a real friend.
        if AuthBootstrap.shared.isSignedIn,
           let meUid = AuthBootstrap.shared.currentUID {
            switch await FirestoreSyncService.shared.lookupFriend(byCode: code) {
                case .notFound:
                    throw SocialError.codeNotFound
                case .error(let err):
                    throw SocialError.lookupError(err)
                case .found(let remote):
                    let real = FriendProfileModel(
                        friendCode: remote.friendCode,
                        nickname: remote.nickname,
                        mascotSpecies: .cat,
                        mascotStage: 0
                    )
                    context.insert(real)
                    guard Persistence.save({ try context.save() }, context: "social.addFriend.remote") != nil else {
                        context.delete(real)
                        throw SocialError.saveFailed
                    }
                    // Mirror the friendship to both sides — `await` so the
                    // other device sees us before this returns. If publish
                    // fails (rules/network), roll the local row back so the
                    // user never sees an "added but invisible" friend.
                    do {
                        try await FirestoreSyncService.shared.publishMutualFriendship(
                            meUid: meUid,
                            meCode: meRow.friendCode,
                            meNick: meRow.nickname,
                            otherUid: remote.uid,
                            otherCode: remote.friendCode,
                            otherNick: remote.nickname
                        )
                    } catch {
                        context.delete(real)
                        Persistence.save({ try context.save() }, context: "social.addFriend.rollback")
                        Persistence.log(error, context: "firestore.publishMutualFriendship")
                        throw SocialError.serverPublishFailed
                    }
                    return real
            }
        }

        // Offline / pre-auth fallback: keep the demo stub but tag it visibly.
        let stub = FriendProfileModel(
            friendCode: code,
            nickname: "(데모) 친구 \(code.prefix(3))",
            mascotSpecies: .cat,
            mascotStage: 0
        )
        context.insert(stub)
        guard Persistence.save({ try context.save() }, context: "social.addFriend.new") != nil else {
            context.delete(stub)
            throw SocialError.saveFailed
        }
        return stub
    }

    /// Removes a friend from the caller's side only (Kakao/Line semantics).
    /// Deletes both the local SwiftData row and the caller's server-side
    /// `users/{me}/friends/{other}` doc so the friends listener doesn't
    /// resurrect the row on next launch.
    static func removeFriend(_ friend: FriendProfileModel, in context: ModelContext) {
        let otherCode = friend.friendCode
        context.delete(friend)
        Persistence.save({ try context.save() }, context: "friend.delete")
        guard let meUid = AuthBootstrap.shared.currentUID else { return }
        Task {
            // Lookup the friend's UID by friendCode to delete the right doc.
            switch await FirestoreSyncService.shared.lookupFriend(byCode: otherCode) {
                case .found(let remote):
                    do {
                        try await FirestoreSyncService.shared.deleteFriendship(
                            meUid: meUid, otherUid: remote.uid
                        )
                    } catch {
                        Persistence.log(error, context: "firestore.deleteFriendship")
                    }
                case .notFound, .error:
                    break
            }
        }
    }
}
