// AccountDeletionService — one-call in-app account + data deletion required by
// App Review guideline 5.1.1(v). Order matters: server data must be erased
// while still authenticated, then the auth identity is dropped, then local
// storage is wiped, then a fresh anonymous identity is minted so the app keeps
// working from an empty state.

import Foundation
import SwiftData
import FirebaseAuth

@MainActor
enum AccountDeletionService {
    /// Erases everything tied to the current account and resets the app to a
    /// clean anonymous state. Returns true on completion. Best-effort: a
    /// failure in any single step still proceeds so the user is never left
    /// half-deleted with their data intact.
    @discardableResult
    static func deleteEverything(context: ModelContext) async -> Bool {
        let me = SocialService.me(in: context)
        let myUid = AuthBootstrap.shared.currentUID ?? Auth.auth().currentUser?.uid
        let myFriendCode = me.friendCode

        // 1. Server erase — must run while the user is still authenticated.
        if let myUid {
            await FirestoreSyncService.shared.deleteAllServerData(
                myUid: myUid, myFriendCode: myFriendCode
            )
        }

        // 2. Tear down live listeners before dropping the session.
        FirestoreSyncService.shared.stopListeningFriends()
        FirestoreSyncService.shared.stopListeningMyGroups()

        // 3. Delete the auth user (best effort — linked accounts may need a
        //    recent login). Then sign out unconditionally so the next sign-in
        //    mints a brand-new anonymous UID rather than reusing the old one.
        do {
            try await Auth.auth().currentUser?.delete()
        } catch {
            Persistence.log(error, context: "auth.deleteUser")
        }
        try? Auth.auth().signOut()

        // 4. Wipe all local SwiftData so nothing survives on-device.
        wipeLocalStore(context: context)

        // 5. Fresh anonymous identity so the app is immediately usable again.
        await AuthBootstrap.shared.resetAndReSignInAnonymously()
        return true
    }

    /// Batch-deletes every persisted model. Listed explicitly so adding a new
    /// @Model forces a conscious decision about whether deletion must cover it.
    private static func wipeLocalStore(context: ModelContext) {
        try? context.delete(model: StudySessionModel.self)
        try? context.delete(model: RunSessionModel.self)
        try? context.delete(model: SubjectModel.self)
        try? context.delete(model: DDayModel.self)
        try? context.delete(model: PlannerBlockModel.self)
        try? context.delete(model: DailyPageModel.self)
        try? context.delete(model: PlantModel.self)
        try? context.delete(model: FriendProfileModel.self)
        try? context.delete(model: StudyGroupModel.self)
        try? context.delete(model: ChatMessageModel.self)
        Persistence.save({ try context.save() }, context: "account.wipeLocal")
    }
}
