// FocusModeView — running/paused-state surface.
//
// Replaces the legacy "everything on one screen" layout: when the timer is
// actively measuring, we surface only the session number, the target-relative
// progress ring, today's total, and the controls. Lecture/guard state sits
// next to the controls so users see *why* the timer might pause itself.

import SwiftUI
import SwiftData
import StudyCore

struct FocusModeView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \StudySessionModel.startedAt) private var sessions: [StudySessionModel]
    @Query(sort: \SubjectModel.createdAt) private var subjects: [SubjectModel]
    @State private var pendingEndConfirm = false

    private let calendar = PlannerCalendar(cutoffHour: 3)
    private var today: Int { calendar.plannerDay(for: Date()) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            // ScrollView wrapper so small phones (iPhone SE) + large Dynamic
            // Type don't clip the lecture footer or the control row. The
            // dial keeps its fixed 260pt so the visual hierarchy stays.
            ScrollView {
                VStack(spacing: DT.Spacing.lg) {
                    header
                    dial
                    statsRow
                    pomodoroSidecar
                    controls
                    guardBanner
                    lectureFooter
                    Spacer(minLength: DT.Spacing.xl)
                }
                .padding(.horizontal, DT.Spacing.lg)
                .padding(.top, DT.Spacing.xl)
                .frame(maxWidth: .infinity)
            }
        }
        .background(DT.Color.surface.ignoresSafeArea())
        .confirmationDialog(
            "공부를 종료할까요?",
            isPresented: $pendingEndConfirm,
            titleVisibility: .visible
        ) {
            Button("종료하고 저장", role: .destructive) { appState.endSession() }
            Button("계속 공부하기", role: .cancel) {}
        } message: {
            Text("이번 세션의 \(shortElapsed)을 저장하고 플래너에 자동 기록합니다.")
        }
    }

    private var shortElapsed: String {
        let s = appState.timer.elapsedSeconds
        let m = s / 60
        return m > 0 ? "\(m)분" : "\(s)초"
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text(subjectName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(DT.Color.textPrimary)
            Text(stateLabel)
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
        }
    }

    private var subjectName: String {
        currentSubject?.name ?? "공부 중"
    }

    private var currentSubject: SubjectModel? {
        guard let id = appState.timer.runningSubjectID else { return nil }
        return subjects.first { $0.id == id }
    }

    private var stateLabel: String {
        switch appState.timer.state {
            case .paused: return "일시정지"
            default: return "측정 중"
        }
    }

    // MARK: - Dial (always target-progress; pomodoro is a sidecar below)

    /// Single source of truth for the central numeric: always the elapsed
    /// seconds of the current session, always wrapped in the target-progress
    /// ring. Pomodoro doesn't replace this anymore — instead it gets its own
    /// small indicator under the stats row so the user never has to wonder
    /// what the big number on screen means.
    private var dial: some View {
        targetProgressDial
            .frame(width: 260, height: 260)
    }

    private var targetProgressDial: some View {
        ZStack {
            Circle()
                .stroke(DT.Color.primary.opacity(0.15), lineWidth: 14)
            Circle()
                .trim(from: 0, to: targetProgress)
                .stroke(DT.Color.primary, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: targetProgress)
            VStack(spacing: 4) {
                Text("이번 세션")
                    .font(.caption)
                    .foregroundStyle(DT.Color.textSecondary)
                Text(formatted(seconds: appState.timer.elapsedSeconds))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(DT.Color.textPrimary)
                Text(targetCaption)
                    .font(.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }
            .padding(.horizontal, DT.Spacing.md)
            .multilineTextAlignment(.center)
        }
    }

    /// Compact pomodoro readout shown *below* the main ring, never replacing
    /// it. Communicates the cycle without changing the meaning of the big
    /// number on screen.
    @ViewBuilder
    private var pomodoroSidecar: some View {
        if PomodoroSettings.isEnabled {
            HStack(spacing: DT.Spacing.sm) {
                Image(systemName: "timer.circle.fill")
                    .foregroundStyle(DT.Color.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("포모도로")
                        .font(.caption.bold())
                        .foregroundStyle(DT.Color.textPrimary)
                    Text(pomodoroLabel)
                        .font(.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                        .monospacedDigit()
                }
                Spacer()
                pomodoroMiniRing
            }
            .padding(.horizontal, DT.Spacing.md)
            .padding(.vertical, DT.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DT.Radius.md)
                    .fill(DT.Color.background)
            )
        }
    }

    private var pomodoroLabel: String {
        let remaining = appState.pomodoroRemainingSeconds
        let work = PomodoroSettings.workMinutes
        let rest = PomodoroSettings.restMinutes
        let mm = remaining / 60
        let ss = remaining % 60
        return String(format: "집중 %d분 / 휴식 %d분 · 남은 %02d:%02d", work, rest, mm, ss)
    }

    private var pomodoroMiniRing: some View {
        let total = max(1, PomodoroSettings.workMinutes * 60)
        let remaining = max(0, min(total, appState.pomodoroRemainingSeconds))
        let progress = Double(remaining) / Double(total)
        return ZStack {
            Circle().stroke(DT.Color.primary.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(DT.Color.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 32, height: 32)
    }

    private var targetProgress: Double {
        guard let goal = currentSubject?.dailyTargetMinutes, goal > 0 else { return 0 }
        let totalDoneSec = todayMinutesForSubject * 60 + appState.timer.elapsedSeconds
        return min(1, Double(totalDoneSec) / Double(goal * 60))
    }

    private var targetCaption: String {
        guard let goal = currentSubject?.dailyTargetMinutes, goal > 0 else {
            return "목표 미설정"
        }
        let done = todayMinutesForSubject + appState.timer.elapsedSeconds / 60
        return "오늘 \(done)분 / 목표 \(goal)분"
    }

    // MARK: - Today totals row

    private var statsRow: some View {
        HStack(spacing: DT.Spacing.md) {
            statBlock(label: "이번 세션",
                      value: formatted(seconds: appState.timer.elapsedSeconds))
            statBlock(label: "오늘 전체",
                      value: formatted(seconds: todayTotalSecondsLive))
        }
    }

    private func statBlock(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(DT.Color.textSecondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DT.Color.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DT.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.md)
                .fill(DT.Color.background)
        )
    }

    private var todayMinutesForSubject: Int {
        guard let id = currentSubject?.id else { return 0 }
        return sessions
            .filter { $0.plannerDay == today && $0.subjectID == id }
            .reduce(0) { $0 + $1.totalSeconds } / 60
    }

    private var todayTotalSecondsLive: Int {
        let persisted = sessions.filter { $0.plannerDay == today }
            .reduce(0) { $0 + $1.totalSeconds }
        return persisted + appState.timer.elapsedSeconds
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: DT.Spacing.md) {
            switch appState.timer.state {
                case .running:
                    // Primary = 일시정지 (the action the user keeps doing across
                    // a long study session). 종료 is destructive — it triggers
                    // the persist + plant nutrient pump and ends the run, so
                    // it goes through a confirmationDialog from a ghost button.
                    PillButton(title: "일시정지", style: .primary) { appState.pauseSession() }
                    PillButton(title: "종료", style: .ghost) { pendingEndConfirm = true }
                case .paused:
                    PillButton(title: "재개", style: .primary) { appState.resumeSession() }
                    PillButton(title: "종료", style: .ghost) { pendingEndConfirm = true }
                default: EmptyView()
            }
        }
    }

    // MARK: - Banners + lecture footer

    @ViewBuilder
    private var guardBanner: some View {
        switch appState.lastGuardAction {
            case .stop(let reason):
                bannerText("정지됨: \(label(reason))", color: DT.Color.error)
            case .pause(let reason):
                bannerText("일시정지: \(label(reason))", color: DT.Color.warning)
            default:
                EmptyView()
        }
    }

    private var lectureFooter: some View {
        HStack(spacing: DT.Spacing.sm) {
            Image(systemName: currentSubject?.allowPhoneUse == true
                  ? "lock.open.fill" : "lock.shield.fill")
                .foregroundStyle(currentSubject?.allowPhoneUse == true
                                 ? DT.Color.warning : DT.Color.success)
            Text(currentSubject?.allowPhoneUse == true
                 ? "강의 모드 — 다른 앱 사용해도 정지하지 않아요 (최대 3시간)"
                 : "방해 차단 — 다른 앱으로 나가면 자동 일시정지")
                .font(.caption)
                .foregroundStyle(DT.Color.textSecondary)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.horizontal, DT.Spacing.lg)
        .padding(.bottom, DT.Spacing.xl)
    }

    private func bannerText(_ text: String, color: SwiftUI.Color) -> some View {
        Text(text)
            .font(DT.Typography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, DT.Spacing.md)
            .padding(.vertical, DT.Spacing.sm)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private func label(_ trigger: PauseTrigger) -> String {
        switch trigger {
            case .background: return "다른 앱 사용 감지"
            case .screenLock: return "화면 잠금"
            case .phoneCall: return "통화"
            case .audio: return "오디오 인터럽션"
            case .pip: return "PiP 시작"
            case .splitView: return "분할 화면 축소"
            case .lectureCap: return "강의 모드 3시간 초과"
            case .userManual: return "수동"
        }
    }

    private func formatted(seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}
