// BlockGridView — photo-1 left page, now editable.
// 22 rows × 6 columns (132 slots), wrapping 05:00 → 02:50.
// Tap any cell to assign / clear a subject for that 10-minute slot manually
// (useful when the user studied without the timer running).

import SwiftUI
import SwiftData
import StudyCore

struct BlockGridView: View {
    let plannerDay: Int

    @Environment(\.modelContext) private var context
    @Query private var subjects: [SubjectModel]
    @Query private var blocks: [PlannerBlockModel]

    @State private var editingSlot: Int?

    private static let displayedHours: [Int] = Array(5...23) + Array(0...2)

    init(plannerDay: Int) {
        self.plannerDay = plannerDay
        _blocks = Query(filter: #Predicate<PlannerBlockModel> {
            $0.plannerDay == plannerDay
        })
    }

    var body: some View {
        VStack(spacing: 4) {
            header
            ForEach(BlockGridView.displayedHours.indices, id: \.self) { i in
                row(for: BlockGridView.displayedHours[i])
            }
        }
        .padding(.horizontal, DT.Spacing.md)
        .sheet(item: Binding(
            get: { editingSlot.map { SlotEdit(index: $0) } },
            set: { editingSlot = $0?.index }
        )) { edit in
            SlotEditSheet(
                plannerDay: plannerDay,
                slotIndex: edit.index,
                subjects: subjects,
                currentSubjectID: blocks.first(where: { $0.slotIndex == edit.index })?.subjectID,
                onAssign: { subjectID in assign(slotIndex: edit.index, subjectID: subjectID) },
                onClear: { clear(slotIndex: edit.index) }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("h")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DT.Color.textSecondary)
                .frame(width: 24)
            ForEach(1..<7) { i in
                Text("\(i * 10)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DT.Color.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func row(for hour: Int) -> some View {
        HStack(spacing: 4) {
            Text(String(format: "%02d", hour))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DT.Color.textSecondary)
                .frame(width: 24)
            ForEach(0..<6) { col in
                let slotIndex = hour * 6 + col
                BlockCell(color: color(for: slotIndex))
                    .onTapGesture { editingSlot = slotIndex }
            }
        }
    }

    private func color(for slotIndex: Int) -> SwiftUI.Color? {
        guard let block = blocks.first(where: { $0.slotIndex == slotIndex }),
              let subjectID = block.subjectID,
              let subject = subjects.first(where: { $0.id == subjectID }) else {
            return nil
        }
        return SwiftUI.Color(hexString: subject.colorHex)
    }

    private func assign(slotIndex: Int, subjectID: UUID) {
        let key = PlannerBlockModel.makeSlotKey(plannerDay: plannerDay, slotIndex: slotIndex)
        let predicate = #Predicate<PlannerBlockModel> { $0.slotKey == key }
        let descriptor = FetchDescriptor<PlannerBlockModel>(predicate: predicate)
        let block: PlannerBlockModel
        if let existing = try? context.fetch(descriptor).first {
            existing.subjectID = subjectID
            block = existing
        } else {
            block = PlannerBlockModel(
                plannerDay: plannerDay, slotIndex: slotIndex, subjectID: subjectID
            )
            context.insert(block)
        }
        if Persistence.save({ try context.save() }, context: "planner.assignSlot") != nil {
            FirestoreSyncService.shared.publishPlannerBlock(block)
        }
    }

    private func clear(slotIndex: Int) {
        let key = PlannerBlockModel.makeSlotKey(plannerDay: plannerDay, slotIndex: slotIndex)
        let predicate = #Predicate<PlannerBlockModel> { $0.slotKey == key }
        let descriptor = FetchDescriptor<PlannerBlockModel>(predicate: predicate)
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            if Persistence.save({ try context.save() }, context: "planner.clearSlot") != nil {
                FirestoreSyncService.shared.deletePlannerBlock(slotKey: key)
            }
        }
    }
}

private struct SlotEdit: Identifiable {
    let index: Int
    var id: Int { index }
}

private struct BlockCell: View {
    let color: SwiftUI.Color?

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color ?? DT.Color.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(DT.Color.textSecondary.opacity(0.2), lineWidth: 0.5)
            )
            .aspectRatio(1, contentMode: .fit)
    }
}

private struct SlotEditSheet: View {
    let plannerDay: Int
    let slotIndex: Int
    let subjects: [SubjectModel]
    let currentSubjectID: UUID?
    let onAssign: (UUID) -> Void
    let onClear: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var slotTimeLabel: String {
        let hour = slotIndex / 6
        let minute = (slotIndex % 6) * 10
        return String(format: "%02d:%02d ~ %02d:%02d",
                      hour, minute,
                      (minute + 10) >= 60 ? (hour + 1) % 24 : hour,
                      (minute + 10) % 60)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("시간") {
                    Text(slotTimeLabel)
                        .font(.body.monospacedDigit())
                }
                Section("과목") {
                    if subjects.isEmpty {
                        Text("먼저 과목을 추가해주세요.")
                            .foregroundStyle(DT.Color.textSecondary)
                    } else {
                        ForEach(subjects) { subject in
                            Button {
                                onAssign(subject.id)
                                dismiss()
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(SwiftUI.Color(hexString: subject.colorHex) ?? DT.Color.primary)
                                        .frame(width: 18, height: 18)
                                    Text(subject.name)
                                        .foregroundStyle(DT.Color.textPrimary)
                                    Spacer()
                                    if subject.id == currentSubjectID {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(DT.Color.primary)
                                    }
                                }
                            }
                        }
                    }
                }
                if currentSubjectID != nil {
                    Section {
                        Button(role: .destructive) {
                            onClear()
                            dismiss()
                        } label: {
                            Label("이 칸 비우기", systemImage: "eraser")
                        }
                    }
                }
            }
            .navigationTitle("슬롯 편집")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}
