// RunSessionModel — persisted record of a running session.

import Foundation
import SwiftData
import StudyCore

@Model
final class RunSessionModel {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var distanceMeters: Double
    var routePolyline: Data
    var avgPaceSecPerKm: Int
    var caloriesKcal: Double
    var plannerDay: Int
    /// Pause-aware. See RunSession.totalActiveSeconds.
    var totalActiveSeconds: Int

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        distanceMeters: Double = 0,
        routePolyline: Data = Data(),
        avgPaceSecPerKm: Int = 0,
        caloriesKcal: Double = 0,
        plannerDay: Int,
        totalActiveSeconds: Int = 0
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.routePolyline = routePolyline
        self.avgPaceSecPerKm = avgPaceSecPerKm
        self.caloriesKcal = caloriesKcal
        self.plannerDay = plannerDay
        self.totalActiveSeconds = totalActiveSeconds
    }

    convenience init(from session: RunSession) {
        self.init(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            distanceMeters: session.distanceMeters,
            routePolyline: session.routePolyline,
            avgPaceSecPerKm: session.avgPaceSecPerKm,
            caloriesKcal: session.caloriesKcal,
            plannerDay: session.plannerDay,
            totalActiveSeconds: session.totalActiveSeconds
        )
    }

    var distanceKilometers: Double { distanceMeters / 1000.0 }
}
