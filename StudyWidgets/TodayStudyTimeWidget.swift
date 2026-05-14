// TodayStudyTimeWidget — Small widget showing today's accumulated study time.
// Reads the precomputed seconds from the App Group; updates every 15 min.

import WidgetKit
import SwiftUI

struct TodayStudyTimeWidget: Widget {
    let kind: String = "TodayStudyTimeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayStudyProvider()) { entry in
            TodayStudyView(entry: entry)
                .containerBackground(WT.Color.surface, for: .widget)
        }
        .configurationDisplayName("오늘 순공시간")
        .description("오늘 누적 순공시간")
        .supportedFamilies([.systemSmall])
    }
}

struct TodayStudyEntry: TimelineEntry {
    let date: Date
    let seconds: Int
}

struct TodayStudyProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayStudyEntry {
        TodayStudyEntry(date: .now, seconds: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayStudyEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayStudyEntry>) -> Void) {
        let entry = currentEntry()
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> TodayStudyEntry {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        let seconds = defaults?.integer(forKey: "today.studySeconds") ?? 0
        return TodayStudyEntry(date: .now, seconds: seconds)
    }
}

struct TodayStudyView: View {
    let entry: TodayStudyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "timer")
                .font(.system(size: 22))
                .foregroundStyle(WT.Color.primary)
            Text("오늘 순공")
                .font(.caption)
                .foregroundStyle(WT.Color.textSecondary)
            Text(formatted)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(WT.Color.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }

    private var formatted: String {
        let h = entry.seconds / 3600
        let m = (entry.seconds % 3600) / 60
        if h > 0 { return "\(h)시간 \(m)분" }
        return "\(m)분"
    }
}
