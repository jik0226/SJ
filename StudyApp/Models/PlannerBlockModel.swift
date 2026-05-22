// PlannerBlockModel — one 10-minute slot stored in SwiftData.
// `slotKey` carries the (plannerDay, slotIndex) composite as a unique attribute,
// so duplicate slots are rejected at the DB layer even if logic ever races.

import Foundation
import SwiftData
import StudyCore

@Model
final class PlannerBlockModel {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var slotKey: String
    var plannerDay: Int
    var slotIndex: Int
    var subjectID: UUID?
    var note: String?
    /// "timer" = auto-filled by a finished timer session (already counted in
    /// StudySessionModel), "manual" = user tapped the slot in the planner
    /// (not backed by a session). Stats add only manual blocks so timer time
    /// isn't double-counted. Stored default keeps migration lightweight and
    /// treats legacy blocks as timer-sourced (no double count).
    var source: String = PlannerBlockSource.timer.rawValue

    init(
        id: UUID = UUID(),
        plannerDay: Int,
        slotIndex: Int,
        subjectID: UUID? = nil,
        note: String? = nil,
        source: PlannerBlockSource = .timer
    ) {
        self.id = id
        self.slotKey = PlannerBlockModel.makeSlotKey(plannerDay: plannerDay, slotIndex: slotIndex)
        self.plannerDay = plannerDay
        self.slotIndex = slotIndex
        self.subjectID = subjectID
        self.note = note
        self.source = source.rawValue
    }

    var isManual: Bool { source == PlannerBlockSource.manual.rawValue }

    var compositeKey: String { slotKey }

    static func makeSlotKey(plannerDay: Int, slotIndex: Int) -> String {
        "\(plannerDay)-\(slotIndex)"
    }
}

enum PlannerBlockSource: String, Sendable {
    case timer
    case manual
}
