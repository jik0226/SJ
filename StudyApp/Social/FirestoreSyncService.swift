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

import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore
import StudyCore

@MainActor
final class FirestoreSyncService {
    static let shared = FirestoreSyncService()

    private let db = Firestore.firestore()
    private var groupListeners: [UUID: ListenerRegistration] = [:]
    private var friendsListener: ListenerRegistration?

    private init() {}

    private var uid: String? { Auth.auth().currentUser?.uid }
    private func userRef() -> DocumentReference? {
        guard let uid else { return nil }
        return db.collection("users").document(uid)
    }
    private func privateDoc(_ collection: String, _ id: String) -> DocumentReference? {
        userRef()?.collection("private").document(collection).collection("items").document(id)
    }

    // MARK: - Public profile (gated by PrivacyPreferences)

    /// Publishes the user's *discoverable* fields. Every summary field is
    /// gated on PrivacyPreferences so off-by-default opt-in is honoured.
    /// FriendCode + nickname are always published (otherwise friend lookup
    /// can't work at all).
    func publishMe(_ profile: FriendProfileModel) {
        guard let uid, let ref = userRef() else { return }
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

    // MARK: - Inbound sync (boot-time)

    /// Pulls the user's private subtree from Firestore and mirrors anything
    /// missing into local SwiftData. Existing rows are NOT overwritten —
    /// local changes win until a proper updatedAt-based merge is built.
    func pullPrivateSnapshot(into context: ModelContext) async {
        guard uid != nil, let userRef = userRef() else { return }
        await pullCollection(
            ref: userRef.collection("private").document("subjects").collection("items"),
            context: context, hydrate: hydrateSubject(_:context:)
        )
        await pullCollection(
            ref: userRef.collection("private").document("ddays").collection("items"),
            context: context, hydrate: hydrateDDay(_:context:)
        )
        await pullCollection(
            ref: userRef.collection("private").document("planner").collection("items"),
            context: context, hydrate: hydratePlannerBlock(_:context:)
        )
        await pullCollection(
            ref: userRef.collection("private").document("sessions").collection("items"),
            context: context, hydrate: hydrateSession(_:context:)
        )
        await pullCollection(
            ref: userRef.collection("private").document("runs").collection("items"),
            context: context, hydrate: hydrateRun(_:context:)
        )
        await pullCollection(
            ref: userRef.collection("private").document("plant").collection("items"),
            context: context, hydrate: hydratePlant(_:context:)
        )
        Persistence.save({ try context.save() }, context: "firestore.pullPrivate")
    }

    private func pullCollection(
        ref: CollectionReference,
        context: ModelContext,
        hydrate: ([String: Any], ModelContext) -> Void
    ) async {
        do {
            let snap = try await ref.getDocuments()
            for doc in snap.documents {
                hydrate(doc.data(), context)
            }
        } catch {
            Persistence.log(error, context: "firestore.pull.\(ref.path)")
        }
    }

    private func hydrateSubject(_ d: [String: Any], context: ModelContext) {
        guard let idString = d["id"] as? String, let uuid = UUID(uuidString: idString) else { return }
        let predicate = #Predicate<SubjectModel> { $0.id == uuid }
        if (try? context.fetch(FetchDescriptor(predicate: predicate)).first) != nil { return }
        let workoutTypeRaw = d["workoutTypeRaw"] as? String
        let workoutType = workoutTypeRaw.flatMap(WorkoutType.init(rawValue:))
        let categoryRaw = d["categoryRaw"] as? String ?? SubjectCategory.study.rawValue
        let category = SubjectCategory(rawValue: categoryRaw) ?? .study
        context.insert(SubjectModel(
            id: uuid,
            name: d["name"] as? String ?? "과목",
            colorHex: d["colorHex"] as? String ?? "#4DABF7",
            sfSymbol: d["sfSymbol"] as? String ?? "book",
            allowPhoneUse: d["allowPhoneUse"] as? Bool ?? false,
            category: category,
            dailyTargetMinutes: d["dailyTargetMinutes"] as? Int ?? 60,
            workoutType: workoutType
        ))
    }

    private func hydrateDDay(_ d: [String: Any], context: ModelContext) {
        guard let idString = d["id"] as? String, let uuid = UUID(uuidString: idString) else { return }
        let predicate = #Predicate<DDayModel> { $0.id == uuid }
        if (try? context.fetch(FetchDescriptor(predicate: predicate)).first) != nil { return }
        guard let interval = d["targetDate"] as? TimeInterval else { return }
        context.insert(DDayModel(
            id: uuid,
            title: d["title"] as? String ?? "D-Day",
            targetDate: Date(timeIntervalSince1970: interval),
            emoji: d["emoji"] as? String ?? "📅",
            isPinned: d["isPinned"] as? Bool ?? false
        ))
    }

    private func hydratePlannerBlock(_ d: [String: Any], context: ModelContext) {
        guard let slotKey = d["slotKey"] as? String else { return }
        let predicate = #Predicate<PlannerBlockModel> { $0.slotKey == slotKey }
        if (try? context.fetch(FetchDescriptor(predicate: predicate)).first) != nil { return }
        guard let day = d["plannerDay"] as? Int, let idx = d["slotIndex"] as? Int else { return }
        let subjectID = (d["subjectID"] as? String).flatMap(UUID.init(uuidString:))
        context.insert(PlannerBlockModel(plannerDay: day, slotIndex: idx, subjectID: subjectID))
    }

    private func hydrateSession(_ d: [String: Any], context: ModelContext) {
        guard let idString = d["id"] as? String, let uuid = UUID(uuidString: idString),
              let subjectIDString = d["subjectID"] as? String,
              let subjectUUID = UUID(uuidString: subjectIDString),
              let startedInterval = d["startedAt"] as? TimeInterval else { return }
        let predicate = #Predicate<StudySessionModel> { $0.id == uuid }
        if (try? context.fetch(FetchDescriptor(predicate: predicate)).first) != nil { return }
        let endedInterval = d["endedAt"] as? TimeInterval
        let model = StudySessionModel(
            id: uuid,
            subjectID: subjectUUID,
            startedAt: Date(timeIntervalSince1970: startedInterval),
            endedAt: endedInterval.map { Date(timeIntervalSince1970: $0) },
            totalSeconds: d["totalSeconds"] as? Int ?? 0,
            plannerDay: d["plannerDay"] as? Int ?? 0
        )
        context.insert(model)
    }

    private func hydrateRun(_ d: [String: Any], context: ModelContext) {
        guard let idString = d["id"] as? String, let uuid = UUID(uuidString: idString),
              let startedInterval = d["startedAt"] as? TimeInterval else { return }
        let predicate = #Predicate<RunSessionModel> { $0.id == uuid }
        if (try? context.fetch(FetchDescriptor(predicate: predicate)).first) != nil { return }
        let endedInterval = d["endedAt"] as? TimeInterval
        context.insert(RunSessionModel(
            id: uuid,
            startedAt: Date(timeIntervalSince1970: startedInterval),
            endedAt: endedInterval.map { Date(timeIntervalSince1970: $0) },
            distanceMeters: d["distanceMeters"] as? Double ?? 0,
            avgPaceSecPerKm: d["avgPaceSecPerKm"] as? Int ?? 0,
            caloriesKcal: d["caloriesKcal"] as? Double ?? 0,
            plannerDay: d["plannerDay"] as? Int ?? 0,
            totalActiveSeconds: d["totalActiveSeconds"] as? Int ?? 0
        ))
    }

    private func hydratePlant(_ d: [String: Any], context: ModelContext) {
        guard let idString = d["id"] as? String, let uuid = UUID(uuidString: idString) else { return }
        let predicate = #Predicate<PlantModel> { $0.id == uuid }
        if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
            // Plant exists — only adopt server numbers when they're strictly
            // larger (the only direction nutrient counters move). Avoids the
            // edge case where a fresh local plant wipes accumulated minutes.
            existing.studyMinutes = max(existing.studyMinutes, d["studyMinutes"] as? Int ?? 0)
            existing.workoutMinutes = max(existing.workoutMinutes, d["workoutMinutes"] as? Int ?? 0)
            return
        }
        let plant = PlantModel(
            id: uuid,
            seed: d["seed"] as? Int,
            name: d["name"] as? String ?? "내 바다",
            studyMinutes: d["studyMinutes"] as? Int ?? 0,
            workoutMinutes: d["workoutMinutes"] as? Int ?? 0
        )
        context.insert(plant)
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

    /// Starts a snapshot listener on the current user's `friends` subcollection.
    /// Each incoming doc that doesn't yet have a matching FriendProfileModel
    /// gets mirrored into SwiftData so the friends list updates in real time.
    /// Idempotent — re-calling stops the previous listener first.
    func startListeningFriends(context: ModelContext) {
        guard let uid else { return }
        friendsListener?.remove()
        friendsListener = db.collection("users").document(uid)
            .collection("friends")
            .addSnapshotListener { [weak self] snap, error in
                if let error {
                    Persistence.log(error, context: "firestore.friendsListener")
                    return
                }
                guard let docs = snap?.documentChanges else { return }
                Task { @MainActor in
                    self?.applyIncomingFriends(docs, context: context)
                }
            }
    }

    func stopListeningFriends() {
        friendsListener?.remove()
        friendsListener = nil
    }

    private func applyIncomingFriends(
        _ changes: [DocumentChange], context: ModelContext
    ) {
        for change in changes where change.type == .added || change.type == .modified {
            let data = change.document.data()
            guard let code = data["friendCode"] as? String else { continue }
            let nickname = data["nickname"] as? String ?? "친구"
            let predicate = #Predicate<FriendProfileModel> { $0.friendCode == code }
            if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
                // Refresh nickname in case the other side renamed.
                if existing.nickname.hasPrefix("(데모)") || existing.nickname != nickname {
                    existing.nickname = nickname
                }
                continue
            }
            context.insert(FriendProfileModel(
                friendCode: code,
                nickname: nickname,
                mascotSpecies: .cat,
                mascotStage: 0
            ))
        }
        Persistence.save({ try context.save() }, context: "firestore.applyIncomingFriends")
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

    func lookupFriend(byCode code: String) async -> LookupOutcome<RemoteFriend> {
        guard Auth.auth().currentUser != nil else { return .error(.unauthenticated) }
        do {
            let snap = try await db.collection("users")
                .whereField("friendCode", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()
            guard let doc = snap.documents.first else { return .notFound }
            return .found(RemoteFriend(
                uid: doc.data()["uid"] as? String ?? doc.documentID,
                friendCode: code,
                nickname: doc.data()["nickname"] as? String ?? "친구"
            ))
        } catch {
            Persistence.log(error, context: "firestore.lookupFriend")
            return .error(.from(error))
        }
    }

    func lookupGroup(byCode code: String) async -> LookupOutcome<RemoteGroup> {
        guard Auth.auth().currentUser != nil else { return .error(.unauthenticated) }
        do {
            let snap = try await db.collection("groups")
                .whereField("code", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()
            guard let doc = snap.documents.first else { return .notFound }
            let idString = doc.data()["id"] as? String ?? doc.documentID
            guard let uuid = UUID(uuidString: idString) else { return .notFound }
            return .found(RemoteGroup(
                id: uuid,
                code: code,
                name: doc.data()["name"] as? String ?? "그룹",
                memberCodes: doc.data()["memberCodes"] as? [String] ?? []
            ))
        } catch {
            Persistence.log(error, context: "firestore.lookupGroup")
            return .error(.from(error))
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
        ]
        let gid = msg.groupId.uuidString
        let mid = msg.id.uuidString
        try await db.collection("chats").document(gid)
            .collection("messages").document(mid).setData(data, merge: true)
    }

    func startListening(group: StudyGroupModel, context: ModelContext) {
        guard Auth.auth().currentUser != nil else { return }
        stopListening(group: group)
        let gid = group.id
        let listener = db.collection("chats").document(gid.uuidString)
            .collection("messages")
            .order(by: "sentAt")
            .addSnapshotListener { [weak self] snap, error in
                if let error {
                    Persistence.log(error, context: "firestore.chatListener")
                    return
                }
                guard let docs = snap?.documentChanges else { return }
                Task { @MainActor in
                    self?.applyIncomingMessages(docs, groupId: gid, context: context)
                }
            }
        groupListeners[gid] = listener
    }

    func stopListening(group: StudyGroupModel) {
        groupListeners[group.id]?.remove()
        groupListeners.removeValue(forKey: group.id)
    }

    private func applyIncomingMessages(
        _ changes: [DocumentChange], groupId: UUID, context: ModelContext
    ) {
        for change in changes where change.type == .added {
            let data = change.document.data()
            guard let idString = data["id"] as? String,
                  let msgId = UUID(uuidString: idString),
                  let sender = data["senderFriendCode"] as? String,
                  let text = data["text"] as? String,
                  let sentInterval = data["sentAt"] as? TimeInterval
            else { continue }
            let predicate = #Predicate<ChatMessageModel> { $0.id == msgId }
            let exists = (try? context.fetch(FetchDescriptor(predicate: predicate)).first) != nil
            if exists { continue }
            let mirrored = ChatMessageModel(
                id: msgId,
                groupId: groupId,
                senderFriendCode: sender,
                text: text,
                sentAt: Date(timeIntervalSince1970: sentInterval),
                attachedRecordSummary: data["attachedSummary"] as? String,
                attachedKind: (data["attachedKind"] as? String).flatMap(AttachedKind.init(rawValue:))
            )
            context.insert(mirrored)
        }
        Persistence.save({ try context.save() }, context: "firestore.applyIncoming")
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

    var errorDescription: String? {
        switch self {
            case .unauthenticated:
                return "익명 로그인이 끝나지 않았어요. 잠시 후 다시 시도해주세요."
            case .permissionDenied:
                return "서버 접근 권한이 없어요. Firestore 규칙을 확인해주세요."
            case .network:
                return "서버에 연결할 수 없어요. 인터넷 상태를 확인해주세요."
            case .unknown(let msg):
                return "서버 오류가 발생했어요: \(msg)"
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
