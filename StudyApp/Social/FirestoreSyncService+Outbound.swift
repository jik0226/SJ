// FirestoreSyncService+Outbound — the write path that mirrors local SwiftData
// changes up to Firestore. Public profile writes gate every summary field on
// PrivacyPreferences; the /private subtree always syncs (owner-only by rules).

import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore
import StudyCore

extension FirestoreSyncService {
    // MARK: - Public profile (gated by PrivacyPreferences)

    /// Publishes the user's *discoverable* fields. Every summary field is
    /// gated on PrivacyPreferences so off-by-default opt-in is honoured.
    /// FriendCode + nickname are always published (otherwise friend lookup
    /// can't work at all).
    func publishMe(_ profile: FriendProfileModel) {
        guard let uid, let ref = userRef() else { return }
        // Don't publish a placeholder/empty name — until the user picks a
        // display name they shouldn't be discoverable, otherwise friends
        // see a blank or "나" entry.
        guard !profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var data: [String: Any] = [
            "uid": uid,
            "friendCode": profile.friendCode,
            "nickname": profile.nickname,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        if PrivacyPreferences.isEnabled(.todayStudyMinutes) {
            data["todayStudyMinutes"] = profile.todayStudyMinutes
        } else {
            data["todayStudyMinutes"] = FieldValue.delete()
        }
        // Other summary fields are derived elsewhere (see publishSummaryFields).
        Task {
            do {
                try await ref.setData(data, merge: true)
            } catch {
                Persistence.log(error, context: "firestore.publishMe")
            }
        }
    }

    /// Pushes derived summary numbers (week minutes, streak, planner+ocean
    /// snapshots) honoring each privacy flag. Called whenever the underlying
    /// data changes — cheap because Firestore merges deletes if disabled.
    func publishSummaryFields(
        weekMinutes: Int,
        streakDays: Int,
        oceanSeed: Int?,
        oceanNutrients: (study: Int, workout: Int)?,
        plannerTodaySlots: [Int: String]?
    ) {
        guard let ref = userRef() else { return }
        var data: [String: Any] = ["updatedAt": FieldValue.serverTimestamp()]
        data["weekStudyMinutes"] = PrivacyPreferences.isEnabled(.weekStudyMinutes)
            ? weekMinutes : FieldValue.delete()
        data["streakDays"] = PrivacyPreferences.isEnabled(.streakDays)
            ? streakDays : FieldValue.delete()
        // Ocean shape is fully reproducible from (seed, study, workout).
        if PrivacyPreferences.isEnabled(.oceanShape),
           let seed = oceanSeed, let n = oceanNutrients {
            data["oceanSeed"] = seed
            data["oceanStudy"] = n.study
            data["oceanWorkout"] = n.workout
        } else {
            data["oceanSeed"] = FieldValue.delete()
            data["oceanStudy"] = FieldValue.delete()
            data["oceanWorkout"] = FieldValue.delete()
        }
        // Planner: map slotIndex -> color hex. Subject name intentionally not
        // shared — friends only see the color pattern.
        if PrivacyPreferences.isEnabled(.plannerToday), let slots = plannerTodaySlots {
            data["plannerTodaySlots"] = slots.reduce(into: [String: String]()) { acc, kv in
                acc[String(kv.key)] = kv.value
            }
        } else {
            data["plannerTodaySlots"] = FieldValue.delete()
        }
        Task {
            do {
                try await ref.setData(data, merge: true)
            } catch {
                Persistence.log(error, context: "firestore.publishSummary")
            }
        }
    }

    // MARK: - Private mirror (always syncs)

    func publishSession(_ session: StudySessionModel) {
        publishPrivate("sessions", id: session.id.uuidString, data: [
            "id": session.id.uuidString,
            "subjectID": session.subjectID.uuidString,
            "startedAt": session.startedAt.timeIntervalSince1970,
            "endedAt": session.endedAt?.timeIntervalSince1970 as Any,
            "totalSeconds": session.totalSeconds,
            "plannerDay": session.plannerDay,
        ])
    }

    func publishRun(_ run: RunSessionModel) {
        publishPrivate("runs", id: run.id.uuidString, data: [
            "id": run.id.uuidString,
            "startedAt": run.startedAt.timeIntervalSince1970,
            "endedAt": run.endedAt?.timeIntervalSince1970 as Any,
            "distanceMeters": run.distanceMeters,
            "avgPaceSecPerKm": run.avgPaceSecPerKm,
            "totalActiveSeconds": run.totalActiveSeconds,
            "caloriesKcal": run.caloriesKcal,
            "plannerDay": run.plannerDay,
        ])
    }

    func publishSubject(_ subject: SubjectModel) {
        publishPrivate("subjects", id: subject.id.uuidString, data: [
            "id": subject.id.uuidString,
            "name": subject.name,
            "colorHex": subject.colorHex,
            "sfSymbol": subject.sfSymbol,
            "allowPhoneUse": subject.allowPhoneUse,
            "categoryRaw": subject.categoryRaw,
            "dailyTargetMinutes": subject.dailyTargetMinutes,
            "workoutTypeRaw": subject.workoutTypeRaw as Any,
        ])
    }

    func deleteSubject(_ subjectID: UUID) {
        deletePrivate("subjects", id: subjectID.uuidString)
    }

    func publishDDay(_ dday: DDayModel) {
        publishPrivate("ddays", id: dday.id.uuidString, data: [
            "id": dday.id.uuidString,
            "title": dday.title,
            "targetDate": dday.targetDate.timeIntervalSince1970,
            "emoji": dday.emoji,
            "isPinned": dday.isPinned,
        ])
    }

    func deleteDDay(_ id: UUID) {
        deletePrivate("ddays", id: id.uuidString)
    }

    func publishPlannerBlock(_ block: PlannerBlockModel) {
        publishPrivate("planner", id: block.slotKey, data: [
            "slotKey": block.slotKey,
            "plannerDay": block.plannerDay,
            "slotIndex": block.slotIndex,
            "subjectID": block.subjectID?.uuidString as Any,
        ])
    }

    func deletePlannerBlock(slotKey: String) {
        deletePrivate("planner", id: slotKey)
    }

    func publishPlant(_ plant: PlantModel) {
        publishPrivate("plant", id: "state", data: [
            "id": plant.id.uuidString,
            "seed": plant.seed,
            "name": plant.name,
            "studyMinutes": plant.studyMinutes,
            "workoutMinutes": plant.workoutMinutes,
        ])
    }

    private func publishPrivate(_ collection: String, id: String, data: [String: Any]) {
        guard let ref = privateDoc(collection, id) else { return }
        var payload = data
        payload["updatedAt"] = FieldValue.serverTimestamp()
        Task {
            do {
                try await ref.setData(payload, merge: true)
            } catch {
                Persistence.log(error, context: "firestore.publishPrivate.\(collection)")
            }
        }
    }

    private func deletePrivate(_ collection: String, id: String) {
        guard let ref = privateDoc(collection, id) else { return }
        Task {
            do {
                try await ref.delete()
            } catch {
                Persistence.log(error, context: "firestore.deletePrivate.\(collection)")
            }
        }
    }

    // MARK: - Mutual friendship

    /// Writes the friendship to *both* users' `users/{uid}/friends/{otherUid}`
    /// subcollections so the other side sees the connection without any
    /// manual accept step. PoC trade-off: any authenticated user can write
    /// into another user's friends list — fine until we add accept/reject.
    func publishMutualFriendship(
        meUid: String, meCode: String, meNick: String,
        otherUid: String, otherCode: String, otherNick: String
    ) async throws {
        let outgoing: [String: Any] = [
            "uid": otherUid, "friendCode": otherCode, "nickname": otherNick,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        let incoming: [String: Any] = [
            "uid": meUid, "friendCode": meCode, "nickname": meNick,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        let usersRef = db.collection("users")
        try await usersRef.document(meUid).collection("friends")
            .document(otherUid).setData(outgoing, merge: true)
        try await usersRef.document(otherUid).collection("friends")
            .document(meUid).setData(incoming, merge: true)
    }

    /// Removes the friendship from *only the caller's* side. The other user
    /// keeps the row in their list; this matches Kakao/Line semantics where
    /// "delete friend" is a personal hide, not a mutual unlink.
    func deleteFriendship(meUid: String, otherUid: String) async throws {
        try await db.collection("users").document(meUid)
            .collection("friends").document(otherUid).delete()
    }

    /// Removes a user from a group's memberCodes server-side. When the last
    /// member leaves the group doc itself is deleted to avoid orphans.
    func updateGroupMembers(groupId: UUID, members: [String]) async throws {
        let ref = db.collection("groups").document(groupId.uuidString)
        if members.isEmpty {
            try await ref.delete()
        } else {
            try await ref.setData(["memberCodes": members], merge: true)
        }
    }

    /// Awaitable variant — callers (createGroup / joinGroup) need to know
    /// the server doc actually landed before another device can join by code.
    /// Fire-and-forget here would race the user re-typing the code on the
    /// other phone before publish completes.
    func publishGroup(_ group: StudyGroupModel) async throws {
        guard Auth.auth().currentUser?.uid != nil else {
            throw FirestoreSyncError.notSignedIn
        }
        let id = group.id.uuidString
        let data: [String: Any] = [
            "id": id, "code": group.code, "name": group.name,
            "memberCodes": group.memberCodes,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await db.collection("groups").document(id).setData(data, merge: true)
    }

    func publishMessage(_ msg: ChatMessageModel) async throws {
        guard uid != nil else { throw FirestoreSyncError.notSignedIn }
        let data: [String: Any] = [
            "id": msg.id.uuidString,
            "groupId": msg.groupId.uuidString,
            "senderFriendCode": msg.senderFriendCode,
            "text": msg.text,
            "sentAt": msg.sentAt.timeIntervalSince1970,
            "attachedKind": msg.attachedKindRaw as Any,
            "attachedSummary": msg.attachedRecordSummary as Any,
            "attachedPayload": msg.attachedPayloadJSON as Any,
        ]
        let gid = msg.groupId.uuidString
        let mid = msg.id.uuidString
        try await db.collection("chats").document(gid)
            .collection("messages").document(mid).setData(data, merge: true)
    }
}
