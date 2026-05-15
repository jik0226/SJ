// PlantWidget — Small widget rendering the ocean snapshot (waves + fish).
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
}

struct PlantProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlantEntry {
        PlantEntry(date: .now, name: "내 바다", seed: 12345, studyMinutes: 0, workoutMinutes: 0)
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
            WidgetOceanCanvas(parameters: parameters)
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

/// Minimal canvas mirroring the main app's PlantCanvasView. Kept independent so
/// the widget extension doesn't import any app-only modules.
private struct WidgetOceanCanvas: View {
    let parameters: PlantParameters

    var body: some View {
        Canvas { ctx, size in
            let p = parameters
            drawBackground(ctx: ctx, size: size, hue: p.bgHue)
            drawWaves(ctx: ctx, size: size, waves: p.waves)
            drawFish(ctx: ctx, size: size, fish: p.fish)
        }
    }

    private func drawBackground(ctx: GraphicsContext, size: CGSize, hue: Double) {
        let top = Color(hue: hue, saturation: 0.55, brightness: 0.45)
        let bottom = Color(hue: hue, saturation: 0.45, brightness: 0.75)
        let rect = CGRect(origin: .zero, size: size)
        ctx.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [top, bottom]),
                startPoint: CGPoint(x: rect.midX, y: 0),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )
    }

    private func drawWaves(ctx: GraphicsContext, size: CGSize, waves: [WaveLayer]) {
        guard !waves.isEmpty else { return }
        let count = waves.count
        for (i, wave) in waves.enumerated() {
            let depthY = size.height * (0.30 + 0.45 * (Double(i) / Double(max(1, count - 1))))
            var path = Path()
            let steps = 30
            path.move(to: CGPoint(x: 0, y: depthY))
            for s in 0...steps {
                let t = Double(s) / Double(steps)
                let x = t * size.width
                let y = depthY + sin(wave.frequency * t * 6.28 + wave.phase) * wave.amplitude
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
            let alpha = 0.35 + wave.depth * 0.55
            let layerColor = Color(hue: parameters.bgHue, saturation: 0.55, brightness: 0.80)
            ctx.fill(path, with: .color(layerColor.opacity(alpha)))
        }
    }

    private func drawFish(ctx: GraphicsContext, size: CGSize, fish: [FishMark]) {
        for f in fish.prefix(6) {
            let cx = f.xRatio * size.width
            let cy = f.yRatio * size.height
            let w = f.sizeRatio * size.width * 1.2
            let h = w * 0.55
            let body = Path(ellipseIn: CGRect(x: cx - w/2, y: cy - h/2, width: w, height: h))
            let color = Color(hue: f.bodyHue, saturation: 0.7, brightness: 0.9)
            ctx.fill(body, with: .color(color))
            var tail = Path()
            let dir: CGFloat = f.facingRight ? -1 : 1
            tail.move(to: CGPoint(x: cx + dir * w/2, y: cy))
            tail.addLine(to: CGPoint(x: cx + dir * (w/2 + w*0.4), y: cy - h*0.5))
            tail.addLine(to: CGPoint(x: cx + dir * (w/2 + w*0.4), y: cy + h*0.5))
            tail.closeSubpath()
            ctx.fill(tail, with: .color(color))
        }
    }
}
