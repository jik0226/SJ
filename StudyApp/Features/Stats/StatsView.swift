// StatsView — daily / weekly / monthly summary using Apple Charts.

import SwiftUI
import SwiftData
import Charts
import StudyCore

struct StatsView: View {
    @Environment(\.modelContext) private var context

    @State private var range: StatsRange = .week

    private let calendar = PlannerCalendar(cutoffHour: 3)

    enum StatsRange: String, CaseIterable, Identifiable {
        case week = "7일"
        case month = "30일"
        case today = "오늘"
        var id: String { rawValue }
        var days: Int {
            switch self {
                case .today: return 1
                case .week: return 7
                case .month: return 30
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DT.Spacing.lg) {
                rangePicker
                dailyBarCard
                subjectBreakdownCard
                hourlyHeatmapCard
                Spacer(minLength: DT.Spacing.xxl)
            }
            .padding(.horizontal, DT.Spacing.lg)
            .padding(.top, DT.Spacing.lg)
        }
        .background(DT.Color.surface.ignoresSafeArea())
        .navigationTitle("통계")
    }

    private var rangePicker: some View {
        Picker("", selection: $range) {
            ForEach(StatsRange.allCases) { r in
                Text(r.rawValue).tag(r)
            }
        }
        .pickerStyle(.segmented)
    }

    private var dailyBarCard: some View {
        let data = StatsService.weekly(days: range.days, context: context)
        let totalMinutes = data.reduce(0) { $0 + $1.totalSeconds } / 60
        return VStack(alignment: .leading, spacing: DT.Spacing.sm) {
            HStack {
                Text("\(range.rawValue) 누적")
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
                Spacer()
                Text("\(totalMinutes)분")
                    .font(DT.Typography.headline)
                    .foregroundStyle(DT.Color.primary)
                    .monospacedDigit()
            }
            if data.isEmpty {
                Text("아직 데이터가 없어요").font(DT.Typography.body).foregroundStyle(DT.Color.textSecondary)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("일", item.date, unit: .day),
                        y: .value("분", item.totalSeconds / 60)
                    )
                    .foregroundStyle(DT.Color.primary)
                    .cornerRadius(4)
                }
                .frame(height: 180)
            }
        }
        .padding(DT.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: DT.Radius.card).fill(DT.Color.background))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }

    private var subjectBreakdownCard: some View {
        let data = StatsService.weekly(days: range.days, context: context)
        let start = data.first?.plannerDay ?? calendar.plannerDay(for: Date())
        let end = data.last?.plannerDay ?? calendar.plannerDay(for: Date())
        let totals = StatsService.subjectBreakdown(from: start, to: end, context: context)
        return VStack(alignment: .leading, spacing: DT.Spacing.sm) {
            Text("과목별 비중")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
            if totals.isEmpty {
                Text("아직 데이터가 없어요").font(DT.Typography.body).foregroundStyle(DT.Color.textSecondary)
            } else {
                Chart(totals) { item in
                    SectorMark(
                        angle: .value("분", item.totalSeconds / 60),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.5
                    )
                    .foregroundStyle(SwiftUI.Color(hexString: item.colorHex) ?? DT.Color.primary)
                    .annotation(position: .overlay) {
                        Text(item.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: 220)
            }
        }
        .padding(DT.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: DT.Radius.card).fill(DT.Color.background))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }

    private var hourlyHeatmapCard: some View {
        let today = calendar.plannerDay(for: Date())
        let buckets = StatsService.hourlyHeatmap(for: today, context: context)
        let maxSec = max(1, buckets.map { $0.totalSeconds }.max() ?? 1)
        return VStack(alignment: .leading, spacing: DT.Spacing.sm) {
            Text("오늘 시간대")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
            Chart(buckets) { b in
                BarMark(
                    x: .value("시간", b.hour),
                    y: .value("분", b.totalSeconds / 60)
                )
                .foregroundStyle(by: .value("강도", Double(b.totalSeconds) / Double(maxSec)))
            }
            .chartForegroundStyleScale(range: Gradient(colors: [
                DT.Color.primary.opacity(0.2),
                DT.Color.primary,
            ]))
            .chartLegend(.hidden)
            .frame(height: 140)
        }
        .padding(DT.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: DT.Radius.card).fill(DT.Color.background))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }
}
