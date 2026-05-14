// AgeOnboardingView — first-launch age gate.
// Stores `isMinor` on the user's profile using true 만 나이 (real age),
// not just year-difference, so the minor cutoff matches the PLAN §9 policy.

import SwiftUI
import SwiftData
import StudyCore

struct AgeOnboardingView: View {
    let onComplete: () -> Void
    @Environment(\.modelContext) private var context
    @State private var birthDate: Date = Calendar.current.date(
        byAdding: .year, value: -18, to: Date()
    ) ?? Date()

    var body: some View {
        VStack(spacing: DT.Spacing.xl) {
            Spacer()
            VStack(spacing: DT.Spacing.md) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 64))
                    .foregroundStyle(DT.Color.primary)
                Text("생년월일을 알려주세요")
                    .font(DT.Typography.title1)
                    .foregroundStyle(DT.Color.textPrimary)
                Text("만 14세 미만 사용자에게는 안전 정책이 자동 적용됩니다.\n친구 검색·익명 메시지 등 일부 기능이 제한될 수 있어요.")
                    .font(DT.Typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DT.Color.textSecondary)
                    .padding(.horizontal, DT.Spacing.lg)
            }

            DatePicker(
                "생년월일",
                selection: $birthDate,
                in: dateRange,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 180)
            .padding(.horizontal, DT.Spacing.xl)

            Button(action: complete) {
                Text("시작하기")
                    .font(DT.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DT.Spacing.md)
                    .background(Capsule().fill(DT.Color.primary))
                    .padding(.horizontal, DT.Spacing.xl)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .background(DT.Color.surface.ignoresSafeArea())
    }

    private var dateRange: ClosedRange<Date> {
        let cal = Calendar.current
        let lower = cal.date(byAdding: .year, value: -100, to: Date()) ?? Date()
        return lower...Date()
    }

    private func complete() {
        let me = SocialService.me(in: context)
        me.isMinor = isMinor(birthDate: birthDate)
        Persistence.save({ try context.save() }, context: "onboarding.age")
        UserDefaults.standard.set(true, forKey: "onboarding.complete")
        Task {
            await NotificationsService.requestAuthorizationIfNeeded()
            NotificationsService.scheduleDailyReminder()
        }
        onComplete()
    }

    private func isMinor(birthDate: Date) -> Bool {
        let cal = Calendar.current
        let ageComponents = cal.dateComponents([.year], from: birthDate, to: Date())
        return (ageComponents.year ?? 0) < 14
    }
}
