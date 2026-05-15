// PlannerView — photo-1 in digital form, now with day navigation.
// Top: 10-minute slot grid (tap to edit). Bottom: today's goal / key point /
// feedback / progress for the selected day.

import SwiftUI
import SwiftData
import StudyCore

struct PlannerView: View {
    private let calendar = PlannerCalendar(cutoffHour: 3)
    @State private var selectedDate: Date = Date()
    @State private var showingDatePicker = false

    private var selectedPlannerDay: Int {
        calendar.plannerDay(for: selectedDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DT.Spacing.lg) {
                    dayHeader
                    BlockGridView(plannerDay: selectedPlannerDay)
                        .padding(.vertical, DT.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DT.Radius.card)
                                .fill(DT.Color.background)
                        )
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
                        .padding(.horizontal, DT.Spacing.lg)

                    DailyPageView(plannerDay: selectedPlannerDay)
                        .padding(.horizontal, DT.Spacing.lg)
                }
                .padding(.vertical, DT.Spacing.lg)
            }
            .background(DT.Color.surface.ignoresSafeArea())
            .navigationTitle("플래너")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingDatePicker = true }) {
                        Image(systemName: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DayPickerSheet(date: selectedDate) { picked in
                    selectedDate = picked
                }
            }
        }
    }

    private var dayHeader: some View {
        HStack(spacing: DT.Spacing.md) {
            Button(action: { shiftDay(-1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
            }
            Spacer()
            Button(action: { showingDatePicker = true }) {
                VStack(spacing: 2) {
                    Text(formattedSelected)
                        .font(DT.Typography.title2)
                        .foregroundStyle(DT.Color.textPrimary)
                    if isToday {
                        Text("오늘")
                            .font(.caption)
                            .foregroundStyle(DT.Color.primary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button(action: { shiftDay(1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
            }
            .disabled(isToday)
            .opacity(isToday ? 0.3 : 1)
        }
        .padding(.horizontal, DT.Spacing.xl)
    }

    private var isToday: Bool {
        selectedPlannerDay == calendar.plannerDay(for: Date())
    }

    private var formattedSelected: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: selectedDate)
    }

    private func shiftDay(_ days: Int) {
        if let next = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            // Block future days: planner shouldn't pre-render unseen time.
            if next <= Date() { selectedDate = next }
        }
    }
}

private struct DayPickerSheet: View {
    /// Initial date passed from the parent. We keep a *draft* copy so that
    /// rotating through the DatePicker doesn't immediately mutate parent
    /// state — "취소" should mean cancel, not "save anyway".
    let initialDate: Date
    let onConfirm: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Date

    init(date: Date, onConfirm: @escaping (Date) -> Void) {
        self.initialDate = date
        self.onConfirm = onConfirm
        _draft = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "날짜 선택",
                    selection: $draft,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                Spacer()
            }
            .navigationTitle("플래너 날짜")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") {
                        onConfirm(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
