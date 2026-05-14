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

    init(
        id: UUID = UUID(),
        plannerDay: Int,
        slotIndex: Int,
        subjectID: UUID? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.slotKey = PlannerBlockModel.makeSlotKey(plannerDay: plannerDay, slotIndex: slotIndex)
        self.plannerDay = plannerDay
        self.slotIndex = slotIndex
        self.subjectID = subjectID
        self.note = note
    }

    var compositeKey: String { slotKey }

    static func makeSlotKey(plannerDay: Int, slotIndex: Int) -> String {
        "\(plannerDay)-\(slotIndex)"
    }
}
