// DDayListView — list, edit, pin, delete D-Days.

import SwiftUI
import SwiftData

struct DDayListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DDayModel.targetDate) private var ddays: [DDayModel]
    @State private var editing: DDayModel?
    @State private var creatingNew = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(ddays) { d in
                    DDayRow(dday: d)
                        .swipeActions(edge: .leading) {
                            Button { togglePin(d) } label: {
                                Label(d.isPinned ? "고정 해제" : "고정", systemImage: "pin.fill")
                            }
                            .tint(DT.Color.warning)
                        }
                        .onTapGesture { editing = d }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("디데이")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { creatingNew = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $creatingNew) {
                DDayFormView(existing: nil)
            }
            .sheet(item: $editing) { d in
                DDayFormView(existing: d)
            }
        }
    }

    private func togglePin(_ d: DDayModel) {
        if !d.isPinned {
            ddays.forEach { $0.isPinned = false }
        }
        d.isPinned.toggle()
        Persistence.save({ try context.save() }, context: "dday.togglePin")
        WidgetSyncService.syncPinnedDDay(context: context)
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(ddays[i]) }
        Persistence.save({ try context.save() }, context: "dday.delete")
        WidgetSyncService.syncPinnedDDay(context: context)
    }
}

private struct DDayRow: View {
    let dday: DDayModel

    var body: some View {
        HStack(spacing: DT.Spacing.md) {
            Text(dday.emoji).font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(dday.title).font(DT.Typography.headline)
                    if dday.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(DT.Color.warning)
                    }
                }
                Text(dday.targetDate.formatted(date: .abbreviated, time: .omitted))
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }
            Spacer()
            Text(dDayLabel)
                .font(DT.Typography.headline)
                .foregroundStyle(DT.Color.primary)
                .monospacedDigit()
        }
    }

    private var dDayLabel: String {
        let r = dday.coreValue.daysRemaining(from: Date())
        if r > 0 { return "D-\(r)" }
        if r == 0 { return "D-DAY" }
        return "D+\(-r)"
    }
}
