// PlannerView — photo-1 in digital form.
// Top: 10-minute slot grid. Bottom: today's goal / key point / feedback / progress.

import SwiftUI
import SwiftData
import StudyCore

struct PlannerView: View {
    private let calendar = PlannerCalendar(cutoffHour: 3)

    var body: some View {
        let today = calendar.plannerDay(for: Date())
        NavigationStack {
            ScrollView {
                VStack(spacing: DT.Spacing.lg) {
                    BlockGridView(plannerDay: today)
                        .padding(.vertical, DT.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DT.Radius.card)
                                .fill(DT.Color.background)
                        )
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
                        .padding(.horizontal, DT.Spacing.lg)

                    DailyPageView(plannerDay: today)
                        .padding(.horizontal, DT.Spacing.lg)
                }
                .padding(.vertical, DT.Spacing.lg)
            }
            .background(DT.Color.surface.ignoresSafeArea())
            .navigationTitle("플래너")
        }
    }
}
