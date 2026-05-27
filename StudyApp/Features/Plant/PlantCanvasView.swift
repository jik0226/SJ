// PlantCanvasView — ocean rendering. Renamed conceptually; file path kept for
// git continuity.
//
// Render order: mood gradient → waves → seabed starfish → bubbles → fish school
//               → mascot creature → sky token.
// Creature/decoration draw helpers live in PlantCanvasView+Creatures.swift.

import SwiftUI
import StudyCore

struct PlantCanvasView: View {
    let parameters: OceanParameters
    /// 0..1 ambient phase to push wave + fish positions.
    var sway: Double = 0

    var body: some View {
        Canvas { context, size in
            drawBackground(context: context, size: size)
            drawWaves(context: context, size: size)
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
        let top = Color(hue: mood.topHue, saturation: 0.38, brightness: 0.90)
        let bottom = Color(hue: mood.bottomHue, saturation: 0.70, brightness: 0.28)
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [top, bottom]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    // MARK: - Waves

    private func drawWaves(context: GraphicsContext, size: CGSize) {
        let bandTop = size.height * 0.35
        let bandBottom = size.height * 0.95
        let baseHue = parameters.mood.topHue
        for wave in parameters.waves {
            let centerY = bandTop + wave.depth * (bandBottom - bandTop)
            let saturation = 0.55 + wave.depth * 0.25
            let brightness = 0.75 - wave.depth * 0.30
            let color = Color(hue: baseHue, saturation: saturation, brightness: brightness)
            var path = Path()
            let steps = 80
            for i in 0...steps {
                let xRatio = Double(i) / Double(steps)
                let x = xRatio * size.width
                let arg = wave.frequency * (xRatio * 10) + wave.phase + sway * 2 * .pi
                let y = centerY + sin(arg) * wave.amplitude
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
            context.fill(path, with: .color(color.opacity(0.65)))
        }
    }

    // MARK: - Seabed starfish

    private func drawSeabed(context: GraphicsContext, size: CGSize) {
        let seabedY = size.height * 0.91
        for mark in parameters.seabed {
            let cx = mark.xRatio * size.width
            let r = mark.sizeRatio * min(size.width, size.height) * 0.6
            drawStarfish(context: context,
                         center: CGPoint(x: cx, y: seabedY - r * 0.4),
                         radius: r, hue: mark.hue)
        }
    }

    // MARK: - Bubbles

    private func drawBubbles(context: GraphicsContext, size: CGSize) {
        for bubble in parameters.bubbles {
            let cx = bubble.xRatio * size.width
            // Bubbles drift upward as sway advances; wrap from top back to bottom.
            let rawY = bubble.yRatio - sway * 0.35
            let cy = (rawY.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * size.height
            let r = bubble.sizeRatio * min(size.width, size.height)
            context.fill(
                Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(0.22))
            )
            context.stroke(
                Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(0.40)),
                lineWidth: max(0.5, r * 0.25)
            )
        }
    }

    // MARK: - Fish school

    private func drawFish(context: GraphicsContext, size: CGSize) {
        for (idx, fish) in parameters.fish.enumerated() {
            let baseX = fish.xRatio * size.width
            let driftX = sin(sway * 2 * .pi + Double(idx) * 0.7) * 10
            let center = CGPoint(
                x: baseX + (fish.facingRight ? driftX : -driftX),
                y: fish.yRatio * size.height
            )
            let body = Color(hue: fish.bodyHue, saturation: 0.65, brightness: 0.85)
            let radius = fish.sizeRatio * min(size.width, size.height) * 0.45
            drawSingleFish(context: context, center: center, radius: radius,
                           facingRight: fish.facingRight, color: body)
        }
    }

    /// Parametric fish: body = horizontal ellipse, tail = triangle cusp.
    private func drawSingleFish(
        context: GraphicsContext, center: CGPoint, radius: Double,
        facingRight: Bool, color: Color
    ) {
        let sign: Double = facingRight ? 1 : -1
        let bodyWidth = radius * 1.6
        let bodyHeight = radius
        var path = Path()
        let steps = 36
        for i in 0...steps {
            let t = Double(i) / Double(steps) * 2 * .pi
            let x = center.x + cos(t) * bodyWidth
            let y = center.y + sin(t) * bodyHeight
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        context.fill(path, with: .color(color))
        var tail = Path()
        tail.move(to: CGPoint(x: center.x - sign * bodyWidth * 1.6, y: center.y))
        tail.addLine(to: CGPoint(x: center.x - sign * bodyWidth * 0.9, y: center.y - bodyHeight))
        tail.addLine(to: CGPoint(x: center.x - sign * bodyWidth * 0.9, y: center.y + bodyHeight))
        tail.closeSubpath()
        context.fill(tail, with: .color(color.opacity(0.85)))
        let eyeCenter = CGPoint(x: center.x + sign * bodyWidth * 0.55, y: center.y - bodyHeight * 0.2)
        let eyeRadius = max(1.5, radius * 0.12)
        context.fill(
            Path(ellipseIn: CGRect(x: eyeCenter.x - eyeRadius, y: eyeCenter.y - eyeRadius,
                                   width: eyeRadius * 2, height: eyeRadius * 2)),
            with: .color(.white)
        )
        context.fill(
            Path(ellipseIn: CGRect(x: eyeCenter.x - eyeRadius * 0.5, y: eyeCenter.y - eyeRadius * 0.5,
                                   width: eyeRadius, height: eyeRadius)),
            with: .color(.black)
        )
    }

    // MARK: - Mascot

    private func drawMascotLayer(context: GraphicsContext, size: CGSize) {
        let p = parameters.mascotPlacement
        let center = CGPoint(x: p.xRatio * size.width, y: p.yRatio * size.height)
        let radius = p.sizeRatio * min(size.width, size.height)
        drawMascot(context: context, center: center, radius: radius,
                   mascot: parameters.mascot, accentHue: parameters.mood.accentHue)
    }
}
