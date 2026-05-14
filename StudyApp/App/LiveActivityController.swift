// LiveActivityController — thin wrapper around ActivityKit so AppState doesn't
// own the async surface directly. Safe to call on missing entitlement: every
// API path swallows ActivityKit errors and logs.
//
// Time model: `startedAt` is recomputed on pause/resume so that
// `Date.now - startedAt` (running) and `pausedAt - startedAt` (paused) both
// equal the actual **active** elapsed time. `accumulatedSeconds` is kept as a
// debugging hint but the widget shouldn't rely on it for display.

import Foundation
import ActivityKit
import StudyCore

@MainActor
final class LiveActivityController {
    private var current: Activity<TimerActivityAttributes>?

    func start(
        sessionId: UUID,
        subjectName: String,
        subjectColorHex: String,
        startedAt: Date,
        targetSeconds: Int?
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = TimerActivityAttributes(sessionId: sessionId)
        let state = TimerActivityAttributes.ContentState(
            startedAt: startedAt,
            pausedAt: nil,
            accumulatedSeconds: 0,
            subjectName: subjectName,
            subjectColorHex: subjectColorHex,
            targetSeconds: targetSeconds
        )
        do {
            current = try Activity<TimerActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            current = nil
        }
    }

    /// `activeSeconds` is the count we want frozen on the lock screen.
    /// We rebase `startedAt` so `pausedAt - startedAt == activeSeconds` exactly.
    func pause(at: Date, activeSeconds: Int) {
        guard let activity = current else { return }
        let old = activity.content.state
        let rebased = at.addingTimeInterval(-TimeInterval(activeSeconds))
        let state = TimerActivityAttributes.ContentState(
            startedAt: rebased,
            pausedAt: at,
            accumulatedSeconds: activeSeconds,
            subjectName: old.subjectName,
            subjectColorHex: old.subjectColorHex,
            targetSeconds: old.targetSeconds
        )
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    /// `activeSeconds` is the elapsed-so-far value at the moment of resume.
    /// We rebase `startedAt` to `now - activeSeconds` so the OS-driven counter
    /// keeps growing from that point.
    func resume(at: Date, activeSeconds: Int) {
        guard let activity = current else { return }
        let old = activity.content.state
        let rebased = at.addingTimeInterval(-TimeInterval(activeSeconds))
        let state = TimerActivityAttributes.ContentState(
            startedAt: rebased,
            pausedAt: nil,
            accumulatedSeconds: activeSeconds,
            subjectName: old.subjectName,
            subjectColorHex: old.subjectColorHex,
            targetSeconds: old.targetSeconds
        )
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity = current else { return }
        let final = activity.content.state
        Task {
            await activity.end(
                ActivityContent(state: final, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        current = nil
    }
}
