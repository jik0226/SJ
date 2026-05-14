// PlantWidget — Small widget showing the procedural plant snapshot.
// Reads seed + nutrients from the App Group and re-derives the canvas locally.

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
        .configurationDisplayName("내 식물")
        .description("씨앗에서 자라는 함수형 식물")
        .supportedFamilies([.systemSmall])
    }
}

struct PlantEntry: TimelineEntry {
    let date: Date
    let name: String
    let seed: Int
    let studyMinutes: Int
    let workoutMinutes: Int
}

struct PlantProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlantEntry {
        PlantEntry(date: .now, name: "내 새싹", seed: 12345, studyMinutes: 0, workoutMinutes: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlantEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlantEntry>) -> Void) {
        let entry = currentEntry()
        // Plant only mutates on session end; hourly refresh is plenty.
        let next = Date().addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> PlantEntry {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        return PlantEntry(
            date: .now,
            name: defaults?.string(forKey: "plant.name") ?? "내 새싹",
            seed: defaults?.integer(forKey: "plant.seed") ?? 0,
            studyMinutes: defaults?.integer(forKey: "plant.studyMinutes") ?? 0,
            workoutMinutes: defaults?.integer(forKey: "plant.workoutMinutes") ?? 0
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
                workoutMinutes: entry.workoutMinutes
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
            WidgetPlantCanvas(parameters: parameters)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// Minimal canvas drawer mirroring `PlantCanvasView` in the main app — kept
/// independent so the widget extension doesn't import app-only modules.
private struct WidgetPlantCanvas: View {
    let parameters: PlantParameters

    var body: some View {
        Canvas { context, size in
            let p = parameters
            let baseX = size.width / 2
            let baseY = size.height - 4
            let stemPixelHeight = min(size.height * 0.85, p.stemHeight * 1.4)

            let stemColor = Color(hue: p.stemHue, saturation: 0.55, brightness: 0.55)
            let leafColor = Color(hue: p.leafHue, saturation: 0.65, brightness: 0.70)

            var stem = Path()
            stem.move(to: CGPoint(x: baseX, y: baseY))
            let steps = 40
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let y = baseY - t * stemPixelHeight
                let x = baseX + sin(t * p.stemFrequency * .pi * 2) * p.stemAmplitude * 0.8
                stem.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(
                stem, with: .color(stemColor),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )

            for i in 0..<min(p.leafCount, 12) {
                let t = 0.15 + (Double(i) / Double(max(1, p.leafCount - 1))) * 0.8
                let y = baseY - t * stemPixelHeight
                let x = baseX + sin(t * p.stemFrequency * .pi * 2) * p.stemAmplitude * 0.8
                let side: Double = (i % 2 == 0) ? 1.0 : -1.0
                let angle = side * .pi / 6
                drawLeaf(
                    context: context,
                    at: CGPoint(x: x, y: y),
                    angle: angle,
                    petals: p.leafPetals,
                    size: p.leafSize * 0.7,
                    color: leafColor
                )
            }
        }
    }

    private func drawLeaf(
        context: GraphicsContext, at center: CGPoint, angle: Double,
        petals: Int, size: Double, color: Color
    ) {
        var path = Path()
        let steps = 18
        let n = Double(petals)
        for i in 0...steps {
            let theta = (Double(i) / Double(steps)) * .pi
            let r = size * abs(cos(n * theta))
            let lx = r * cos(theta)
            let ly = r * sin(theta)
            let rx = lx * cos(angle) - ly * sin(angle)
            let ry = lx * sin(angle) + ly * cos(angle)
            let pt = CGPoint(x: center.x + rx, y: center.y - ry)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        context.fill(path, with: .color(color.opacity(0.85)))
    }
}
