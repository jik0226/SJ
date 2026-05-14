// PlannerBlock — one 10-minute slot.
// Composite key = "YYYYMMDD-slotIndex" (slotIndex: 0..143).

import Foundation

public struct PlannerBlock: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var plannerDay: Int
    /// 0 = 00:00, 1 = 00:10, ..., 143 = 23:50.
    public var slotIndex: Int
    public var subjectID: UUID?
    public var note: String?

    public init(
        id: UUID = UUID(),
        plannerDay: Int,
        slotIndex: Int,
        subjectID: UUID? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.plannerDay = plannerDay
        self.slotIndex = slotIndex
        self.subjectID = subjectID
        self.note = note
    }

    public var compositeKey: String {
        "\(plannerDay)-\(slotIndex)"
    }

    public static let slotsPerDay = 144
    public static let minutesPerSlot = 10
}
