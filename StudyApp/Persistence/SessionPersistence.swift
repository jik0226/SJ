// SessionPersistence — saves a finished StudySession and fills planner slots.
// Treated as a single transaction: every insert/update lands in one save() call,
// and any failure rolls the context back so the next session doesn't inherit
// dirty state.

import Foundation
import SwiftData
import StudyCore

enum SessionPersistenceError: Error {
    case saveFailed(underlying: Error)
}

@MainActor
enum SessionPersistence {
    static func save(_ session: StudySession, context: ModelContext) throws {
        do {
            context.insert(StudySessionModel(from: session))
            try fillPlannerSlots(for: session, context: context)
            try context.save()
        } catch {
            context.rollback()
            throw SessionPersistenceError.saveFailed(underlying: error)
        }
    }

    private static func fillPlannerSlots(
        for session: StudySession, context: ModelContext
    ) throws {
        let calendar = PlannerCalendar(cutoffHour: 3)
        let subjectID = session.subjectID

        for (day, idx) in calendar.slots(for: session) {
            let key = PlannerBlockModel.makeSlotKey(plannerDay: day, slotIndex: idx)
            let predicate = #Predicate<PlannerBlockModel> { $0.slotKey == key }
            let descriptor = FetchDescriptor<PlannerBlockModel>(predicate: predicate)
            let existing = try context.fetch(descriptor).first
            if let existing {
                existing.subjectID = subjectID
            } else {
                context.insert(PlannerBlockModel(
                    plannerDay: day, slotIndex: idx, subjectID: subjectID
                ))
            }
        }
    }
}
