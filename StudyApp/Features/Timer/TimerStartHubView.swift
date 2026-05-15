// TimerStartHubView — idle-state "study launcher" surface.
//
// Replaces the legacy chip+ring+button layout with a per-subject row list
// where every subject is one tap away from a session, and today's totals
// are the most prominent thing on screen.

import SwiftUI
import SwiftData
import StudyCore

struct TimerStartHubView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \SubjectModel.createdAt) private var subjects: [SubjectModel]
    @Query(sort: \StudySessionModel.startedAt) private var sessions: [StudySessionModel]

    let onStartGPSRun: (SubjectModel) -> Void
    let onOpenPomodoroSheet: () -> Void

    @State private var showingSubjectForm = false

    private let calendar = PlannerCalendar(cutoffHour: 3)
    private var today: Int { calendar.plannerDay(for: Date()) }

    var body: some View {
        ScrollView {
            VStack(spacing: DT.Spacing.lg) {
                if let startError = appState.lastStartError {
                    startErrorBanner(startError)
                }
                headerCard
                if subjects.isEmpty {
                    emptyState
                } else {
                    subjectList
                }
                pomodoroOption
                Spacer(minLength: DT.Spacing.xxl)
            }
            .padding(.horizontal, DT.Spacing.lg)
            .padding(.top, DT.Spacing.lg)
        }
        .sheet(isPresented: $showingSubjectForm) {
            // Direct to the add form so the user lands on the action they
            // clicked, not on yet another list. Existing == nil = create.
            SubjectFormView(existing: nil)
        }
    }

    /// Surfaces `AppState.lastStartError`. Previously the start path could
    /// fail silently — the user tapped ▶ and got no visible feedback. The
    /// banner sits at the top of the hub with an explicit dismiss so the
    /// next start attempt can re-render it cleanly.
    private func startErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: DT.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DT.Color.error)
            VStack(alignment: .leading, spacing: 2) {
                Text("시작하지 못했어요")
                    .font(DT.Typography.headline)
                    .foregroundStyle(DT.Color.textPrimary)
                Text(message)
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                appState.lastStartError = nil
            } label: {
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

    // MARK: - Header (today total + target gap)

    private var headerCard: some View {
        VStack(spacing: DT.Spacing.xs) {
            Text("오늘 누적")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
            Text(formatted(seconds: todayTotalSeconds))
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DT.Color.textPrimary)
            Text(targetGapLabel)
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DT.Spacing.xl)
        .padding(.horizontal, DT.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.background)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, y: 1)
    }

    private var todayTotalSeconds: Int {
        sessions.filter { $0.plannerDay == today }.reduce(0) { $0 + $1.totalSeconds }
    }

    /// Sum of seconds spent today on rows that belong to *study* subjects.
    /// Workout sessions are excluded so the "목표까지" gap stays apples-to-apples
    /// with the study-only goal sum below.
    private var todayStudyOnlySeconds: Int {
        let studyIds = Set(
            subjects.filter { $0.category == .study }.map(\.id)
        )
        return sessions
            .filter { $0.plannerDay == today && studyIds.contains($0.subjectID) }
            .reduce(0) { $0 + $1.totalSeconds }
    }

    private var targetGapLabel: String {
        let totalGoalMinutes = subjects
            .filter { $0.category == .study }
            .reduce(0) { $0 + $1.dailyTargetMinutes }
        guard totalGoalMinutes > 0 else { return "오늘 시작해볼까요?" }
        let doneMinutes = todayStudyOnlySeconds / 60
        if doneMinutes >= totalGoalMinutes {
            return "오늘 목표 달성! 🌊"
        }
        let remaining = totalGoalMinutes - doneMinutes
        let h = remaining / 60
        let m = remaining % 60
        if h > 0 { return "오늘 목표까지 \(h)시간 \(m)분 남았어요" }
        return "오늘 목표까지 \(m)분 남았어요"
    }

    // MARK: - Subject list

    private var subjectList: some View {
        VStack(spacing: DT.Spacing.sm) {
            ForEach(subjects) { subject in
                SubjectStartCard(
                    subject: subject,
                    todayMinutes: minutes(for: subject),
                    onTap: { start(subject) }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DT.Spacing.md) {
            Image(systemName: "books.vertical")
                .font(.system(size: 36))
                .foregroundStyle(DT.Color.textSecondary)
            Text("아직 과목이 없어요")
                .font(DT.Typography.body)
                .foregroundStyle(DT.Color.textPrimary)
            Text("타이머를 쓰려면 먼저 과목을 만들어야 해요. 색·아이콘·일일 목표·강의 모드를 한 번에 정할 수 있어요.")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DT.Spacing.lg)
            Button {
                showingSubjectForm = true
            } label: {
                HStack(spacing: DT.Spacing.xs) {
                    Image(systemName: "plus.circle.fill")
                    Text("과목 추가")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DT.Spacing.xl)
                .padding(.vertical, DT.Spacing.md)
                .background(Capsule().fill(DT.Color.primary))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DT.Spacing.xl)
        .padding(.horizontal, DT.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.background)
        )
    }

    private func minutes(for subject: SubjectModel) -> Int {
        sessions
            .filter { $0.plannerDay == today && $0.subjectID == subject.id }
            .reduce(0) { $0 + $1.totalSeconds } / 60
    }

    private func start(_ subject: SubjectModel) {
        if subject.category == .workout, subject.workoutType?.usesGPS == true {
            onStartGPSRun(subject)
        } else {
            appState.startSession(subject: subject.coreValue)
        }
    }

    // MARK: - Pomodoro secondary option

    private var pomodoroOption: some View {
        Button(action: onOpenPomodoroSheet) {
            HStack(spacing: DT.Spacing.sm) {
                Image(systemName: "timer.circle.fill")
                    .foregroundStyle(DT.Color.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("포모도로")
                        .font(DT.Typography.body)
                        .foregroundStyle(DT.Color.textPrimary)
                    Text(pomodoroDescription)
                        .font(DT.Typography.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }
            .padding(DT.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DT.Radius.card)
                    .fill(DT.Color.background)
            )
        }
        .buttonStyle(.plain)
    }

    private var pomodoroDescription: String {
        if PomodoroSettings.isEnabled {
            return "집중 \(PomodoroSettings.workMinutes)분 / 휴식 \(PomodoroSettings.restMinutes)분 — 켜짐"
        }
        return "집중 / 휴식 주기로 자동 일시정지 — 꺼짐"
    }

    private func formatted(seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}

/// One subject row in the launcher list. Whole row is tappable for start;
/// the trailing play icon clarifies the affordance.
private struct SubjectStartCard: View {
    let subject: SubjectModel
    let todayMinutes: Int
    let onTap: () -> Void

    private var accent: SwiftUI.Color {
        SwiftUI.Color(hexString: subject.colorHex) ?? DT.Color.primary
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DT.Spacing.md) {
                Image(systemName: subject.sfSymbol)
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(accent))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(subject.name)
                            .font(DT.Typography.headline)
                            .foregroundStyle(DT.Color.textPrimary)
                        if subject.allowPhoneUse {
                            Text("강의")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(DT.Color.warning))
                        }
                    }
                    Text(metricLabel)
                        .font(DT.Typography.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                    if subject.dailyTargetMinutes > 0 {
                        ProgressView(value: progressValue)
                            .progressViewStyle(.linear)
                            .tint(accent)
                            .frame(maxWidth: 180)
                    }
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(accent)
            }
            .padding(DT.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DT.Radius.card)
                    .fill(DT.Color.background)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var metricLabel: String {
        if subject.dailyTargetMinutes > 0 {
            return "오늘 \(todayMinutes)분 · 목표 \(subject.dailyTargetMinutes)분"
        }
        return "오늘 \(todayMinutes)분"
    }

    private var progressValue: Double {
        guard subject.dailyTargetMinutes > 0 else { return 0 }
        return min(1, Double(todayMinutes) / Double(subject.dailyTargetMinutes))
    }
}
