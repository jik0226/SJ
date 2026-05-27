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
            drawBackground(ctx: ctx, size: size, mood: p.mood)
            drawWaves(ctx: ctx, size: size, waves: p.waves, mood: p.mood)
            drawFish(ctx: ctx, size: size, fish: p.fish)
            drawMascot(ctx: ctx, size: size, p: p)
        }
    }

    // MARK: - Background uses mood palette

    private func drawBackground(ctx: GraphicsContext, size: CGSize, mood: OceanMood) {
        let top = Color(hue: mood.topHue, saturation: 0.38, brightness: 0.90)
        let bottom = Color(hue: mood.bottomHue, saturation: 0.70, brightness: 0.28)
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

    private func drawWaves(ctx: GraphicsContext, size: CGSize, waves: [WaveLayer], mood: OceanMood) {
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
            let layerColor = Color(hue: mood.topHue, saturation: 0.55, brightness: 0.80)
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

    /// Simplified mascot: a single rounded shape with two big eyes so the
    /// widget is recognizably different per mood without complex Path math.
    private func drawMascot(ctx: GraphicsContext, size: CGSize, p: PlantParameters) {
        let mp = p.mascotPlacement
        let cx = mp.xRatio * size.width
        let cy = mp.yRatio * size.height
        let r = mp.sizeRatio * min(size.width, size.height) * 0.85
        let bodyColor = Color(hue: p.mood.accentHue, saturation: 0.55, brightness: 0.78)
        // Body.
        ctx.fill(
            Path(ellipseIn: CGRect(x: cx - r, y: cy - r * 0.85, width: r * 2, height: r * 1.7)),
            with: .color(bodyColor)
        )
        // Two big eyes.
        for side in [-0.32, 0.32] {
            let ex = cx + side * r
            let ey = cy - r * 0.20
            let er = r * 0.26
            ctx.fill(Path(ellipseIn: CGRect(x: ex - er, y: ey - er, width: er * 2, height: er * 2)),
                     with: .color(.white))
            let pr = er * 0.55
            ctx.fill(Path(ellipseIn: CGRect(x: ex - pr * 0.6, y: ey - pr, width: pr * 1.2, height: pr * 2)),
                     with: .color(.black))
        }
    }
}
