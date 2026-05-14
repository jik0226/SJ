// RunSession — outdoor running session captured via CoreLocation in the iOS app.
// The Data field carries an encoded polyline; the core layer treats it opaquely.

import Foundation

public struct RunSession: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var distanceMeters: Double
    public var routePolyline: Data
    public var avgPaceSecPerKm: Int
    public var caloriesKcal: Double
    public var plannerDay: Int
    /// Wall-clock minus pauses. Use this (not `endedAt - startedAt`) for any
    /// summary, HealthKit duration, or calorie computation.
    public var totalActiveSeconds: Int

    public init(
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

    public var distanceKilometers: Double { distanceMeters / 1000.0 }
}
