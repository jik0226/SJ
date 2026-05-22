// PlantModel — persisted state of the user's procedurally-grown plant.
// (seed, studyMinutes, workoutMinutes) is the complete description; the
// rendering is derived from PlantFormula.

import Foundation
import SwiftData
import StudyCore

@Model
final class PlantModel {
    @Attribute(.unique) var id: UUID
    var seed: Int                          // SwiftData stores Int, not UInt64
    var name: String
    var studyMinutes: Int
    var workoutMinutes: Int
    var createdAt: Date
    /// JSON-encoded `[ActivityEvent]` in chronological order. Drives the
    /// order-sensitive ocean shape. Capped at the most recent 500 events.
    var activityLogData: Data?

    init(
        id: UUID = UUID(),
        seed: Int? = nil,
        name: String = "내 바다",
        studyMinutes: Int = 0,
        workoutMinutes: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.seed = seed ?? Self.makeSeed()
        self.name = name
        self.studyMinutes = max(0, studyMinutes)
        self.workoutMinutes = max(0, workoutMinutes)
        self.createdAt = createdAt
    }

    var activityLog: [ActivityEvent] {
        guard let data = activityLogData,
              let decoded = try? JSONDecoder().decode([ActivityEvent].self, from: data)
        else { return [] }
        return decoded
    }

    var nutrients: PlantNutrients {
        PlantNutrients(
            studyMinutes: studyMinutes,
            workoutMinutes: workoutMinutes,
            sequenceHash: ActivitySequence.hash(of: activityLog)
        )
    }

    var parameters: PlantParameters {
        PlantFormula.parameters(seed: UInt64(bitPattern: Int64(seed)), nutrients: nutrients)
    }

    var formulaLines: [PlantFormulaLine] {
        PlantFormula.formulaDescription(
            seed: UInt64(bitPattern: Int64(seed)),
            nutrients: nutrients
        )
    }

    /// Append an activity to the ordered log (drives the order-sensitive
    /// ocean) and bump the matching nutrient total in one place.
    func recordActivity(kind: ActivityEvent.Kind, minutes: Int, at: Date = Date()) {
        guard minutes > 0 else { return }
        switch kind {
            case .study: studyMinutes += minutes
            case .workout: workoutMinutes += minutes
        }
        var log = activityLog
        log.append(ActivityEvent(kind: kind, minutes: minutes, at: at))
        if log.count > 500 { log = Array(log.suffix(500)) }
        activityLogData = try? JSONEncoder().encode(log)
    }

    /// Subtracts minutes (e.g. clearing a planner slot) without touching the
    /// activity log — clearing a slot undoes the total but not the historical
    /// ordering. Clamps at zero.
    func reduceMinutes(kind: ActivityEvent.Kind, minutes: Int) {
        guard minutes > 0 else { return }
        switch kind {
            case .study: studyMinutes = max(0, studyMinutes - minutes)
            case .workout: workoutMinutes = max(0, workoutMinutes - minutes)
        }
    }

    /// Add minutes of "study" nutrient. No-op for non-positive values.
    func addStudyMinutes(_ minutes: Int) {
        recordActivity(kind: .study, minutes: minutes)
    }

    func addWorkoutMinutes(_ minutes: Int) {
        recordActivity(kind: .workout, minutes: minutes)
    }

    private static func makeSeed() -> Int {
        // Use the high bits of UUID for a stable per-user random seed.
        let u = UUID().uuid
        let bytes = [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7]
        var seed: UInt64 = 0
        for b in bytes { seed = (seed << 8) | UInt64(b) }
        return Int(truncatingIfNeeded: seed)
    }
}
