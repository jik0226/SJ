// TimerView — top-level study tab.
// Branches between two distinct surfaces based on engine state:
//   - idle / ended  → TimerStartHubView  (subject launcher list)
//   - running / paused → FocusModeView   (immersive session view)
//
// GPS-bearing workouts still detour through RunningView via fullScreenCover.
// Pomodoro toggle moved off the main flow into a sheet from the launcher.

import SwiftUI
import SwiftData
import StudyCore

struct TimerView: View {
    @Environment(AppState.self) private var appState
    @State private var runningSubject: SubjectModel?
    @State private var showingPomodoro = false

    var body: some View {
        Group {
            switch appState.timer.state {
                case .running, .paused:
                    FocusModeView()
                case .idle, .ended:
                    TimerStartHubView(
                        onStartGPSRun: { runningSubject = $0 },
                        onOpenPomodoroSheet: { showingPomodoro = true }
                    )
            }
        }
        .background(DT.Color.surface.ignoresSafeArea())
        .fullScreenCover(item: $runningSubject) { subject in
            NavigationStack {
                RunningView(subject: subject)
                    .navigationTitle(subject.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .interactiveDismissDisabled()
            }
        }
        .sheet(isPresented: $showingPomodoro) {
            PomodoroSettingsSheet()
        }
    }
}

/// Pill-shaped action button shared by FocusModeView and RunningView. Kept at
/// top-level scope so the older RunningView keeps compiling unchanged.
struct PillButton: View {
    enum Style { case primary, ghost }
    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DT.Typography.headline)
                .foregroundStyle(style == .primary ? .white : DT.Color.primary)
                .padding(.horizontal, DT.Spacing.xl)
                .padding(.vertical, DT.Spacing.md)
                .background(
                    Capsule().fill(style == .primary ? DT.Color.primary : DT.Color.background)
                )
                .overlay(
                    Capsule().stroke(DT.Color.primary, lineWidth: style == .ghost ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}
