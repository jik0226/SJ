// PlantCanvasView — ocean rendering. Renamed conceptually but file path
// kept for git continuity.
//
// Multi-layer sin waves + parametric fish, all from OceanParameters. The
// `phase` value of each wave gets an additional time-based offset so the
// surface gently animates without any image asset.

import SwiftUI
import StudyCore

struct PlantCanvasView: View {
    let parameters: OceanParameters
    /// 0..1 ambient phase to push wave + fish positions.
    var sway: Double = 0

    var body: some View {
        Canvas { context, size in
            drawBackground(context: context, size: size, parameters: parameters)
            drawWaves(context: context, size: size, parameters: parameters, sway: sway)
            drawFish(context: context, size: size, parameters: parameters, sway: sway)
        }
    }

    private func drawBackground(
        context: GraphicsContext, size: CGSize, parameters: OceanParameters
    ) {
        let topColor = Color(hue: parameters.bgHue, saturation: 0.30, brightness: 0.92)
        let bottomColor = Color(hue: parameters.bgHue, saturation: 0.65, brightness: 0.30)
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [topColor, bottomColor]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    private func drawWaves(
        context: GraphicsContext, size: CGSize, parameters: OceanParameters, sway: Double
    ) {
        // Each wave lives in a horizontal band — back waves higher up, front
        // waves lower down. We fill the area beneath each wave with a slightly
        // darker blue so they read as overlapping sheets.
        let bandTop = size.height * 0.35   // surface starts ~35% from top
        let bandBottom = size.height * 0.95

        for wave in parameters.waves {
            let centerY = bandTop + wave.depth * (bandBottom - bandTop)
            let hue = parameters.bgHue
            let saturation = 0.55 + wave.depth * 0.25
            let brightness = 0.75 - wave.depth * 0.30
            let color = Color(hue: hue, saturation: saturation, brightness: brightness)

            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height))
            let steps = 80
            for i in 0...steps {
                let xRatio = Double(i) / Double(steps)
                let x = xRatio * size.width
                let arg = wave.frequency * (xRatio * 10) + wave.phase + sway * 2 * .pi
                let y = centerY + sin(arg) * wave.amplitude
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            // Close to bottom for filled wave area.
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()

            context.fill(path, with: .color(color.opacity(0.65)))
        }
    }

    private func drawFish(
        context: GraphicsContext, size: CGSize, parameters: OceanParameters, sway: Double
    ) {
        for (idx, fish) in parameters.fish.enumerated() {
            let baseX = fish.xRatio * size.width
            // Fish gently swim horizontally based on the sway phase + its index.
            let driftX = sin(sway * 2 * .pi + Double(idx) * 0.7) * 10
            let center = CGPoint(
                x: baseX + (fish.facingRight ? driftX : -driftX),
                y: fish.yRatio * size.height
            )
            let body = Color(hue: fish.bodyHue, saturation: 0.65, brightness: 0.85)
            let radius = fish.sizeRatio * min(size.width, size.height) * 0.45
            drawSingleFish(
                context: context, center: center, radius: radius,
                facingRight: fish.facingRight, color: body
            )
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
        // Parametric ellipse (body).
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

        // Tail: small triangle at the back.
        var tail = Path()
        let tailTip = CGPoint(x: center.x - sign * bodyWidth * 1.6, y: center.y)
        let tailUp = CGPoint(x: center.x - sign * bodyWidth * 0.9, y: center.y - bodyHeight)
        let tailDown = CGPoint(x: center.x - sign * bodyWidth * 0.9, y: center.y + bodyHeight)
        tail.move(to: tailTip)
        tail.addLine(to: tailUp)
        tail.addLine(to: tailDown)
        tail.closeSubpath()
        context.fill(tail, with: .color(color.opacity(0.85)))

        // Eye.
        let eyeCenter = CGPoint(x: center.x + sign * bodyWidth * 0.55, y: center.y - bodyHeight * 0.2)
        let eyeRadius = max(1.5, radius * 0.12)
        context.fill(
            Path(ellipseIn: CGRect(
                x: eyeCenter.x - eyeRadius, y: eyeCenter.y - eyeRadius,
                width: eyeRadius * 2, height: eyeRadius * 2
            )),
            with: .color(.white)
        )
        context.fill(
            Path(ellipseIn: CGRect(
                x: eyeCenter.x - eyeRadius * 0.5, y: eyeCenter.y - eyeRadius * 0.5,
                width: eyeRadius, height: eyeRadius
            )),
            with: .color(.black)
        )
    }
}
