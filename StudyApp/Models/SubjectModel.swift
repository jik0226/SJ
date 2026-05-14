// SubjectModel — SwiftData @Model wrapping the core Subject struct.

import Foundation
import SwiftData
import StudyCore

@Model
final class SubjectModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var sfSymbol: String
    var allowPhoneUse: Bool
    var categoryRaw: String
    var dailyTargetMinutes: Int
    var createdAt: Date
    /// nil for study subjects; set for workout subjects to drive the
    /// RunningView vs simple timer branch.
    var workoutTypeRaw: String?

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        sfSymbol: String,
        allowPhoneUse: Bool,
        category: SubjectCategory,
        dailyTargetMinutes: Int,
        createdAt: Date = Date(),
        workoutType: WorkoutType? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sfSymbol = sfSymbol
        self.allowPhoneUse = allowPhoneUse
        self.categoryRaw = category.rawValue
        self.dailyTargetMinutes = dailyTargetMinutes
        self.createdAt = createdAt
        self.workoutTypeRaw = workoutType?.rawValue
    }

    var category: SubjectCategory {
        SubjectCategory(rawValue: categoryRaw) ?? .study
    }

    var workoutType: WorkoutType? {
        guard let raw = workoutTypeRaw else { return nil }
        return WorkoutType(rawValue: raw)
    }

    var coreValue: Subject {
        Subject(
            id: id,
            name: name,
            colorHex: colorHex,
            sfSymbol: sfSymbol,
            allowPhoneUse: allowPhoneUse,
            category: category,
            dailyTargetMinutes: dailyTargetMinutes,
            createdAt: createdAt
        )
    }
}
