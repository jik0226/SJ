// TimerView — circular elapsed display + start/pause/end controls.
// Uses TimelineView for 1s ticks without spamming SwiftData.

import SwiftUI
import SwiftData
import StudyCore

struct TimerView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \SubjectModel.createdAt) private var subjects: [SubjectModel]
    @State private var selectedSubject: SubjectModel?
    @State private var runningSubject: SubjectModel?

    var body: some View {
        VStack(spacing: DT.Spacing.xl) {
            subjectPicker
            timerDial
            controls
            guardBanner
            Spacer()
        }
        .padding(.horizontal, DT.Spacing.lg)
        .padding(.top, DT.Spacing.xl)
        .background(DT.Color.surface.ignoresSafeArea())
        .onAppear {
            if selectedSubject == nil { selectedSubject = subjects.first }
        }
        .fullScreenCover(item: $runningSubject) { subject in
            // Running flow owns its own dismissal via the Stop button so a
            // mid-run dismiss can't drop the recorded distance/time.
            NavigationStack {
                RunningView(subject: subject)
                    .navigationTitle(subject.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .interactiveDismissDisabled()
            }
        }
    }

    private var subjectPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DT.Spacing.sm) {
                ForEach(subjects) { subject in
                    SubjectChip(
                        subject: subject,
                        isSelected: selectedSubject?.id == subject.id
                    )
                    .onTapGesture {
                        guard appState.timer.state == .idle || appState.timer.state == .ended
                        else { return }
                        selectedSubject = subject
                    }
                }
            }
            .padding(.horizontal, DT.Spacing.xs)
        }
    }

    private var timerDial: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            ZStack {
                Circle()
                    .stroke(DT.Color.primary.opacity(0.15), lineWidth: 14)
                Circle()
                    .stroke(DT.Color.primary, lineWidth: 14)
                    .rotationEffect(.degrees(-90))
                    .opacity(appState.timer.state == .running ? 1 : 0.4)
                VStack(spacing: DT.Spacing.xs) {
                    Text(formattedElapsed())
                        .font(.system(size: 48, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(DT.Color.textPrimary)
                    Text(stateLabel)
                        .font(DT.Typography.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                }
            }
            .frame(width: 260, height: 260)
        }
    }

    private var controls: some View {
        HStack(spacing: DT.Spacing.md) {
            switch appState.timer.state {
                case .idle, .ended:
                    PillButton(title: "시작", style: .primary) {
                        guard let s = selectedSubject else { return }
                        // GPS-bearing workouts get the RunningView; gym / free
                        // workouts share the plain timer with study subjects.
                        if s.category == .workout, s.workoutType?.usesGPS == true {
                            runningSubject = s
                        } else {
                            appState.startSession(subject: s.coreValue)
                        }
                    }
                    .disabled(selectedSubject == nil)
                    .opacity(selectedSubject == nil ? 0.4 : 1.0)
                case .running:
                    PillButton(title: "일시정지", style: .ghost) {
                        appState.pauseSession()
                    }
                    PillButton(title: "종료", style: .primary) {
                        appState.endSession()
                    }
                case .paused:
                    PillButton(title: "재개", style: .primary) {
                        appState.resumeSession()
                    }
                    PillButton(title: "종료", style: .ghost) {
                        appState.endSession()
                    }
            }
        }
    }

    @ViewBuilder
    private var guardBanner: some View {
        if let startError = appState.lastStartError {
            bannerText(startError, color: DT.Color.error)
        } else {
            switch appState.lastGuardAction {
                case .stop(let reason):
                    bannerText("정지됨: \(label(reason))", color: DT.Color.error)
                case .pause(let reason):
                    bannerText("일시정지: \(label(reason))", color: DT.Color.warning)
                default:
                    EmptyView()
            }
        }
    }

    private func bannerText(_ text: String, color: SwiftUI.Color) -> some View {
        Text(text)
            .font(DT.Typography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, DT.Spacing.md)
            .padding(.vertical, DT.Spacing.sm)
            .background(
                Capsule().fill(color.opacity(0.12))
            )
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

    private func formattedElapsed() -> String {
        let s = appState.timer.elapsedSeconds
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    private var stateLabel: String {
        switch appState.timer.state {
            case .idle: return selectedSubject?.name ?? "과목을 선택하세요"
            case .running: return "측정 중"
            case .paused: return "일시정지"
            case .ended: return "종료"
        }
    }
}

private struct SubjectChip: View {
    let subject: SubjectModel
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DT.Spacing.xs) {
            Image(systemName: subject.sfSymbol)
            Text(subject.name)
        }
        .font(DT.Typography.caption)
        .foregroundStyle(isSelected ? .white : DT.Color.textPrimary)
        .padding(.horizontal, DT.Spacing.md)
        .padding(.vertical, DT.Spacing.sm)
        .background(
            Capsule().fill(
                isSelected ? (SwiftUI.Color(hexString: subject.colorHex) ?? DT.Color.primary)
                           : DT.Color.background
            )
        )
    }
}

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
