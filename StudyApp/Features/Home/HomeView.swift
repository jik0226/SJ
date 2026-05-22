// HomeView — top-level dashboard.
// Ocean card + clickable today-card → timer, planner card → today planner.

import SwiftUI
import SwiftData
import StudyCore

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var recovery = RecoveryState.shared
    @State private var serverMode = ServerMode.shared

    @Query(filter: #Predicate<DDayModel> { $0.isPinned == true })
    private var pinnedDDays: [DDayModel]

    @Query private var plants: [PlantModel]

    @Query(sort: \StudySessionModel.startedAt)
    private var sessions: [StudySessionModel]

    private let calendar = PlannerCalendar(cutoffHour: 3)

    /// Bound by RootView so tapping the timer/planner card switches tabs.
    @Binding var selection: RootTab

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DT.Spacing.lg) {
                    // The primary CTA stays first no matter what. Problem
                    // banners sit BELOW it (UX review) so a bad sync state
                    // can never push "지금 바로 시작하기" off the first screen.
                    TodayProgressCard(
                        persistedSecondsToday: persistedSecondsToday,
                        liveSeconds: appState.timer.elapsedSeconds,
                        timerState: appState.timer.state,
                        onTap: { selection = .timer }
                    )
                    if let warning = recovery.warning {
                        RecoveryBanner(warning: warning) { recovery.acknowledge() }
                    }
                    if case .offline(let reason) = serverMode.state {
                        ServerOfflineBanner(reason: reason)
                    }
                    if let error = appState.lastPersistenceError {
                        PersistenceErrorBanner(error: error) {
                            appState.lastPersistenceError = nil
                        }
                    }
                    if let pinned = pinnedDDays.first {
                        DDayCard(dday: pinned)
                    }
                    PlannerShortcutCard(onTap: { selection = .planner })
                    OceanCard(plant: plants.first)
                    StreakCard()
                    Spacer(minLength: DT.Spacing.xxl)
                }
                .padding(.horizontal, DT.Spacing.lg)
                .padding(.top, DT.Spacing.lg)
            }
            .background(DT.Color.surface.ignoresSafeArea())
            .navigationTitle(homeTitle)
        }
    }

    private var homeTitle: String {
        let comps = Calendar.current.dateComponents([.month, .day], from: Date())
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return "오늘 · \(m)/\(d)"
    }

    private var persistedSecondsToday: Int {
        let today = calendar.plannerDay(for: Date())
        return sessions
            .filter { $0.plannerDay == today }
            .reduce(0) { $0 + $1.totalSeconds }
    }
}

private struct OceanCard: View {
    let plant: PlantModel?
    @State private var sway: Double = 0

    var body: some View {
        NavigationLink {
            PlantDetailView()
        } label: {
            VStack(spacing: DT.Spacing.md) {
                if let plant {
                    PlantCanvasView(parameters: plant.parameters, sway: sway)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
                } else {
                    Color.blue.opacity(0.3)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
                }
                Text(plant?.name ?? "내 바다")
                    .font(DT.Typography.title2)
                    .foregroundStyle(DT.Color.textPrimary)
                if let plant {
                    Text("공부 \(plant.studyMinutes)분 · 운동 \(plant.workoutMinutes)분")
                        .font(DT.Typography.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                } else {
                    Text("학습을 시작하면 파도가 일어나기 시작합니다.")
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
            // Continuous gentle wave animation.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000)
                await MainActor.run {
                    sway = (sway + 0.006).truncatingRemainder(dividingBy: 1.0)
                }
            }
        }
    }
}

private struct PlannerShortcutCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DT.Spacing.md) {
                Image(systemName: "calendar.day.timeline.left")
                    .font(.system(size: 24))
                    .foregroundStyle(DT.Color.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(DT.Color.primary.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("오늘 플래너")
                        .font(DT.Typography.headline)
                        .foregroundStyle(DT.Color.textPrimary)
                    Text("10분 블록을 채우거나 과거 기록을 확인")
                        .font(DT.Typography.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(DT.Color.textSecondary)
            }
            .padding(DT.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DT.Radius.card)
                    .fill(DT.Color.background)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
        }
        .buttonStyle(.plain)
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

/// Banner shown when `AppModelContainer` had to side-line the previous store.
/// We choose wording over icons so the user understands their data is safe
/// (archived, not deleted) rather than silently lost.
private struct RecoveryBanner: View {
    let warning: RecoveryState.Warning
    let onDismiss: () -> Void

    private var title: String {
        switch warning {
            case .archivedAfterFailedOpen: return "이전 데이터는 안전히 보관됐어요"
            case .inMemorySession: return "이번 세션은 디스크에 저장되지 않아요"
        }
    }

    private var body_text: String {
        switch warning {
            case .archivedAfterFailedOpen(let url):
                return "앱이 이전 기록을 열 수 없어 새로 시작했어요. 기존 파일은 그대로 보관 중이에요:\n\(url.lastPathComponent)"
            case .inMemorySession:
                return "디스크 접근에 실패해 메모리에만 기록됩니다. 앱을 종료하면 이번 기록은 사라져요. 잠시 후 앱을 다시 실행해 주세요."
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: DT.Spacing.sm) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(DT.Color.warning)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DT.Typography.headline)
                    .foregroundStyle(DT.Color.textPrimary)
                Text(body_text)
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                .fill(DT.Color.warning.opacity(0.12))
        )
    }
}

private struct ServerOfflineBanner: View {
    let reason: String

    var body: some View {
        HStack(alignment: .top, spacing: DT.Spacing.sm) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(DT.Color.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("친구·채팅 서버 연결이 끊겼어요")
                    .font(DT.Typography.headline)
                    .foregroundStyle(DT.Color.textPrimary)
                Text(reason)
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("타이머·플래너·바다는 평소처럼 동작합니다.")
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }
            Spacer()
        }
        .padding(DT.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.warning.opacity(0.12))
        )
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DT.Spacing.sm) {
                Text("오늘 순공시간")
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(formatted(seconds: total))
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(DT.Color.textPrimary)
                        .monospacedDigit()
                }
                HStack(spacing: DT.Spacing.sm) {
                    Image(systemName: ctaIcon)
                        .foregroundStyle(.white)
                    Text(ctaLabel)
                        .font(DT.Typography.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.85))
                        .font(.caption)
                }
                .padding(.horizontal, DT.Spacing.md)
                .padding(.vertical, DT.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DT.Radius.md)
                        .fill(DT.Color.primary)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DT.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DT.Radius.card)
                    .fill(DT.Color.background)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var ctaIcon: String {
        switch timerState {
            case .running: return "waveform"
            case .paused: return "pause.fill"
            default: return "play.fill"
        }
    }

    private var ctaLabel: String {
        switch timerState {
            case .running: return "지금 공부 중 — 타이머로 이동"
            case .paused: return "일시정지 중 — 재개하러 가기"
            default: return "지금 바로 시작하기"
        }
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
