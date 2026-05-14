// WidgetSyncService — pushes minimal data into the App Group so widgets can
// render without the main app being alive.

import Foundation
import SwiftData
import WidgetKit
import StudyCore

@MainActor
enum WidgetSyncService {
    private static let defaults = UserDefaults(suiteName: AppGroup.identifier)
    private static let calendar = PlannerCalendar(cutoffHour: 3)

    static func syncAll(context: ModelContext) {
        syncPinnedDDay(context: context)
        syncTodayStudyTime(context: context)
        syncPlant(context: context)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func syncPinnedDDay(context: ModelContext) {
        let predicate = #Predicate<DDayModel> { $0.isPinned == true }
        let descriptor = FetchDescriptor<DDayModel>(predicate: predicate)
        guard let pinned = try? context.fetch(descriptor).first else {
            defaults?.removeObject(forKey: "dday.title")
            defaults?.removeObject(forKey: "dday.targetDate")
            defaults?.removeObject(forKey: "dday.emoji")
            return
        }
        defaults?.set(pinned.title, forKey: "dday.title")
        defaults?.set(pinned.targetDate, forKey: "dday.targetDate")
        defaults?.set(pinned.emoji, forKey: "dday.emoji")
    }

    static func syncTodayStudyTime(context: ModelContext) {
        let today = calendar.plannerDay(for: Date())
        let predicate = #Predicate<StudySessionModel> { $0.plannerDay == today }
        let descriptor = FetchDescriptor<StudySessionModel>(predicate: predicate)
        let sessions = (try? context.fetch(descriptor)) ?? []
        let seconds = sessions.reduce(0) { $0 + $1.totalSeconds }
        defaults?.set(seconds, forKey: "today.studySeconds")
    }

    static func syncPlant(context: ModelContext) {
        guard let plant = try? context.fetch(FetchDescriptor<PlantModel>()).first else {
            return
        }
        defaults?.set(plant.name, forKey: "plant.name")
        defaults?.set(plant.seed, forKey: "plant.seed")
        defaults?.set(plant.studyMinutes, forKey: "plant.studyMinutes")
        defaults?.set(plant.workoutMinutes, forKey: "plant.workoutMinutes")
    }
}
