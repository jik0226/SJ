// HomeView — top-level dashboard.
// Plant card replaces the old mascot/species card: the visual itself is a
// procedural canvas driven by PlantFormula(seed, nutrients).

import SwiftUI
import SwiftData
import StudyCore

struct HomeView: View {
    @Environment(AppState.self) private var appState

    @Query(filter: #Predicate<DDayModel> { $0.isPinned == true })
    private var pinnedDDays: [DDayModel]

    @Query private var plants: [PlantModel]

    @Query(sort: \StudySessionModel.startedAt)
    private var sessions: [StudySessionModel]

    private let calendar = PlannerCalendar(cutoffHour: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DT.Spacing.lg) {
                    if let error = appState.lastPersistenceError {
                        PersistenceErrorBanner(error: error) {
                            appState.lastPersistenceError = nil
                        }
                    }
                    PlantCard(plant: plants.first)
                    if let pinned = pinnedDDays.first {
                        DDayCard(dday: pinned)
                    }
                    TodayProgressCard(
                        persistedSecondsToday: persistedSecondsToday,
                        liveSeconds: appState.timer.elapsedSeconds,
                        timerState: appState.timer.state
                    )
                    StreakCard()
                    Spacer(minLength: DT.Spacing.xxl)
                }
                .padding(.horizontal, DT.Spacing.lg)
                .padding(.top, DT.Spacing.lg)
            }
            .background(DT.Color.surface.ignoresSafeArea())
            .navigationTitle("오늘")
        }
    }

    private var persistedSecondsToday: Int {
        let today = calendar.plannerDay(for: Date())
        return sessions
            .filter { $0.plannerDay == today }
            .reduce(0) { $0 + $1.totalSeconds }
    }
}

private struct PlantCard: View {
    let plant: PlantModel?
    @State private var sway: Double = 0

    var body: some View {
        NavigationLink {
            PlantDetailView()
        } label: {
            VStack(spacing: DT.Spacing.md) {
                if let plant {
                    PlantCanvasView(parameters: plant.parameters, sway: sway)
                        .frame(height: 180)
                } else {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(DT.Color.primary.opacity(0.5))
                        .frame(height: 180)
                }
                Text(plant?.name ?? "씨앗")
                    .font(DT.Typography.title2)
                    .foregroundStyle(DT.Color.textPrimary)
                if let plant {
                    Text("공부 \(plant.studyMinutes)분 · 운동 \(plant.workoutMinutes)분")
                        .font(DT.Typography.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                } else {
                    Text("처음 학습을 시작하면 자라기 시작합니다.")
                        .font(DT.Typography.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DT.Spacing.lg)
            .padding(.horizontal, DT.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DT.Radius.card)
                    .fill(DT.Color.background)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .task {
            // Gentle sway loop.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000)
                await MainActor.run {
                    sway = (sway + 0.008).truncatingRemainder(dividingBy: 1.0)
                }
            }
        }
    }
}

private struct StreakCard: View {
    var body: some View {
        let length = StreakService.currentLength
        let alive = StreakService.isStreakAliveToday
        HStack(spacing: DT.Spacing.md) {
            Image(systemName: alive ? "flame.fill" : "flame")
                .font(.system(size: 28))
                .foregroundStyle(alive ? DT.Color.warning : DT.Color.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("연속 학습")
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
                Text("\(length)일")
                    .font(DT.Typography.title2)
                    .foregroundStyle(DT.Color.textPrimary)
                    .monospacedDigit()
            }
            Spacer()
            if !alive && length > 0 {
                Text("오늘 목표 미달성")
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.error)
            }
        }
        .padding(DT.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.background)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }
}

private struct PersistenceErrorBanner: View {
    let error: SessionPersistenceError
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DT.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DT.Color.error)
            VStack(alignment: .leading, spacing: 2) {
                Text("세션 저장 실패")
                    .font(DT.Typography.headline)
                    .foregroundStyle(DT.Color.textPrimary)
                Text("다음 세션 시작 전 잠시 후 다시 시도해주세요.")
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(DT.Color.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(DT.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.error.opacity(0.10))
        )
    }
}

private struct DDayCard: View {
    let dday: DDayModel

    var body: some View {
        HStack(spacing: DT.Spacing.md) {
            Text(dday.emoji).font(.system(size: 28))
            VStack(alignment: .leading, spacing: DT.Spacing.xs) {
                Text(dday.title)
                    .font(DT.Typography.headline)
                    .foregroundStyle(DT.Color.textPrimary)
                Text(dDayLabel(for: dday))
                    .font(DT.Typography.title1)
                    .foregroundStyle(DT.Color.primary)
                    .monospacedDigit()
            }
            Spacer()
        }
        .padding(DT.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.background)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private func dDayLabel(for dday: DDayModel) -> String {
        let remaining = dday.coreValue.daysRemaining(from: Date())
        if remaining > 0 { return "D-\(remaining)" }
        if remaining == 0 { return "D-DAY" }
        return "D+\(-remaining)"
    }
}

private struct TodayProgressCard: View {
    let persistedSecondsToday: Int
    let liveSeconds: Int
    let timerState: TimerState

    var body: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.sm) {
            Text("오늘 순공시간")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(formatted(seconds: total))
                    .font(DT.Typography.title1)
                    .foregroundStyle(DT.Color.textPrimary)
                    .monospacedDigit()
            }
            Text("상태: \(stateLabel)")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DT.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.background)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private var total: Int {
        timerState == .running || timerState == .paused
            ? persistedSecondsToday + liveSeconds
            : persistedSecondsToday
    }

    private var stateLabel: String {
        switch timerState {
            case .idle: return "대기"
            case .running: return "측정 중"
            case .paused: return "일시정지"
            case .ended: return "종료"
        }
    }

    private func formatted(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
