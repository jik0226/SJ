// PlantCanvasView — draws the plant from PlantParameters using SwiftUI Canvas.
// Pure math: stem is a sin wave, leaves are rose curves r = a·cos(n·θ),
// flower is a 6-petal rose. No images.

import SwiftUI
import StudyCore

struct PlantCanvasView: View {
    let parameters: PlantParameters
    /// Optional 0..1 ambient phase used to gently sway the plant on screen.
    var sway: Double = 0

    var body: some View {
        Canvas { context, size in
            let p = parameters
            let baseX = size.width / 2
            let baseY = size.height - 16
            // Normalise stemHeight (20..~150) into canvas height budget.
            let stemPixelHeight = min(size.height * 0.85, p.stemHeight * 2.0)

            // Resolve hues to Colors once.
            let stemColor = Color(hue: p.stemHue, saturation: 0.55, brightness: 0.55)
            let leafColor = Color(hue: p.leafHue, saturation: 0.65, brightness: 0.70)

            drawStem(
                context: context,
                baseX: baseX, baseY: baseY,
                height: stemPixelHeight,
                amplitude: p.stemAmplitude,
                frequency: p.stemFrequency,
                color: stemColor,
                sway: sway
            )
            drawLeaves(
                context: context,
                baseX: baseX, baseY: baseY,
                stemHeight: stemPixelHeight,
                p: p,
                color: leafColor,
                sway: sway
            )
            if p.hasFlower {
                let pos = stemPoint(
                    baseX: baseX, baseY: baseY,
                    height: stemPixelHeight, t: 1.0,
                    amplitude: p.stemAmplitude,
                    frequency: p.stemFrequency,
                    sway: sway
                )
                drawFlower(
                    context: context,
                    at: pos,
                    size: max(p.leafSize, 8) * 1.4,
                    color: Color(hue: (p.leafHue + 0.55).truncatingRemainder(dividingBy: 1),
                                 saturation: 0.7, brightness: 0.9)
                )
            }
        }
    }

    private func stemPoint(
        baseX: Double, baseY: Double, height: Double, t: Double,
        amplitude: Double, frequency: Double, sway: Double
    ) -> CGPoint {
        let y = baseY - t * height
        let phase = sway * 2 * .pi
        let x = baseX + sin(t * frequency * .pi * 2 + phase) * amplitude
        return CGPoint(x: x, y: y)
    }

    private func drawStem(
        context: GraphicsContext,
        baseX: Double, baseY: Double, height: Double,
        amplitude: Double, frequency: Double,
        color: Color, sway: Double
    ) {
        var path = Path()
        path.move(to: CGPoint(x: baseX, y: baseY))
        let steps = 60
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let pt = stemPoint(
                baseX: baseX, baseY: baseY, height: height, t: t,
                amplitude: amplitude, frequency: frequency, sway: sway
            )
            path.addLine(to: pt)
        }
        context.stroke(
            path, with: .color(color),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawLeaves(
        context: GraphicsContext,
        baseX: Double, baseY: Double, stemHeight: Double,
        p: PlantParameters, color: Color, sway: Double
    ) {
        guard p.leafCount > 0 else { return }
        for i in 0..<p.leafCount {
            // Place leaves along the upper 80% of the stem, alternating sides.
            let t = 0.15 + (Double(i) / Double(max(1, p.leafCount - 1))) * 0.8
            let pt = stemPoint(
                baseX: baseX, baseY: baseY, height: stemHeight, t: t,
                amplitude: p.stemAmplitude, frequency: p.stemFrequency, sway: sway
            )
            let side: Double = (i % 2 == 0) ? 1.0 : -1.0
            let seedJitter = Double((p.seed &+ UInt64(i)) % 7) * 0.05  // 0..0.3
            let angle = side * (.pi / 6 + seedJitter)
            drawRoseLeaf(
                context: context,
                at: pt, angle: angle,
                petals: p.leafPetals,
                size: p.leafSize,
                color: color
            )
        }
    }

    /// Rose curve r = a·cos(n·θ) drawn as a closed leaf, oriented along `angle`.
    private func drawRoseLeaf(
        context: GraphicsContext,
        at center: CGPoint, angle: Double,
        petals: Int, size: Double,
        color: Color
    ) {
        var path = Path()
        let steps = 36
        let n = Double(petals)
        for i in 0...steps {
            let theta = (Double(i) / Double(steps)) * .pi   // half rotation enough for one petal
            let r = size * abs(cos(n * theta))
            let lx = r * cos(theta)
            let ly = r * sin(theta)
            // Rotate by `angle` then translate.
            let rx = lx * cos(angle) - ly * sin(angle)
            let ry = lx * sin(angle) + ly * cos(angle)
            let pt = CGPoint(x: center.x + rx, y: center.y - ry)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        context.fill(path, with: .color(color.opacity(0.85)))
        context.stroke(path, with: .color(color), lineWidth: 0.6)
    }

    private func drawFlower(
        context: GraphicsContext,
        at center: CGPoint, size: Double, color: Color
    ) {
        var path = Path()
        let steps = 80
        let n: Double = 3  // 6-petaled rose
        for i in 0...steps {
            let theta = (Double(i) / Double(steps)) * 2 * .pi
            let r = size * cos(n * theta)
            let pt = CGPoint(
                x: center.x + r * cos(theta),
                y: center.y - r * sin(theta)
            )
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        context.fill(path, with: .color(color.opacity(0.9)))
    }
}
