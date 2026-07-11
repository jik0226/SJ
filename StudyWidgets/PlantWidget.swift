// PlantWidget — Small widget rendering the ocean snapshot (waves + mascot).
// Reads seed + nutrients from the App Group and re-derives the canvas locally.
// Independent renderer so the widget extension doesn't pull in app-only modules.

import WidgetKit
import SwiftUI
import StudyCore

struct PlantWidget: Widget {
    let kind: String = "PlantWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlantProvider()) { entry in
            PlantWidgetView(entry: entry)
                .containerBackground(WT.Color.surface, for: .widget)
        }
        .configurationDisplayName("내 바다")
        .description("공부·운동 시간이 쌓일수록 파도와 물고기가 늘어납니다")
        .supportedFamilies([.systemSmall])
    }
}

struct PlantEntry: TimelineEntry {
    let date: Date
    let name: String
    let seed: Int
    let studyMinutes: Int
    let workoutMinutes: Int
    /// Activity-order hash — must match the app body's so the widget draws the
    /// same ocean. Stored as a string in the App Group (UInt64 range).
    let sequenceHash: UInt64
}

struct PlantProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlantEntry {
        PlantEntry(date: .now, name: "내 바다", seed: 12345, studyMinutes: 0, workoutMinutes: 0, sequenceHash: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlantEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlantEntry>) -> Void) {
        let entry = currentEntry()
        // Ocean only mutates on session end; hourly refresh is plenty.
        let next = Date().addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> PlantEntry {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        return PlantEntry(
            date: .now,
            name: defaults?.string(forKey: "plant.name") ?? "내 바다",
            seed: defaults?.integer(forKey: "plant.seed") ?? 0,
            studyMinutes: defaults?.integer(forKey: "plant.studyMinutes") ?? 0,
            workoutMinutes: defaults?.integer(forKey: "plant.workoutMinutes") ?? 0,
            sequenceHash: UInt64(defaults?.string(forKey: "plant.sequenceHash") ?? "") ?? 0
        )
    }
}

struct PlantWidgetView: View {
    let entry: PlantEntry

    private var parameters: PlantParameters {
        PlantFormula.parameters(
            seed: UInt64(bitPattern: Int64(entry.seed)),
            nutrients: PlantNutrients(
                studyMinutes: entry.studyMinutes,
                workoutMinutes: entry.workoutMinutes,
                sequenceHash: entry.sequenceHash
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WT.Color.textPrimary)
                    .lineLimit(1)
                Spacer()
            }
            // The real ocean renderer (shared with the app + share card via
            // Shared/OceanCanvas) so the widget shows the exact same sea —
            // kawaii creatures, DNA traits, milestones and all.
            PlantCanvasView(parameters: parameters, sway: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            HStack(spacing: 4) {
                Text("📚\(entry.studyMinutes)")
                Spacer()
                Text("🏃\(entry.workoutMinutes)")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(WT.Color.textSecondary)
        }
        .padding(10)
    }
}
