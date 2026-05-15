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
    /// Set when HealthKit returns `.failed` so the SummarySheet can surface it
    /// alongside the closing button. Top-of-screen banners get covered by the
    /// sheet so they can't be the sole channel.
    @State private var summaryHealthError: String?
    /// Set when SwiftData failed to persist the run. We still show the recap
    /// (the user did do the work) but flag prominently that it wasn't saved
    /// so they can re-do or note it manually.
    @State private var summarySaveFailed = false
    @State private var healthBanner: String?
    @State private var pendingEndConfirm = false
    @State private var lastSummaryNoise = false
    /// Auto-started on entry so the user's "시작" from TimerView doesn't get
    /// asked twice. Guards against re-entry when SwiftUI re-runs `.task`.
    @State private var didAutoStart = false

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
            // The user already tapped "시작" in TimerView — don't make them
            // tap it again. Auto-start once permission resolution settles.
            if !didAutoStart, manager.canStart, manager.state == .idle {
                didAutoStart = true
                manager.start()
            }
        }
        .confirmationDialog(
            "운동을 종료할까요?",
            isPresented: $pendingEndConfirm,
            titleVisibility: .visible
        ) {
            Button("종료", role: .destructive) { endRun() }
            Button("계속 진행", role: .cancel) {}
        } message: {
            Text("이번 운동을 마무리하고 기록을 저장합니다.")
        }
        .sheet(item: $completedSession) { session in
            RunSummarySheet(
                session: session,
                workoutType: subject.workoutType ?? .running,
                isNoiseTier: lastSummaryNoise,
                healthError: summaryHealthError,
                saveFailed: summarySaveFailed
            ) {
                completedSession = nil
                summaryHealthError = nil
                summarySaveFailed = false
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
            // Funnel both the top-left "종료" and the bottom "종료" PillButton
            // through the same confirmation so a stray tap can't drop the run.
            pendingEndConfirm = true
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
                    PillButton(title: "종료", style: .primary) { pendingEndConfirm = true }
                case .paused:
                    PillButton(title: "재개", style: .primary) { manager.resume() }
                    PillButton(title: "종료", style: .ghost) { pendingEndConfirm = true }
            }
        }
    }

    private func endRun() {
        // Capture active seconds BEFORE manager.end() so we judge noise on
        // actual running time, not wall-clock (which includes pauses).
        let activeSeconds = manager.elapsedSeconds
        guard let session = manager.end() else { return }
        // Noise tier: too-short to be a real session, so we don't persist.
        // But surface that fact in the SummarySheet instead of dismissing —
        // a silent dismiss makes the user wonder if a tap was eaten.
        let isNoise = session.distanceMeters < 100 && activeSeconds < 60
        lastSummaryNoise = isNoise
        if !isNoise {
            let model = RunSessionModel(from: session)
            context.insert(model)
            let saved = Persistence.save({ try context.save() }, context: "run.save") != nil
            summarySaveFailed = !saved
            if saved {
                // Only grow the ocean if persistence succeeded — otherwise the
                // user could re-do the run and double-count their nutrients.
                PlantProgressService.handleRunCompleted(session, context: context)
                // Mirror to Firestore: raw run goes into /private, summary
                // (todayStudyMinutes etc.) refreshes via AppState below.
                FirestoreSyncService.shared.publishRun(model)
                appState.publishPublicSnapshot(context: context)
            } else {
                // Roll back the optimistic insert so the persisted set stays
                // consistent. The summary will warn the user that nothing was
                // saved; doing the run again won't double up.
                context.delete(model)
            }
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
                            // Route into the sheet so the user actually sees it.
                            summaryHealthError = reason
                    }
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
