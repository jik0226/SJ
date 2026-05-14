// TimerLiveActivity — Lock Screen + Dynamic Island for the running timer.
// Uses `Text(timerInterval:)` so the OS renders the running clock for us
// without process wake-ups (PLAN §6).
//
// Time model: `LiveActivityController.pause/resume` rebases `startedAt` so
// `pausedAt - startedAt == activeSeconds`. Both views use the same
// `LiveActivityElapsed` helper so the lock screen and the dynamic island
// never drift.

import ActivityKit
import WidgetKit
import SwiftUI

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(.white.opacity(0.92))
                .activitySystemActionForegroundColor(WT.Color.textPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Circle()
                        .fill(SwiftUI.Color.fromHexString(context.state.subjectColorHex))
                        .frame(width: 18, height: 18)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveActivityElapsed(state: context.state)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.subjectName)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let target = context.state.targetSeconds {
                        Text("목표 \(target / 60)분")
                            .font(.caption)
                            .foregroundStyle(WT.Color.textSecondary)
                    }
                }
            } compactLeading: {
                Circle()
                    .fill(SwiftUI.Color.fromHexString(context.state.subjectColorHex))
                    .frame(width: 12, height: 12)
            } compactTrailing: {
                LiveActivityElapsed(state: context.state)
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Circle()
                    .fill(SwiftUI.Color.fromHexString(context.state.subjectColorHex))
                    .frame(width: 12, height: 12)
            }
        }
    }
}

/// Single rendering of the active timer for every LiveActivity surface.
/// Reads `startedAt` (already rebased so the delta is active-time only).
struct LiveActivityElapsed: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        if let pausedAt = state.pausedAt {
            Text(Duration.seconds(max(0, Int(pausedAt.timeIntervalSince(state.startedAt)))),
                 format: .time(pattern: .hourMinuteSecond))
        } else {
            Text(timerInterval: state.startedAt...Date.distantFuture,
                 pauseTime: nil,
                 countsDown: false,
                 showsHours: true)
        }
    }
}

private struct LockScreenView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(SwiftUI.Color.fromHexString(state.subjectColorHex))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: state.pausedAt == nil ? "timer" : "pause.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(state.subjectName)
                    .font(.headline)
                    .foregroundStyle(WT.Color.textPrimary)
                if let target = state.targetSeconds {
                    Text("오늘 목표 \(target / 60)분")
                        .font(.caption)
                        .foregroundStyle(WT.Color.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                LiveActivityElapsed(state: state)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(WT.Color.textPrimary)
                Text(state.pausedAt == nil ? "측정 중" : "일시정지")
                    .font(.caption2)
                    .foregroundStyle(WT.Color.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
