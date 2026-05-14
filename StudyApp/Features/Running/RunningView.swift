// RunningView — start/stop a run, show live distance, pace, and elapsed.

import SwiftUI
import SwiftData
import StudyCore

struct RunningView: View {
    let subject: SubjectModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var manager = RunningManager()
    @State private var completedSession: RunSession?
    @State private var healthBanner: String?

    var body: some View {
        ScrollView {
            VStack(spacing: DT.Spacing.xl) {
                header
                if let banner = manager.authBanner {
                    authWarning(banner)
                }
                if let banner = healthBanner {
                    authWarning(banner)
                }
                metrics
                controls
                Spacer(minLength: DT.Spacing.xxl)
            }
            .padding(.horizontal, DT.Spacing.lg)
            .padding(.top, DT.Spacing.xl)
        }
        .background(DT.Color.surface.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: closeAction) {
                    // Active run → "종료" funnels through endRun so the data
                    // can't be silently dropped.
                    Text(isActive ? "종료" : "취소")
                }
            }
        }
        .task {
            manager.workoutType = subject.workoutType ?? .running
            manager.requestAuthorizationIfNeeded()
            let result = await HealthService.shared.requestAuthorization()
            switch result {
                case .granted, .unavailable:
                    healthBanner = nil
                case .partial:
                    healthBanner = "건강 앱 일부 권한이 거부됐어요. 일부 기록만 저장됩니다."
                case .failed(let reason):
                    healthBanner = "건강 앱 권한 요청 실패: \(reason)"
            }
        }
        .sheet(item: $completedSession) { session in
            RunSummarySheet(
                session: session,
                workoutType: subject.workoutType ?? .running
            ) {
                completedSession = nil
                dismiss()
            }
            .interactiveDismissDisabled()
        }
    }

    private var isActive: Bool {
        manager.state == .running || manager.state == .paused
    }

    private func closeAction() {
        if isActive {
            endRun()
        } else {
            dismiss()
        }
    }

    private func authWarning(_ text: String) -> some View {
        Text(text)
            .font(DT.Typography.caption)
            .foregroundStyle(DT.Color.error)
            .multilineTextAlignment(.leading)
            .padding(DT.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DT.Radius.md)
                    .fill(DT.Color.error.opacity(0.10))
            )
    }

    private var header: some View {
        VStack(spacing: DT.Spacing.xs) {
            Image(systemName: subject.sfSymbol)
                .font(.system(size: 36))
                .foregroundStyle(SwiftUI.Color(hexString: subject.colorHex) ?? DT.Color.primary)
            Text(subject.name)
                .font(DT.Typography.title2)
                .foregroundStyle(DT.Color.textPrimary)
        }
    }

    private var metrics: some View {
        VStack(spacing: DT.Spacing.lg) {
            MetricCard(
                title: "거리",
                value: String(format: "%.2f km", manager.distanceMeters / 1000.0)
            )
            HStack(spacing: DT.Spacing.lg) {
                MetricCard(
                    title: "경과",
                    value: formatted(seconds: manager.elapsedSeconds)
                )
                MetricCard(
                    title: "평균 페이스",
                    value: paceFormatted
                )
            }
        }
    }

    private var paceFormatted: String {
        let p = manager.currentPaceSecPerKm
        guard p > 0 else { return "—" }
        return String(format: "%d'%02d\"", p / 60, p % 60)
    }

    private var controls: some View {
        HStack(spacing: DT.Spacing.md) {
            switch manager.state {
                case .idle, .ended:
                    PillButton(title: "시작", style: .primary) { manager.start() }
                        .disabled(!manager.canStart)
                case .running:
                    PillButton(title: "일시정지", style: .ghost) { manager.pause() }
                    PillButton(title: "종료", style: .primary) { endRun() }
                case .paused:
                    PillButton(title: "재개", style: .primary) { manager.resume() }
                    PillButton(title: "종료", style: .ghost) { endRun() }
            }
        }
    }

    private func endRun() {
        // Capture active seconds BEFORE manager.end() so we judge noise on
        // actual running time, not wall-clock (which includes pauses).
        let activeSeconds = manager.elapsedSeconds
        guard let session = manager.end() else { return }
        // Skip noise-tier sessions: tap-tap (no distance, no time) shouldn't
        // pollute HealthKit or the planner.
        let isNoise = session.distanceMeters < 100 && activeSeconds < 60
        if isNoise {
            dismiss()
            return
        }
        context.insert(RunSessionModel(from: session))
        Persistence.save({ try context.save() }, context: "run.save")
        PlantProgressService.handleRunCompleted(session, context: context)
        let workoutType = subject.workoutType ?? .running
        Task {
            let result = await HealthService.shared.saveWorkout(
                workoutType: workoutType,
                startedAt: session.startedAt,
                activeSeconds: session.totalActiveSeconds,
                distanceMeters: session.distanceMeters,
                caloriesKcal: session.caloriesKcal
            )
            await MainActor.run {
                switch result {
                    case .saved, .noopShortRun, .unavailable:
                        break
                    case .failed(let reason):
                        healthBanner = "건강 앱 저장 실패: \(reason)"
                }
            }
        }
        completedSession = session
    }

    private func formatted(seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}

private struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.xs) {
            Text(title)
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(DT.Color.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DT.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.background)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }
}
