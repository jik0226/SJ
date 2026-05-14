// DailyPageView — photo-1 right page (goal / key point / feedback / progress).
// Page row is seeded via `.task`, never inside binding getters, so SwiftUI's
// body evaluation stays free of side effects.

import SwiftUI
import SwiftData

struct DailyPageView: View {
    let plannerDay: Int
    @Environment(\.modelContext) private var context

    @Query private var pages: [DailyPageModel]

    init(plannerDay: Int) {
        self.plannerDay = plannerDay
        _pages = Query(filter: #Predicate<DailyPageModel> {
            $0.plannerDay == plannerDay
        })
    }

    var body: some View {
        Group {
            if let page = pages.first {
                content(page: page)
            } else {
                placeholder
            }
        }
        .task(id: plannerDay) {
            await ensurePageExists()
        }
    }

    @ViewBuilder
    private func content(page: DailyPageModel) -> some View {
        VStack(alignment: .leading, spacing: DT.Spacing.md) {
            sectionHeader("오늘의 목표")
            EditableField(
                placeholder: "오늘 무엇을 끝낼까?",
                text: bind(page, \.todayGoal),
                lines: 3
            )

            sectionHeader("Key Point")
            EditableField(
                placeholder: "오늘 가장 중요한 한 가지",
                text: bind(page, \.keyPoint),
                lines: 2
            )

            sectionHeader("Feedback")
            EditableField(
                placeholder: "오늘 무엇이 잘 됐고, 무엇이 부족했나",
                text: bind(page, \.feedback),
                lines: 3
            )

            sectionHeader("Progress")
            ProgressSlider(value: bind(page, \.progressPercent))
        }
        .padding(DT.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.background)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }

    private var placeholder: some View {
        ProgressView()
            .frame(maxWidth: .infinity, minHeight: 200)
            .padding(DT.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DT.Radius.card)
                    .fill(DT.Color.background)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }

    private func ensurePageExists() async {
        guard pages.isEmpty else { return }
        context.insert(DailyPageModel(plannerDay: plannerDay))
        try? context.save()
    }

    private func bind<V>(
        _ page: DailyPageModel,
        _ keyPath: ReferenceWritableKeyPath<DailyPageModel, V>
    ) -> Binding<V> {
        Binding(
            get: { page[keyPath: keyPath] },
            set: { newValue in
                page[keyPath: keyPath] = newValue
                try? context.save()
            }
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DT.Typography.caption)
            .foregroundStyle(DT.Color.textSecondary)
    }
}

private struct EditableField: View {
    let placeholder: String
    @Binding var text: String
    let lines: Int

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .lineLimit(lines, reservesSpace: true)
            .font(DT.Typography.body)
            .padding(DT.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DT.Radius.md)
                    .fill(DT.Color.surface)
            )
    }
}

private struct ProgressSlider: View {
    @Binding var value: Int

    var body: some View {
        VStack(spacing: DT.Spacing.sm) {
            HStack {
                Text("\(value)%")
                    .font(DT.Typography.headline)
                    .foregroundStyle(DT.Color.primary)
                    .monospacedDigit()
                Spacer()
            }
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0.rounded()) }
                ),
                in: 0...100,
                step: 5
            )
            .tint(DT.Color.primary)
        }
    }
}
