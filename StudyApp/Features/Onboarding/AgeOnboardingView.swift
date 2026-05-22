// AgeOnboardingView — first-launch age gate.
// Stores `isMinor` on the user's profile using true 만 나이 (real age),
// not just year-difference, so the minor cutoff matches the PLAN §9 policy.

import SwiftUI
import SwiftData
import StudyCore

struct AgeOnboardingView: View {
    let onComplete: () -> Void
    @Environment(\.modelContext) private var context
    @State private var nickname: String = ""
    @State private var birthDate: Date = Calendar.current.date(
        byAdding: .year, value: -18, to: Date()
    ) ?? Date()
    @FocusState private var nicknameFocused: Bool

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DT.Spacing.xl) {
                VStack(spacing: DT.Spacing.md) {
                    Image(systemName: "water.waves")
                        .font(.system(size: 56))
                        .foregroundStyle(DT.Color.primary)
                    Text("SJ에 오신 걸 환영해요")
                        .font(DT.Typography.title1)
                        .foregroundStyle(DT.Color.textPrimary)
                    Text("시작 전에 두 가지만 알려주세요.\n친구에게 보일 이름과 생년월일이에요.")
                        .font(DT.Typography.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DT.Color.textPrimary)
                        .padding(.horizontal, DT.Spacing.lg)
                }
                .padding(.top, DT.Spacing.xxl)

                VStack(alignment: .leading, spacing: DT.Spacing.xs) {
                    Text("친구에게 보일 이름")
                        .font(DT.Typography.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                    TextField("예: 인겸", text: $nickname)
                        .textFieldStyle(.roundedBorder)
                        .focused($nicknameFocused)
                        .submitLabel(.done)
                    Text("그룹·1:1 채팅에서 이 이름으로 보여요. 나중에 프로필에서 바꿀 수 있어요.")
                        .font(.caption2)
                        .foregroundStyle(DT.Color.textSecondary)
                }
                .padding(.horizontal, DT.Spacing.xl)

                VStack(alignment: .leading, spacing: DT.Spacing.xs) {
                    Text("생년월일")
                        .font(DT.Typography.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                    DatePicker(
                        "생년월일",
                        selection: $birthDate,
                        in: dateRange,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    Text("청소년 보호 정책(만 14세 미만 메시지 제한 등) 적용에만 쓰여요. 외부에 공유하지 않습니다.")
                        .font(.caption2)
                        .foregroundStyle(DT.Color.textSecondary)
                }
                .padding(.horizontal, DT.Spacing.xl)

                Button(action: complete) {
                    Text("시작하기")
                        .font(DT.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DT.Spacing.md)
                        .background(Capsule().fill(
                            trimmedNickname.isEmpty ? DT.Color.primary.opacity(0.4) : DT.Color.primary
                        ))
                        .padding(.horizontal, DT.Spacing.xl)
                }
                .buttonStyle(.plain)
                .disabled(trimmedNickname.isEmpty)

                Spacer(minLength: DT.Spacing.xxl)
            }
        }
        .background(DT.Color.surface.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }

    private var dateRange: ClosedRange<Date> {
        let cal = Calendar.current
        let lower = cal.date(byAdding: .year, value: -100, to: Date()) ?? Date()
        return lower...Date()
    }

    private func complete() {
        let cleanName = trimmedNickname
        guard !cleanName.isEmpty else { return }
        let me = SocialService.me(in: context)
        me.nickname = cleanName
        me.isMinor = isMinor(birthDate: birthDate)
        Persistence.save({ try context.save() }, context: "onboarding.profile")
        // Now that a real nickname exists, publish so friends can discover us.
        FirestoreSyncService.shared.publishMe(me)
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
