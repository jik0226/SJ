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
        plant.addStudyMinutes(minutes)
        Persistence.save({ try context.save() }, context: "plant.studyNutrient")
        WidgetSyncService.syncPlant(context: context)
        WidgetCenter.shared.reloadAllTimelines()
        FirestoreSyncService.shared.publishPlant(plant)
    }

    /// Adds workout-time nutrients from a completed run.
    static func handleRunCompleted(_ run: RunSession, context: ModelContext) {
        let minutes = run.totalActiveSeconds / 60
        guard minutes > 0 else { return }
        guard let plant = ensurePlant(context: context) else { return }
        plant.addWorkoutMinutes(minutes)
        Persistence.save({ try context.save() }, context: "plant.workoutNutrient")
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
        plant.addWorkoutMinutes(minutes)
        Persistence.save({ try context.save() }, context: "plant.workoutFromTimer")
        WidgetSyncService.syncPlant(context: context)
        WidgetCenter.shared.reloadAllTimelines()
        FirestoreSyncService.shared.publishPlant(plant)
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
