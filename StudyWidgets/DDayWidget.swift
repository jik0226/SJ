// DDayWidget — Small and Medium home-screen widget showing the pinned D-Day.
// Reads from the shared App Group container; a placeholder fires if nothing
// is pinned yet so the user can still preview the widget.

import WidgetKit
import SwiftUI

struct DDayWidget: Widget {
    let kind: String = "DDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DDayProvider()) { entry in
            DDayWidgetView(entry: entry)
                .containerBackground(WT.Color.surface, for: .widget)
        }
        .configurationDisplayName("디데이")
        .description("핀 고정한 디데이까지 남은 일수")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DDayEntry: TimelineEntry {
    let date: Date
    let title: String
    let emoji: String
    let targetDate: Date
}

struct DDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DDayEntry {
        DDayEntry(date: .now, title: "수능", emoji: "📚",
                  targetDate: Calendar.current.date(byAdding: .day, value: 189, to: .now) ?? .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (DDayEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DDayEntry>) -> Void) {
        let entry = readShared() ?? placeholder(in: context)
        // Refresh at the next midnight — D-Day only changes daily.
        let nextRefresh = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 0, second: 1),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func readShared() -> DDayEntry? {
        guard let defaults = UserDefaults(suiteName: AppGroup.identifier),
              let title = defaults.string(forKey: "dday.title"),
              let target = defaults.object(forKey: "dday.targetDate") as? Date,
              let emoji = defaults.string(forKey: "dday.emoji") else {
            return nil
        }
        return DDayEntry(date: .now, title: title, emoji: emoji, targetDate: target)
    }
}

struct DDayWidgetView: View {
    let entry: DDayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.emoji).font(.system(size: 24))
            Text(entry.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WT.Color.textPrimary)
                .lineLimit(1)
            Text(label)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(WT.Color.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }

    private var label: String {
        let cal = Calendar.current
        let start = cal.startOfDay(for: entry.date)
        let target = cal.startOfDay(for: entry.targetDate)
        let days = cal.dateComponents([.day], from: start, to: target).day ?? 0
        if days > 0 { return "D-\(days)" }
        if days == 0 { return "D-DAY" }
        return "D+\(-days)"
    }
}
