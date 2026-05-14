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

    init(
        id: UUID = UUID(),
        seed: Int? = nil,
        name: String = "내 새싹",
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

    var nutrients: PlantNutrients {
        PlantNutrients(studyMinutes: studyMinutes, workoutMinutes: workoutMinutes)
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

    /// Add minutes of "study" nutrient. No-op for non-positive values.
    func addStudyMinutes(_ minutes: Int) {
        guard minutes > 0 else { return }
        studyMinutes += minutes
    }

    func addWorkoutMinutes(_ minutes: Int) {
        guard minutes > 0 else { return }
        workoutMinutes += minutes
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
