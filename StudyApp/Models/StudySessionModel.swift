// StudySessionModel — persisted record of a completed timer run.
// Paused ranges are JSON-encoded so stats / CloudKit / audit can reconstruct
// the original session timeline without depending on planner-slot derivation.

import Foundation
import SwiftData
import StudyCore

@Model
final class StudySessionModel {
    @Attribute(.unique) var id: UUID
    var subjectID: UUID
    var startedAt: Date
    var endedAt: Date?
    var totalSeconds: Int
    var plannerDay: Int
    var pausedRangesData: Data?

    init(
        id: UUID = UUID(),
        subjectID: UUID,
        startedAt: Date,
        endedAt: Date?,
        totalSeconds: Int,
        plannerDay: Int,
        pausedRangesData: Data? = nil
    ) {
        self.id = id
        self.subjectID = subjectID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalSeconds = totalSeconds
        self.plannerDay = plannerDay
        self.pausedRangesData = pausedRangesData
    }

    convenience init(from session: StudySession) {
        let encoded = try? JSONEncoder().encode(session.pausedRanges)
        self.init(
            id: session.id,
            subjectID: session.subjectID,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            totalSeconds: session.totalSeconds,
            plannerDay: session.plannerDay,
            pausedRangesData: encoded
        )
    }

    var pausedRanges: [PausedRange] {
        guard let data = pausedRangesData,
              let decoded = try? JSONDecoder().decode([PausedRange].self, from: data)
        else { return [] }
        return decoded
    }
}
