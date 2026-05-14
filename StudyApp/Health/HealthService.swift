// HealthService — thin wrapper around HKHealthStore.
// Authorization is opt-in; every API guards on HKHealthStore.isHealthDataAvailable
// so simulator runs without HealthKit don't crash.

import Foundation
import HealthKit
import StudyCore

extension WorkoutType {
    /// Maps our domain enum onto HealthKit's activity vocabulary.
    var hkActivityType: HKWorkoutActivityType {
        switch self {
            case .running: return .running
            case .walking: return .walking
            case .cycling: return .cycling
            case .gym:     return .traditionalStrengthTraining
            case .free:    return .other
        }
    }
}

@MainActor
final class HealthService {
    static let shared = HealthService()
    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let active = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(active)
        }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        return types
    }

    private var writeTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = []
        if let workout = HKObjectType.workoutType() as HKSampleType? {
            types.insert(workout)
        }
        // Mirror every sample type saveWorkout might add so authorization
        // covers walking/running/cycling distance + energy.
        if let walkRun = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(walkRun)
        }
        if let cycling = HKObjectType.quantityType(forIdentifier: .distanceCycling) {
            types.insert(cycling)
        }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        return types
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Result type so call sites can surface a banner instead of dropping the
    /// failure on the floor.
    enum AuthorizationResult: Equatable {
        case granted
        case unavailable
        case partial    // user denied at least one type
        case failed(String)
    }

    func requestAuthorization() async -> AuthorizationResult {
        guard isAvailable else { return .unavailable }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            // We can't actually tell from the API which types were approved,
            // so we report granted optimistically. Save paths log on failure.
            return .granted
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    enum SaveResult: Equatable {
        case saved
        case unavailable
        case noopShortRun
        case failed(String)
    }

    /// Saves an outdoor cardio workout as an HKWorkout. Returns `.saved` only
    /// when the workout actually committed to HealthKit.
    @discardableResult
    func saveWorkout(
        workoutType: WorkoutType,
        startedAt: Date,
        activeSeconds: Int,
        distanceMeters: Double,
        caloriesKcal: Double
    ) async -> SaveResult {
        guard isAvailable else { return .unavailable }
        guard activeSeconds > 0 else { return .noopShortRun }
        let effectiveEnd = startedAt.addingTimeInterval(TimeInterval(activeSeconds))

        let config = HKWorkoutConfiguration()
        config.activityType = workoutType.hkActivityType
        config.locationType = workoutType.usesGPS ? .outdoor : .indoor

        let builder = HKWorkoutBuilder(
            healthStore: store, configuration: config, device: .local()
        )
        do {
            try await builder.beginCollection(at: startedAt)

            var samples: [HKQuantitySample] = []
            let distanceIdentifier: HKQuantityTypeIdentifier = (workoutType == .cycling)
                ? .distanceCycling : .distanceWalkingRunning
            if distanceMeters > 0,
               let distanceType = HKObjectType.quantityType(forIdentifier: distanceIdentifier) {
                samples.append(HKQuantitySample(
                    type: distanceType,
                    quantity: HKQuantity(unit: .meter(), doubleValue: distanceMeters),
                    start: startedAt, end: effectiveEnd
                ))
            }
            if caloriesKcal > 0,
               let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
                samples.append(HKQuantitySample(
                    type: energyType,
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: caloriesKcal),
                    start: startedAt, end: effectiveEnd
                ))
            }
            if !samples.isEmpty {
                try await builder.addSamples(samples)
            }
            try await builder.endCollection(at: effectiveEnd)
            _ = try await builder.finishWorkout()
            return .saved
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
