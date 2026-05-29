// FirestoreSyncService+Deletion — erases the signed-in user's server data for
// in-app account deletion (App Review guideline 5.1.1(v)).
//
// What it removes: the public profile doc, the entire /private backup subtree,
// the user's own friends list, and the user's membership in every group.
// What necessarily remains (and is disclosed in the privacy policy): chat
// messages in shared rooms (immutable by rules, and now unlinked from any
// profile) and cached friend rows other users hold (we can't write to another
// user's friends list on delete). Both are opaque once the profile doc is gone.

import Foundation
import FirebaseAuth
import FirebaseFirestore

extension FirestoreSyncService {
    /// Best-effort full erase of the caller's server data. Runs while still
    /// authenticated (must precede `currentUser.delete()`). Never throws —
    /// deletion must proceed to the local wipe even if some docs fail.
    func deleteAllServerData(myUid: String, myFriendCode: String) async {
        let usersRef = db.collection("users").document(myUid)

        // 1. Private backup subtree — delete every item in each collection.
        for collection in ["sessions", "runs", "subjects", "ddays", "planner", "plant"] {
            let items = usersRef.collection("private").document(collection).collection("items")
            await deleteAll(in: items)
        }

        // 2. My own friends subcollection.
        await deleteAll(in: usersRef.collection("friends"))

        // 3. Remove myself from every group I belong to. arrayRemove targets
        //    only my own uid/code, leaving the room intact for other members.
        do {
            let groups = try await db.collection("groups")
                .whereField("memberUids", arrayContains: myUid)
                .getDocuments()
            for doc in groups.documents {
                do {
                    try await doc.reference.updateData([
                        "memberUids": FieldValue.arrayRemove([myUid]),
                        "memberCodes": FieldValue.arrayRemove([myFriendCode]),
                        "updatedAt": FieldValue.serverTimestamp(),
                    ])
                } catch {
                    Persistence.log(error, context: "firestore.delete.group")
                }
            }
        } catch {
            Persistence.log(error, context: "firestore.delete.groupsQuery")
        }

        // 4. The public profile doc itself (removes nickname/friendCode/uid map).
        do {
            try await usersRef.delete()
        } catch {
            Persistence.log(error, context: "firestore.delete.userDoc")
        }
    }

    /// Deletes every document in a collection one page at a time. Client SDKs
    /// have no recursive delete, so we enumerate and remove individually.
    private func deleteAll(in collection: CollectionReference) async {
        do {
            let snapshot = try await collection.getDocuments()
            for doc in snapshot.documents {
                do {
                    try await doc.reference.delete()
                } catch {
                    Persistence.log(error, context: "firestore.delete.doc.\(collection.collectionID)")
                }
            }
        } catch {
            Persistence.log(error, context: "firestore.delete.list.\(collection.collectionID)")
        }
    }
}
