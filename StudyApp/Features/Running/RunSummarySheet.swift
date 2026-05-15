// RunSummarySheet — celebratory recap shown right after a finished run.

import SwiftUI
import StudyCore

struct RunSummarySheet: View {
    let session: RunSession
    let workoutType: WorkoutType
    /// True iff distance < 100m AND active seconds < 60s. The session was not
    /// persisted; surface the reason here instead of dismissing silently.
    var isNoiseTier: Bool = false
    /// Filled when HealthKit returned `.failed(...)`. Shown inside the sheet
    /// so the user actually sees it (the screen-level banner gets hidden by
    /// the sheet itself).
    var healthError: String? = nil
    /// True when SwiftData persistence failed. The metrics still display so
    /// the user sees what they achieved, but a red banner makes it clear the
    /// record is not saved — otherwise they walk away believing it was.
    var saveFailed: Bool = false
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: DT.Spacing.xl) {
            Spacer()
            Image(systemName: workoutType.defaultSFSymbol)
                .font(.system(size: 72))
                .foregroundStyle(isNoiseTier ? DT.Color.textSecondary : DT.Color.primary)
            Text(headlineText)
                .font(DT.Typography.title1)
                .foregroundStyle(DT.Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DT.Spacing.lg)

            if isNoiseTier {
                noiseHint
            } else {
                metricsCard
            }

            if saveFailed {
                saveFailedBanner
            }
            if let healthError {
                healthFailureBanner(healthError)
            }

            Spacer()

            Button(action: onClose) {
                Text("닫기")
                    .font(DT.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DT.Spacing.md)
                    .background(Capsule().fill(DT.Color.primary))
                    .padding(.horizontal, DT.Spacing.xl)
            }
            .buttonStyle(.plain)
            .padding(.bottom, DT.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DT.Color.background.ignoresSafeArea())
    }

    private var headlineText: String {
        isNoiseTier
            ? "기록되지 않았어요"
            : "\(workoutType.completedLabel)! 🎉"
    }

    private var noiseHint: some View {
        VStack(spacing: DT.Spacing.sm) {
            Text("이번 운동은 너무 짧아 기록되지 않았어요.")
                .font(DT.Typography.body)
                .foregroundStyle(DT.Color.textSecondary)
                .multilineTextAlignment(.center)
            Text("최소 100m 또는 1분 이상 진행해야\n통계와 바다 영양분에 반영됩니다.")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DT.Spacing.xl)
    }

    private var metricsCard: some View {
        VStack(spacing: DT.Spacing.md) {
            row(label: "거리", value: String(format: "%.2f km", session.distanceKilometers))
            row(label: "시간", value: formatted(seconds: durationSeconds))
            row(label: "평균 페이스", value: paceLabel)
            row(label: "예상 칼로리", value: "\(Int(session.caloriesKcal)) kcal")
        }
        .padding(DT.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.surface)
        )
        .padding(.horizontal, DT.Spacing.lg)
    }

    private var saveFailedBanner: some View {
        HStack(spacing: DT.Spacing.sm) {
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(DT.Color.error)
            VStack(alignment: .leading, spacing: 2) {
                Text("기록 저장 실패")
                    .font(.caption.bold())
                    .foregroundStyle(DT.Color.textPrimary)
                Text("이번 운동은 디스크에 저장되지 않았어요. 통계와 바다 영양분에는 반영되지 않습니다.")
                    .font(.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }
            Spacer()
        }
        .padding(DT.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.md)
                .fill(DT.Color.error.opacity(0.12))
        )
        .padding(.horizontal, DT.Spacing.lg)
    }

    private func healthFailureBanner(_ text: String) -> some View {
        HStack(spacing: DT.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DT.Color.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("건강 앱 저장 실패")
                    .font(.caption.bold())
                    .foregroundStyle(DT.Color.textPrimary)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }
            Spacer()
        }
        .padding(DT.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.md)
                .fill(DT.Color.warning.opacity(0.12))
        )
        .padding(.horizontal, DT.Spacing.lg)
    }

    private var durationSeconds: Int {
        // Use pause-aware active duration; falls back to wall-clock only if
        // the active count was never populated (legacy rows).
        if session.totalActiveSeconds > 0 { return session.totalActiveSeconds }
        let end = session.endedAt ?? Date()
        return max(0, Int(end.timeIntervalSince(session.startedAt)))
    }

    private var paceLabel: String {
        let p = session.avgPaceSecPerKm
        guard p > 0 else { return "—" }
        return String(format: "%d'%02d\" / km", p / 60, p % 60)
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DT.Typography.body)
                .foregroundStyle(DT.Color.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(DT.Color.textPrimary)
                .monospacedDigit()
        }
    }

    private func formatted(seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}
