// TimerEngine — pure state machine for a single study/workout timer.
// Time is injected via `clock` so tests can drive it deterministically.

import Foundation
import Observation
import Models
import PlannerCalendar

@MainActor
@Observable
public final class TimerEngine {
    public private(set) var state: TimerState = .idle
    public private(set) var session: StudySession?
    public private(set) var subject: Subject?

    private let clock: () -> Date
    private let calendar: PlannerCalendar

    public init(
        calendar: PlannerCalendar = PlannerCalendar(),
        clock: @escaping () -> Date = { Date() }
    ) {
        self.calendar = calendar
        self.clock = clock
    }

    @discardableResult
    public func start(subject: Subject) throws -> StudySession {
        guard state == .idle || state == .ended else {
            throw TimerError.alreadyRunning
        }
        let now = clock()
        let new = StudySession(
            subjectID: subject.id,
            startedAt: now,
            plannerDay: calendar.plannerDay(for: now)
        )
        self.subject = subject
        self.session = new
        self.state = .running
        return new
    }

    public func pause(reason: PauseReason) throws {
        guard state == .running else { throw TimerError.notRunning }
        guard var current = session else { throw TimerError.noActiveSession }
        current.pausedRanges.append(PausedRange(start: clock(), reason: reason))
        self.session = current
        self.state = .paused
    }

    public func resume() throws {
        guard state == .paused else { throw TimerError.notPaused }
        guard var current = session else { throw TimerError.noActiveSession }
        guard let lastIdx = current.pausedRanges.indices.last else {
            throw TimerError.notPaused
        }
        var last = current.pausedRanges[lastIdx]
        guard last.end == nil else { throw TimerError.notPaused }
        last.end = clock()
        current.pausedRanges[lastIdx] = last
        self.session = current
        self.state = .running
    }

    @discardableResult
    public func end() throws -> StudySession {
        guard state == .running || state == .paused else {
            throw TimerError.notRunning
        }
        guard var current = session else { throw TimerError.noActiveSession }
        let now = clock()
        // Close any dangling pause range first.
        if state == .paused, let lastIdx = current.pausedRanges.indices.last,
           current.pausedRanges[lastIdx].end == nil {
            current.pausedRanges[lastIdx].end = now
        }
        current.endedAt = now
        current.totalSeconds = computeActiveSeconds(for: current, now: now)
        self.session = current
        self.state = .ended
        return current
    }

    /// Convenience: ID of the subject the engine is currently bound to, or
    /// nil when idle/ended. UI layers (FocusModeView) read this to look up
    /// the matching SubjectModel by id without having to keep a parallel
    /// reference around.
    public var runningSubjectID: UUID? { subject?.id }

    /// Seconds the timer was actively counting (start to now, minus pauses).
    public var elapsedSeconds: Int {
        guard let s = session else { return 0 }
        return computeActiveSeconds(for: s, now: clock())
    }

    /// True when an active lecture-mode session has hit the 3-hour cap.
    public var lectureCapReached: Bool {
        guard let subj = subject, subj.allowPhoneUse else { return false }
        return elapsedSeconds >= Subject.lectureModeMaxSeconds
    }

    private func computeActiveSeconds(for s: StudySession, now: Date) -> Int {
        let end = s.endedAt ?? now
        let gross = Int(end.timeIntervalSince(s.startedAt))
        let paused = s.pausedRanges.reduce(0) { acc, r in
            let e = r.end ?? now
            return acc + max(0, Int(e.timeIntervalSince(r.start)))
        }
        return max(0, gross - paused)
    }
}
