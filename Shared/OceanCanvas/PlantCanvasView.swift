// PlantCanvasView — ocean rendering. Renamed conceptually; file path kept for
// git continuity.
//
// Kawaii art direction: milky pastels, soft light rays, foam-highlighted
// waves, a pale sand floor, and creatures with big sparkly eyes + blush.
// Render order: gradient → light rays → bokeh → waves → sand → seabed
//               → bubbles → fish → mascot → sky token.
// Mascots live in +Creatures.swift; fish/starfish/sky in +Decor.swift.

import SwiftUI
import StudyCore

struct PlantCanvasView: View {
    let parameters: OceanParameters
    /// 0..1 ambient phase to push wave + fish positions.
    var sway: Double = 0

    var body: some View {
        Canvas { context, size in
            drawBackground(context: context, size: size)
            drawLightRays(context: context, size: size)
            drawBokeh(context: context, size: size)
            drawWaves(context: context, size: size)
            drawSand(context: context, size: size)
            drawMilestones(context: context, size: size)
            drawSeabed(context: context, size: size)
            drawBubbles(context: context, size: size)
            drawFish(context: context, size: size)
            drawMascotLayer(context: context, size: size)
            drawSkyToken(context: context, size: size, token: parameters.skyToken, mood: parameters.mood)
        }
    }

    // MARK: - Background

    private func drawBackground(context: GraphicsContext, size: CGSize) {
        let mood = parameters.mood
        // Milky three-stop gradient — the old two-stop went nearly black at
        // the bottom, which read gloomy rather than dreamy.
        let top = Color(hue: mood.topHue, saturation: 0.26, brightness: 0.97)
        let mid = Color(hue: mood.topHue, saturation: 0.42, brightness: 0.82)
        let bottom = Color(hue: mood.bottomHue, saturation: 0.55, brightness: 0.52)
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: top, location: 0),
                    .init(color: mid, location: 0.45),
                    .init(color: bottom, location: 1),
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    /// Soft god-rays from the surface — three translucent wedges whose
    /// placement comes from the seed so every ocean is lit differently.
    private func drawLightRays(context: GraphicsContext, size: CGSize) {
        let seed = parameters.seed
        for i in 0..<3 {
            let jitter = Double((seed >> (i * 8)) % 100) / 100.0
            let topX = size.width * (0.15 + 0.7 * jitter)
            let slant = size.width * (0.12 + 0.10 * Double(i))
            let halfW = size.width * (0.045 + 0.02 * jitter)
            var ray = Path()
            ray.move(to: CGPoint(x: topX - halfW, y: -4))
            ray.addLine(to: CGPoint(x: topX + halfW, y: -4))
            ray.addLine(to: CGPoint(x: topX + slant + halfW * 2.4, y: size.height * 0.78))
            ray.addLine(to: CGPoint(x: topX + slant - halfW * 2.4, y: size.height * 0.78))
            ray.closeSubpath()
            context.fill(ray, with: .linearGradient(
                Gradient(colors: [.white.opacity(0.16), .white.opacity(0)]),
                startPoint: CGPoint(x: topX, y: 0),
                endPoint: CGPoint(x: topX + slant, y: size.height * 0.7)
            ))
        }
    }

    /// Floating light specks (bokeh) — tiny, dreamy, deterministic by seed.
    private func drawBokeh(context: GraphicsContext, size: CGSize) {
        let seed = parameters.seed
        let golden = 0.6180339887
        for i in 0..<7 {
            let jx = (Double(i) * golden + Double((seed >> 16) % 97) / 97.0)
                .truncatingRemainder(dividingBy: 1)
            let jy = (Double(i) * golden * 1.7 + Double((seed >> 24) % 89) / 89.0)
                .truncatingRemainder(dividingBy: 1)
            let r = 1.2 + Double((seed >> (i * 4)) % 5) * 0.5
            context.fill(
                Path(ellipseIn: CGRect(x: jx * size.width - r,
                                       y: (0.15 + jy * 0.7) * size.height - r,
                                       width: r * 2, height: r * 2)),
                with: .color(.white.opacity(0.20))
            )
        }
    }

    // MARK: - Waves

    private func drawWaves(context: GraphicsContext, size: CGSize) {
        let bandTop = size.height * 0.35
        let bandBottom = size.height * 0.95
        let baseHue = parameters.mood.topHue
        for wave in parameters.waves {
            let centerY = bandTop + wave.depth * (bandBottom - bandTop)
            // Pastel bands: deeper = a bit more saturated, never murky.
            let saturation = 0.34 + wave.depth * 0.22
            let brightness = 0.92 - wave.depth * 0.26
            let color = Color(hue: baseHue, saturation: saturation, brightness: brightness)
            var crest = Path()
            let steps = 80
            for i in 0...steps {
                let xRatio = Double(i) / Double(steps)
                let x = xRatio * size.width
                let arg = wave.frequency * (xRatio * 10) + wave.phase + sway * 2 * .pi
                let y = centerY + sin(arg) * wave.amplitude
                if i == 0 { crest.move(to: CGPoint(x: x, y: y)) }
                else { crest.addLine(to: CGPoint(x: x, y: y)) }
            }
            var band = crest
            band.addLine(to: CGPoint(x: size.width, y: size.height))
            band.addLine(to: CGPoint(x: 0, y: size.height))
            band.closeSubpath()
            context.fill(band, with: .color(color.opacity(0.55)))
            // Foam highlight along the crest — the line that makes each wave
            // read as a soft, drawn shape instead of a color band.
            context.stroke(crest, with: .color(.white.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
    }

    // MARK: - Sand floor

    private func drawSand(context: GraphicsContext, size: CGSize) {
        let sand = Color(hue: 0.11, saturation: 0.22, brightness: 0.95)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height * 0.955))
        path.addQuadCurve(
            to: CGPoint(x: size.width, y: size.height * 0.955),
            control: CGPoint(x: size.width * 0.5, y: size.height * 0.915)
        )
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        context.fill(path, with: .color(sand.opacity(0.9)))
    }

    // MARK: - Seabed starfish

    private func drawSeabed(context: GraphicsContext, size: CGSize) {
        let seabedY = size.height * 0.94
        for mark in parameters.seabed {
            let cx = mark.xRatio * size.width
            let r = mark.sizeRatio * min(size.width, size.height) * 0.6
            drawStarfish(context: context,
                         center: CGPoint(x: cx, y: seabedY - r * 0.5),
                         radius: r, hue: mark.hue)
        }
    }

    // MARK: - Bubbles

    private func drawBubbles(context: GraphicsContext, size: CGSize) {
        for bubble in parameters.bubbles {
            let cx = bubble.xRatio * size.width
            let rawY = bubble.yRatio - sway * 0.35
            let cy = (rawY.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * size.height
            let r = bubble.sizeRatio * min(size.width, size.height)
            let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.16)))
            context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.45)),
                           lineWidth: max(0.6, r * 0.16))
            // Crescent highlight — the classic "shiny bubble" wink.
            let hr = r * 0.32
            context.fill(
                Path(ellipseIn: CGRect(x: cx - r * 0.45 - hr, y: cy - r * 0.45 - hr,
                                       width: hr * 2, height: hr * 2)),
                with: .color(.white.opacity(0.65))
            )
        }
    }

    // MARK: - Fish + mascot dispatch

    private func drawFish(context: GraphicsContext, size: CGSize) {
        for (idx, fish) in parameters.fish.enumerated() {
            let baseX = fish.xRatio * size.width
            let driftX = sin(sway * 2 * .pi + Double(idx) * 0.7) * 10
            let center = CGPoint(
                x: baseX + (fish.facingRight ? driftX : -driftX),
                y: fish.yRatio * size.height
            )
            // 0.62 multiplier so the face details (eye/smile/blush) stay
            // legible even on the small home-card canvas.
            let radius = fish.sizeRatio * min(size.width, size.height) * 0.62
            drawKawaiiFish(context: context, center: center, radius: radius,
                           facingRight: fish.facingRight, hue: fish.bodyHue,
                           species: parameters.dna.fishSpecies,
                           pattern: parameters.dna.fishPattern)
        }
    }

    private func drawMascotLayer(context: GraphicsContext, size: CGSize) {
        let p = parameters.mascotPlacement
        let center = CGPoint(x: p.xRatio * size.width, y: p.yRatio * size.height)
        let radius = p.sizeRatio * min(size.width, size.height)
        // DNA tint: the mood accent rotated by the user's permanent variant,
        // so two study-heavy users get differently colored turtles.
        let tintedHue = (parameters.mood.accentHue + parameters.dna.mascotHueShift)
            .truncatingRemainder(dividingBy: 1)
        drawMascot(context: context, center: center, radius: radius,
                   mascot: parameters.mascot, accentHue: tintedHue)
    }

    // MARK: - Milestones

    private func drawMilestones(context: GraphicsContext, size: CGSize) {
        let m = min(size.width, size.height)
        let floorY = size.height * 0.945
        for mark in parameters.milestones {
            let x = mark.xRatio * size.width
            switch mark.kind {
            case .coral:
                drawCoral(context: context, base: CGPoint(x: x, y: floorY), scale: m * 0.10)
            case .seaweed:
                drawSeaweed(context: context, base: CGPoint(x: x, y: floorY), scale: m * 0.15, sway: sway)
            case .shipwreck:
                drawShipwreck(context: context, base: CGPoint(x: x, y: floorY), scale: m * 0.11)
            case .lighthouse:
                drawLighthouse(context: context, base: CGPoint(x: x, y: floorY), scale: m * 0.16)
            case .whale:
                drawWhale(context: context,
                          center: CGPoint(x: x, y: size.height * 0.30),
                          radius: m * 0.11, sway: sway)
            }
        }
    }
}
