// BlockGridView — photo-1 left page.
// 22 rows × 6 columns (132 slots), wrapping 05:00 → 02:50 so the visual order
// matches the paper planner. Underlying slot indices still span 0..143.

import SwiftUI
import SwiftData
import StudyCore

struct BlockGridView: View {
    let plannerDay: Int

    @Query private var subjects: [SubjectModel]
    @Query private var blocks: [PlannerBlockModel]

    /// Hours shown top→bottom: 5, 6, …, 23, 0, 1, 2 (22 rows total).
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
