// RunningManager — drives CoreLocation for a run, with adaptive sampling
// (high accuracy while moving, downgraded while stationary) so battery use
// stays bounded.

import Foundation
import CoreLocation
import Observation
import StudyCore

@MainActor
@Observable
final class RunningManager: NSObject {
    private(set) var state: RunState = .idle
    private(set) var distanceMeters: Double = 0
    private(set) var elapsedSeconds: Int = 0
    private(set) var currentPaceSecPerKm: Int = 0
    private(set) var routeCoordinates: [CLLocationCoordinate2D] = []
    private(set) var authStatus: CLAuthorizationStatus = .notDetermined
    /// Human-readable banner for the UI. nil = nothing to show.
    private(set) var authBanner: String?

    @ObservationIgnored
    private let manager = CLLocationManager()
    @ObservationIgnored
    private var startedAt: Date?
    @ObservationIgnored
    private var lastLocation: CLLocation?
    @ObservationIgnored
    private var elapsedTimer: Timer?
    @ObservationIgnored
    private var stationarySince: Date?
    /// Active running seconds banked from completed segments (excluding the
    /// segment currently in progress and excluding pauses).
    @ObservationIgnored
    private var bankedActiveSeconds: Int = 0
    /// Start of the current "running" segment. nil when paused.
    @ObservationIgnored
    private var currentSegmentStart: Date?
    /// Workout type drives MET (calorie) + HealthKit activityType.
    @ObservationIgnored
    var workoutType: WorkoutType = .running

    enum RunState: Equatable, Sendable {
        case idle, running, paused, ended
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = true
        manager.activityType = .fitness
        authStatus = manager.authorizationStatus
        recomputeBanner()
    }

    func requestAuthorizationIfNeeded() {
        // Foreground-only running: we never request Always and never enable
        // background location updates. Running measures distance/route while
        // the app is open; locking the screen or backgrounding pauses GPS.
        // This keeps the app free of the `location` background mode, which App
        // Review otherwise gates behind a per-submission demo video (2.5.4).
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func start() {
        guard state == .idle || state == .ended else { return }
        requestAuthorizationIfNeeded()
        // Don't start a run if the user has denied location — UI will show
        // the banner and the start button stays a no-op.
        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways
              || authStatus == .notDetermined else {
            return
        }
        reset()
        let now = Date()
        startedAt = now
        currentSegmentStart = now
        state = .running
        manager.startUpdatingLocation()
        startTicker()
    }

    var canStart: Bool {
        switch authStatus {
            case .denied, .restricted: return false
            default: return true
        }
    }

    private func recomputeBanner() {
        switch authStatus {
            case .denied:
                authBanner = "위치 권한이 거부되어 거리·페이스를 측정할 수 없습니다. 설정에서 허용해주세요."
            case .restricted:
                authBanner = "위치 사용이 제한되어 있어 러닝 기능을 사용할 수 없습니다."
            default:
                authBanner = nil
        }
    }

    func pause() {
        guard state == .running else { return }
        bankCurrentSegment()
        state = .paused
        manager.stopUpdatingLocation()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    func resume() {
        guard state == .paused else { return }
        // Permission might have been revoked while we were paused.
        guard canStart else { return }
        currentSegmentStart = Date()
        state = .running
        manager.startUpdatingLocation()
        startTicker()
    }

    private func bankCurrentSegment() {
        guard let segStart = currentSegmentStart else { return }
        bankedActiveSeconds += max(0, Int(Date().timeIntervalSince(segStart)))
        currentSegmentStart = nil
    }

    func end() -> RunSession? {
        guard state == .running || state == .paused else { return nil }
        bankCurrentSegment()
        let endAt = Date()
        manager.stopUpdatingLocation()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        state = .ended

        let start = startedAt ?? endAt
        let calendar = PlannerCalendar(cutoffHour: 3)
        let polyline = encodePolyline(routeCoordinates)
        let active = bankedActiveSeconds
        let caloriesKcal = estimatedCalories(meters: distanceMeters, seconds: active)
        return RunSession(
            id: UUID(),
            startedAt: start,
            endedAt: endAt,
            distanceMeters: distanceMeters,
            routePolyline: polyline,
            avgPaceSecPerKm: currentPaceSecPerKm,
            caloriesKcal: caloriesKcal,
            plannerDay: calendar.plannerDay(for: start),
            totalActiveSeconds: active
        )
    }

    private func reset() {
        distanceMeters = 0
        elapsedSeconds = 0
        currentPaceSecPerKm = 0
        routeCoordinates.removeAll()
        startedAt = nil
        lastLocation = nil
        stationarySince = nil
        bankedActiveSeconds = 0
        currentSegmentStart = nil
    }

    private func startTicker() {
        elapsedTimer?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let segmentSecs: Int
                if let segStart = self.currentSegmentStart {
                    segmentSecs = max(0, Int(Date().timeIntervalSince(segStart)))
                } else {
                    segmentSecs = 0
                }
                self.elapsedSeconds = self.bankedActiveSeconds + segmentSecs
                if self.distanceMeters > 0 {
                    self.currentPaceSecPerKm = Int(
                        Double(self.elapsedSeconds) / (self.distanceMeters / 1000.0)
                    )
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        elapsedTimer = t
    }

    private func estimatedCalories(meters: Double, seconds: Int) -> Double {
        // MET × weight × hours; MET varies by workoutType so walking/cycling
        // don't over-report.
        guard seconds > 0 else { return 0 }
        let hours = Double(seconds) / 3600.0
        let weightKg: Double = 65
        return workoutType.metValue * weightKg * hours
    }

    private func encodePolyline(_ coords: [CLLocationCoordinate2D]) -> Data {
        // Simple JSON encoding — good enough for V1; replace with Google polyline
        // encoding later if size becomes an issue.
        let pairs = coords.map { [$0.latitude, $0.longitude] }
        return (try? JSONSerialization.data(withJSONObject: pairs)) ?? Data()
    }
}

extension RunningManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let snapshot = locations
        Task { @MainActor in
            self.consume(locations: snapshot)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // Pause an active run so we don't accumulate 0 km records.
            if self.state == .running { self.pause() }
            self.authBanner = "위치 신호를 받지 못했어요. 잠시 후 다시 시도해주세요."
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authStatus = status
            self.recomputeBanner()
            if status == .denied || status == .restricted, self.state == .running {
                self.pause()
            }
        }
    }

    private func consume(locations: [CLLocation]) {
        guard state == .running else { return }
        for loc in locations where loc.horizontalAccuracy >= 0 && loc.horizontalAccuracy < 50 {
            if let prev = lastLocation {
                let delta = loc.distance(from: prev)
                if delta > 1 {
                    distanceMeters += delta
                    stationarySince = nil
                    manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
                } else if stationarySince == nil {
                    stationarySince = Date()
                } else if let since = stationarySince,
                          Date().timeIntervalSince(since) > 20 {
                    // Stationary > 20s — downgrade accuracy to save battery.
                    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                }
            }
            routeCoordinates.append(loc.coordinate)
            lastLocation = loc
        }
    }
}
