// RunSummarySheet — celebratory recap shown right after a finished run.

import SwiftUI
import StudyCore

struct RunSummarySheet: View {
    let session: RunSession
    let workoutType: WorkoutType
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: DT.Spacing.xl) {
            Spacer()
            Image(systemName: workoutType.defaultSFSymbol)
                .font(.system(size: 72))
                .foregroundStyle(DT.Color.primary)
            Text("\(workoutType.completedLabel)! 🎉")
                .font(DT.Typography.title1)
                .foregroundStyle(DT.Color.textPrimary)

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
