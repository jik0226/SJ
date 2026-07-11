// PlantProgressService — pumps real session minutes into the plant.
// Replaces the old MascotProgressService EXP/stage system.

import Foundation
import SwiftData
import WidgetKit
import StudyCore

@MainActor
enum PlantProgressService {
    /// Adds study-time nutrients from a completed session.
    static func handleStudySessionCompleted(_ session: StudySession, context: ModelContext) {
        let minutes = session.totalSeconds / 60
        guard minutes > 0 else { return }
        guard let plant = ensurePlant(context: context) else { return }
        let before = plant.parameters
        plant.addStudyMinutes(minutes)
        Persistence.save({ try context.save() }, context: "plant.studyNutrient")
        publishMoment(before: before, plant: plant, minutes: minutes, kind: .study)
        WidgetSyncService.syncPlant(context: context)
        WidgetCenter.shared.reloadAllTimelines()
        FirestoreSyncService.shared.publishPlant(plant)
    }

    /// Adds workout-time nutrients from a completed run.
    static func handleRunCompleted(_ run: RunSession, context: ModelContext) {
        let minutes = run.totalActiveSeconds / 60
        guard minutes > 0 else { return }
        guard let plant = ensurePlant(context: context) else { return }
        let before = plant.parameters
        plant.addWorkoutMinutes(minutes)
        Persistence.save({ try context.save() }, context: "plant.workoutNutrient")
        publishMoment(before: before, plant: plant, minutes: minutes, kind: .workout)
        WidgetSyncService.syncPlant(context: context)
        WidgetCenter.shared.reloadAllTimelines()
        FirestoreSyncService.shared.publishPlant(plant)
    }

    /// Adds workout-time nutrients from a non-GPS workout subject (gym/free)
    /// that still uses the regular TimerEngine path.
    static func handleWorkoutSessionCompleted(_ session: StudySession, context: ModelContext) {
        let minutes = session.totalSeconds / 60
        guard minutes > 0 else { return }
        guard let plant = ensurePlant(context: context) else { return }
        let before = plant.parameters
        plant.addWorkoutMinutes(minutes)
        Persistence.save({ try context.save() }, context: "plant.workoutFromTimer")
        publishMoment(before: before, plant: plant, minutes: minutes, kind: .workout)
        WidgetSyncService.syncPlant(context: context)
        WidgetCenter.shared.reloadAllTimelines()
        FirestoreSyncService.shared.publishPlant(plant)
    }

    /// Emits the "your ocean just changed" moment for the session-end sheet.
    /// Only fires when the parameters visibly differ, so a short session that
    /// changes nothing doesn't interrupt with an identical before/after.
    private static func publishMoment(
        before: OceanParameters, plant: PlantModel, minutes: Int, kind: ActivityEvent.Kind
    ) {
        let after = plant.parameters
        guard before != after else { return }
        OceanMomentCenter.shared.publish(OceanMoment(
            before: before, after: after, addedMinutes: minutes, kind: kind
        ))
    }

    /// Bonus nutrients when the user clears a 7-day streak. Split evenly
    /// across both nutrient types so the plant gets a visible jump.
    static func handleWeeklyStreakBonus(context: ModelContext) {
        guard let plant = ensurePlant(context: context) else { return }
        plant.addStudyMinutes(60)
        plant.addWorkoutMinutes(60)
        Persistence.save({ try context.save() }, context: "plant.streakBonus")
        WidgetSyncService.syncPlant(context: context)
        WidgetCenter.shared.reloadAllTimelines()
        FirestoreSyncService.shared.publishPlant(plant)
    }

    /// One planner slot = 10 minutes. Manually filling a slot should grow the
    /// ocean just like a timer session would, otherwise "I filled my planner"
    /// doesn't feel rewarded. Category decides study vs. workout nutrient.
    static func handlePlannerSlotAssigned(category: SubjectCategory, context: ModelContext) {
        guard let plant = ensurePlant(context: context) else { return }
        plant.recordActivity(kind: category == .workout ? .workout : .study, minutes: 10)
        Persistence.save({ try context.save() }, context: "plant.plannerSlotAdd")
        WidgetSyncService.syncPlant(context: context)
        WidgetCenter.shared.reloadAllTimelines()
        FirestoreSyncService.shared.publishPlant(plant)
    }

    /// Clearing a slot undoes its 10-minute contribution (clamped at 0). The
    /// activity log is intentionally left intact — a cleared slot reverses the
    /// total but the historical ordering still happened.
    static func handlePlannerSlotCleared(category: SubjectCategory, context: ModelContext) {
        guard let plant = ensurePlant(context: context) else { return }
        plant.reduceMinutes(kind: category == .workout ? .workout : .study, minutes: 10)
        Persistence.save({ try context.save() }, context: "plant.plannerSlotClear")
        WidgetSyncService.syncPlant(context: context)
        WidgetCenter.shared.reloadAllTimelines()
        FirestoreSyncService.shared.publishPlant(plant)
    }

    private static func ensurePlant(context: ModelContext) -> PlantModel? {
        if let existing = try? context.fetch(FetchDescriptor<PlantModel>()).first {
            return existing
        }
        let p = PlantModel()
        context.insert(p)
        Persistence.save({ try context.save() }, context: "plant.seed")
        return p
    }
}
