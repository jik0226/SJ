// FirestoreSyncService+Inbound — the boot-time read path. Pulls the user's
// private subtree once at launch and hydrates any missing rows into local
// SwiftData (never overwriting local changes). Live snapshot listeners and
// lookups live in FirestoreSyncService+Listeners.swift.

import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore
import StudyCore

extension FirestoreSyncService {
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
}
