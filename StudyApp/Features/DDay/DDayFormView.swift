// DDayFormView — create or edit a DDay.

import SwiftUI
import SwiftData

struct DDayFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let existing: DDayModel?

    @State private var title: String = ""
    @State private var date: Date = .now
    @State private var emoji: String = "📅"
    @State private var isPinned: Bool = false

    private let emojiPalette = ["📚", "📝", "🎯", "🏆", "✏️", "🎂", "💼", "🏃", "🎓", "📅"]

    var body: some View {
        NavigationStack {
            Form {
                Section("제목") {
                    TextField("예: 수능", text: $title)
                }
                Section("날짜") {
                    DatePicker("D-Day", selection: $date, displayedComponents: .date)
                }
                Section("이모지") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5)) {
                        ForEach(emojiPalette, id: \.self) { e in
                            Text(e)
                                .font(.system(size: 28))
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: DT.Radius.md)
                                        .fill(emoji == e ? DT.Color.primary.opacity(0.15) : .clear)
                                )
                                .onTapGesture { emoji = e }
                        }
                    }
                }
                Section {
                    Toggle("메인 화면에 고정", isOn: $isPinned)
                }
            }
            .navigationTitle(existing == nil ? "새 D-Day" : "D-Day 편집")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") { save() }.disabled(title.isEmpty)
                }
            }
            .onAppear { hydrate() }
        }
    }

    private func hydrate() {
        guard let d = existing else { return }
        title = d.title
        date = d.targetDate
        emoji = d.emoji
        isPinned = d.isPinned
    }

    private func save() {
        if isPinned {
            // Unpin everyone else so the home card stays unambiguous.
            let all = (try? context.fetch(FetchDescriptor<DDayModel>())) ?? []
            all.forEach { $0.isPinned = false }
        }
        if let d = existing {
            d.title = title
            d.targetDate = date
            d.emoji = emoji
            d.isPinned = isPinned
        } else {
            context.insert(DDayModel(
                title: title, targetDate: date, emoji: emoji, isPinned: isPinned
            ))
        }
        Persistence.save({ try context.save() }, context: "dday.save")
        WidgetSyncService.syncPinnedDDay(context: context)
        dismiss()
    }
}
