// AppState — single source of truth for cross-feature concerns:
// timer engine, background guard, current subject's lecture mode.

import Foundation
import SwiftUI
import SwiftData
import StudyCore

@MainActor
@Observable
final class AppState {
    let timer: TimerEngine
    var currentSubjectAllowsPhone: Bool = false
    var lastGuardAction: GuardAction = .ignore
    /// Surfaces the most recent persistence failure so UI can flag it.
    /// nil = clean.
    var lastPersistenceError: SessionPersistenceError?
    /// Reflects the most recent `timer.start` failure (e.g. already running).
    /// Cleared on the next successful `startSession`.
    var lastStartError: String?

    /// Injected by RootView.onAppear once SwiftUI's environment is wired.
    @ObservationIgnored
    var modelContext: ModelContext?

    /// Lazy so that `self` is fully initialized when the closure captures it.
    /// `@ObservationIgnored` keeps the macro from generating an init accessor,
    /// which is incompatible with `lazy`.
    @ObservationIgnored
    private(set) lazy var guard_: BackgroundGuard = makeGuard()

    @ObservationIgnored
    private(set) lazy var guardAdapter: BackgroundGuardAdapter = BackgroundGuardAdapter(guard_: guard_)

    @ObservationIgnored
    private var lectureCapTimer: Timer?

    @ObservationIgnored
    private let liveActivity = LiveActivityController()

    init() {
        let calendar = PlannerCalendar(cutoffHour: 3)
        self.timer = TimerEngine(calendar: calendar)
    }

    private func makeGuard() -> BackgroundGuard {
        let g = BackgroundGuard { [weak self] in
            guard let self else {
                return GuardContext(subjectAllowsPhoneUse: false)
            }
            return GuardContext(
                subjectAllowsPhoneUse: self.currentSubjectAllowsPhone,
                lockedScreenAllowed: false,
                lectureSecondsElapsed: self.timer.elapsedSeconds
            )
        }
        g.onDecision = { [weak self] _, action in
            self?.applyGuardAction(action)
        }
        return g
    }

    func setLectureContext(_ allows: Bool) {
        currentSubjectAllowsPhone = allows
    }

    /// Single entry point for starting a new session — keeps the banner state
    /// from leaking across sessions and centralises lecture-mode wiring.
    /// Background observers spin up here so they only run while a session is
    /// alive (PLAN §13 battery policy).
    @discardableResult
    func startSession(subject: Subject) -> Bool {
        lastGuardAction = .ignore
        lastStartError = nil
        setLectureContext(subject.allowPhoneUse)
        do {
            let session = try timer.start(subject: subject)
            if subject.allowPhoneUse { startLectureCapWatch() }
            guardAdapter.start()
            liveActivity.start(
                sessionId: session.id,
                subjectName: subject.name,
                subjectColorHex: subject.colorHex,
                startedAt: session.startedAt,
                targetSeconds: subject.dailyTargetMinutes * 60
            )
            HapticFeedback.impact(style: .light)
            return true
        } catch let error as TimerError {
            Persistence.log(error, context: "timer.start")
            switch error {
                case .alreadyRunning:
                    lastStartError = "이미 진행 중인 세션이 있어요. 종료 후 다시 시작해주세요."
                default:
                    lastStartError = "세션을 시작할 수 없어요."
            }
            return false
        } catch {
            Persistence.log(error, context: "timer.start.unknown")
            lastStartError = "세션을 시작할 수 없어요."
            return false
        }
    }

    func pauseSession(reason: PauseReason = .userManual) {
        pauseSessionInternal(reason: reason)
    }

    func resumeSession() {
        resumeSessionInternal()
    }

    /// Chokepoint that both the user buttons and `applyGuardAction` go through
    /// so the TimerEngine and LiveActivity stay in sync.
    private func pauseSessionInternal(reason: PauseReason) {
        guard timer.state == .running else { return }
        try? timer.pause(reason: reason)
        liveActivity.pause(at: Date(), activeSeconds: timer.elapsedSeconds)
    }

    private func resumeSessionInternal() {
        guard timer.state == .paused else { return }
        try? timer.resume()
        liveActivity.resume(at: Date(), activeSeconds: timer.elapsedSeconds)
    }

    @discardableResult
    func endSession() -> StudySession? {
        return closeSession()
    }

    /// Single chokepoint for "the timer just ended — persist and clean up".
    /// Used by user-initiated end, GuardAction.stop, and GuardAction.end so
    /// the side effects (persist + observers off + LiveActivity end) stay
    /// in sync no matter who triggers termination.
    @discardableResult
    private func closeSession() -> StudySession? {
        let session = try? timer.end()
        stopLectureCapWatch()
        guardAdapter.stop()
        if let session, let context = modelContext {
            persist(session, in: context)
        }
        liveActivity.end()
        return session
    }

    private func persist(_ session: StudySession, in context: ModelContext) {
        do {
            try SessionPersistence.save(session, context: context)
            lastPersistenceError = nil
            // Classify the session's nutrient by the subject's category.
            if let subject = lookupSubject(id: session.subjectID, in: context),
               subject.category == .workout {
                PlantProgressService.handleWorkoutSessionCompleted(session, context: context)
            } else {
                PlantProgressService.handleStudySessionCompleted(session, context: context)
            }
            StreakService.evaluate(context: context)
            WidgetSyncService.syncAll(context: context)
        } catch let error as SessionPersistenceError {
            lastPersistenceError = error
        } catch {
            lastPersistenceError = .saveFailed(underlying: error)
        }
    }

    private func lookupSubject(id: UUID, in context: ModelContext) -> SubjectModel? {
        let predicate = #Predicate<SubjectModel> { $0.id == id }
        return try? context.fetch(FetchDescriptor(predicate: predicate)).first
    }


    func handleScenePhase(_ phase: ScenePhase) {
        // Only react to scene phase while a session is alive.
        // Otherwise idle/ended states would surface a misleading "정지됨" banner
        // every time the user backgrounds the app.
        guard isTimerActive else { return }

        let signal: SceneSignal
        switch phase {
            case .background: signal = .enteredBackground
            case .inactive: signal = .becameInactive
            case .active: signal = .becameActive
            @unknown default: return
        }
        guard_.ingest(signal)
    }

    private var isTimerActive: Bool {
        timer.state == .running || timer.state == .paused
    }

    // MARK: - Lecture mode cap watcher
    func startLectureCapWatch() {
        stopLectureCapWatch()
        // 30s tick is enough — a 3h cap doesn't need second-level precision.
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.timer.lectureCapReached {
                    self.guard_.ingest(.lectureCapReached)
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        lectureCapTimer = t
    }

    func stopLectureCapWatch() {
        lectureCapTimer?.invalidate()
        lectureCapTimer = nil
    }

    private func applyGuardAction(_ action: GuardAction) {
        // Only mutate state when the action is actually applicable — otherwise
        // we'd leave a stale banner from a no-op decision.
        let applied: Bool
        switch action {
            case .stop:
                // Stop = session terminated. User must explicitly start again
                // (per PLAN v2.0 §5 + W0 review).
                guard isTimerActive else { applied = false; break }
                persistTerminatedSession()
                applied = true
            case .pause(let reason):
                guard timer.state == .running else { applied = false; break }
                pauseSessionInternal(reason: pauseReason(for: reason))
                applied = true
            case .resume:
                guard timer.state == .paused else { applied = false; break }
                resumeSessionInternal()
                applied = true
            case .end:
                guard isTimerActive else { applied = false; break }
                persistTerminatedSession()
                applied = true
            case .ignore:
                applied = false
        }
        if applied { lastGuardAction = action }
    }

    private func persistTerminatedSession() {
        _ = closeSession()
    }

    private func pauseReason(for trigger: PauseTrigger) -> PauseReason {
        switch trigger {
            case .userManual: return .userManual
            case .background: return .backgroundEntered
            case .screenLock: return .screenLocked
            case .phoneCall: return .phoneCall
            case .audio: return .audioInterruption
            case .pip: return .pipStarted
            case .splitView: return .splitViewShrunk
            case .lectureCap: return .lectureCapReached
        }
    }
}
