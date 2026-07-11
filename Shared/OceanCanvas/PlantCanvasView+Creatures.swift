// PlantCanvasView+Creatures — kawaii mascot creatures (turtle/octopus/crab)
// plus the shared face kit (sparkly eyes, smiles, blush). Pure draw helpers.
//
// Kawaii rules applied here: pastel bodies (high brightness, gentle
// saturation), oversized eyes with a white sparkle, a small open smile, and
// pink blush dots. Every mascot faces the viewer for maximum charm.

import SwiftUI
import StudyCore

extension PlantCanvasView {

    // MARK: - Mascot dispatch

    func drawMascot(
        context: GraphicsContext, center: CGPoint, radius: Double, mascot: OceanMascot,
        accentHue: Double
    ) {
        switch mascot {
        case .turtle:   drawTurtle(context: context, center: center, radius: radius, accentHue: accentHue)
        case .octopus:  drawOctopus(context: context, center: center, radius: radius, accentHue: accentHue)
        case .crab:     drawCrab(context: context, center: center, radius: radius, accentHue: accentHue)
        }
    }

    // MARK: - Turtle (study-dominant)

    func drawTurtle(
        context: GraphicsContext, center: CGPoint, radius: Double, accentHue: Double
    ) {
        let shell = Color(hue: accentHue, saturation: 0.40, brightness: 0.78)
        let shellRim = Color(hue: accentHue, saturation: 0.28, brightness: 0.90)
        let pattern = Color(hue: accentHue, saturation: 0.45, brightness: 0.62)
        let skin = Color(hue: 0.24, saturation: 0.28, brightness: 0.90)  // soft mint skin

        // 4 stubby flippers behind the shell.
        let flipperOffsets: [(Double, Double)] = [(-0.85, -0.40), (0.85, -0.40),
                                                   (-0.80, 0.45),  (0.80, 0.45)]
        for (dx, dy) in flipperOffsets {
            let fx = center.x + dx * radius
            let fy = center.y + dy * radius
            context.fill(
                Path(ellipseIn: CGRect(x: fx - radius * 0.30, y: fy - radius * 0.22,
                                       width: radius * 0.60, height: radius * 0.44)),
                with: .color(skin)
            )
        }

        // Head above the shell (front-facing cutie, not a side profile).
        let headR = radius * 0.46
        let headC = CGPoint(x: center.x, y: center.y - radius * 0.88)
        context.fill(
            Path(ellipseIn: CGRect(x: headC.x - headR, y: headC.y - headR,
                                   width: headR * 2, height: headR * 2)),
            with: .color(skin)
        )
        drawFace(context: context, center: headC, radius: headR, eyeSpread: 0.48)

        // Shell — a proper dome (flat bottom, round top) with a lighter rim.
        let shellW = radius * 1.25
        let shellH = radius * 1.05
        let bottomY = center.y + shellH * 0.62
        func dome(_ w: Double, _ h: Double) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: center.x - w, y: bottomY))
            p.addQuadCurve(to: CGPoint(x: center.x + w, y: bottomY),
                           control: CGPoint(x: center.x, y: bottomY - h * 2.1))
            p.addQuadCurve(to: CGPoint(x: center.x - w, y: bottomY),
                           control: CGPoint(x: center.x, y: bottomY + h * 0.35))
            p.closeSubpath()
            return p
        }
        context.fill(dome(shellW, shellH), with: .color(shellRim))
        context.fill(dome(shellW * 0.86, shellH * 0.84), with: .color(shell))
        // Simple scute pattern — three soft dots on the dome.
        for i in -1...1 {
            let px = center.x + Double(i) * radius * 0.42
            let pr = radius * 0.13
            context.fill(
                Path(ellipseIn: CGRect(x: px - pr, y: center.y - radius * 0.02 - pr,
                                       width: pr * 2, height: pr * 2)),
                with: .color(pattern.opacity(0.45))
            )
        }
        // Shell sheen — small white highlight upper-left.
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - shellW * 0.55, y: center.y - shellH * 0.75,
                                   width: shellW * 0.5, height: shellH * 0.3)),
            with: .color(.white.opacity(0.30))
        )
    }

    // MARK: - Octopus (balanced)

    func drawOctopus(
        context: GraphicsContext, center: CGPoint, radius: Double, accentHue: Double
    ) {
        let body = Color(hue: accentHue, saturation: 0.40, brightness: 0.90)
        let deep = Color(hue: accentHue, saturation: 0.48, brightness: 0.78)

        // 5 rounded tentacle curls under the head.
        for i in 0..<5 {
            let t = Double(i) / 4.0 - 0.5           // -0.5 .. 0.5
            let baseX = center.x + t * radius * 1.5
            let baseY = center.y + radius * 0.55
            let tipX = baseX + t * radius * 0.8
            let tipY = baseY + radius * 0.85
            var arm = Path()
            arm.move(to: CGPoint(x: baseX, y: baseY))
            arm.addQuadCurve(
                to: CGPoint(x: tipX, y: tipY),
                control: CGPoint(x: baseX + t * radius * 1.2, y: baseY + radius * 0.5)
            )
            context.stroke(arm, with: .color(deep),
                           style: StrokeStyle(lineWidth: radius * 0.30, lineCap: .round))
        }

        // Big round head.
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius * 1.05, y: center.y - radius * 1.1,
                                   width: radius * 2.1, height: radius * 1.9)),
            with: .color(body)
        )
        // Head highlight — soft white sheen top-left.
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius * 0.75, y: center.y - radius * 0.95,
                                   width: radius * 0.7, height: radius * 0.45)),
            with: .color(.white.opacity(0.30))
        )
        drawFace(context: context, center: CGPoint(x: center.x, y: center.y - radius * 0.15),
                 radius: radius * 0.85, eyeSpread: 0.42)
    }

    // MARK: - Crab (active-dominant)

    func drawCrab(
        context: GraphicsContext, center: CGPoint, radius: Double, accentHue: Double
    ) {
        let body = Color(hue: accentHue, saturation: 0.52, brightness: 0.92)
        let deep = Color(hue: accentHue, saturation: 0.60, brightness: 0.80)

        // 3 little legs per side.
        for side in [-1.0, 1.0] {
            for j in 0..<3 {
                let legY = center.y + Double(j - 1) * radius * 0.28
                var leg = Path()
                leg.move(to: CGPoint(x: center.x + side * radius * 0.75, y: legY))
                leg.addQuadCurve(
                    to: CGPoint(x: center.x + side * radius * 1.45, y: legY + radius * 0.35),
                    control: CGPoint(x: center.x + side * radius * 1.25, y: legY)
                )
                context.stroke(leg, with: .color(deep.opacity(0.85)),
                               style: StrokeStyle(lineWidth: radius * 0.13, lineCap: .round))
            }
        }

        // Mitten claws — arm + filled circle with a tiny notch. Way cuter
        // than the old stick pincers.
        for side in [-1.0, 1.0] {
            let clawC = CGPoint(x: center.x + side * radius * 1.45, y: center.y - radius * 0.75)
            var arm = Path()
            arm.move(to: CGPoint(x: center.x + side * radius * 0.7, y: center.y - radius * 0.3))
            arm.addQuadCurve(to: clawC,
                             control: CGPoint(x: center.x + side * radius * 1.4, y: center.y - radius * 0.2))
            context.stroke(arm, with: .color(deep),
                           style: StrokeStyle(lineWidth: radius * 0.20, lineCap: .round))
            let cr = radius * 0.34
            context.fill(
                Path(ellipseIn: CGRect(x: clawC.x - cr, y: clawC.y - cr, width: cr * 2, height: cr * 2)),
                with: .color(body)
            )
            // Notch wedge cut into the claw.
            var notch = Path()
            notch.move(to: CGPoint(x: clawC.x + side * cr * 0.2, y: clawC.y - cr * 1.05))
            notch.addLine(to: CGPoint(x: clawC.x + side * cr * 0.55, y: clawC.y - cr * 0.15))
            notch.addLine(to: CGPoint(x: clawC.x - side * cr * 0.3, y: clawC.y - cr * 0.55))
            notch.closeSubpath()
            context.fill(notch, with: .color(deep.opacity(0.5)))
        }

        // Round body + face.
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.78,
                                   width: radius * 2, height: radius * 1.56)),
            with: .color(body)
        )
        // Eye stalks.
        for side in [-1.0, 1.0] {
            var stalk = Path()
            stalk.move(to: CGPoint(x: center.x + side * radius * 0.4, y: center.y - radius * 0.6))
            stalk.addLine(to: CGPoint(x: center.x + side * radius * 0.4, y: center.y - radius * 1.0))
            context.stroke(stalk, with: .color(deep),
                           style: StrokeStyle(lineWidth: radius * 0.11, lineCap: .round))
            drawSparkleEye(context: context,
                           center: CGPoint(x: center.x + side * radius * 0.4, y: center.y - radius * 1.05),
                           radius: radius * 0.20)
        }
        drawSmile(context: context, center: CGPoint(x: center.x, y: center.y - radius * 0.05),
                  radius: radius * 0.22)
        drawBlush(context: context, center: CGPoint(x: center.x, y: center.y + radius * 0.02),
                  spread: radius * 0.62, radius: radius * 0.14)
    }

    // MARK: - Face kit (shared)

    /// Two sparkly eyes + smile + blush arranged on a circular face.
    func drawFace(context: GraphicsContext, center: CGPoint, radius: Double, eyeSpread: Double) {
        let eyeY = center.y - radius * 0.10
        for side in [-1.0, 1.0] {
            drawSparkleEye(context: context,
                           center: CGPoint(x: center.x + side * radius * eyeSpread, y: eyeY),
                           radius: radius * 0.22)
        }
        drawSmile(context: context, center: CGPoint(x: center.x, y: center.y + radius * 0.28),
                  radius: radius * 0.20)
        drawBlush(context: context, center: CGPoint(x: center.x, y: center.y + radius * 0.18),
                  spread: radius * (eyeSpread + 0.32), radius: radius * 0.13)
    }

    /// Big dark eye with two white sparkles — the heart of the kawaii look.
    func drawSparkleEye(context: GraphicsContext, center: CGPoint, radius: Double) {
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                   width: radius * 2, height: radius * 2)),
            with: .color(Color(hue: 0.65, saturation: 0.45, brightness: 0.22))
        )
        let bigSpark = radius * 0.42
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius * 0.45, y: center.y - radius * 0.55,
                                   width: bigSpark, height: bigSpark)),
            with: .color(.white.opacity(0.95))
        )
        let smallSpark = radius * 0.22
        context.fill(
            Path(ellipseIn: CGRect(x: center.x + radius * 0.25, y: center.y + radius * 0.2,
                                   width: smallSpark, height: smallSpark)),
            with: .color(.white.opacity(0.75))
        )
    }

    /// Small open smile (arc stroke).
    func drawSmile(context: GraphicsContext, center: CGPoint, radius: Double) {
        var smile = Path()
        smile.addArc(center: center, radius: radius,
                     startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
        context.stroke(smile, with: .color(Color(hue: 0.65, saturation: 0.45, brightness: 0.25).opacity(0.8)),
                       style: StrokeStyle(lineWidth: max(1.2, radius * 0.22), lineCap: .round))
    }

    /// Pink blush dots on both cheeks.
    func drawBlush(context: GraphicsContext, center: CGPoint, spread: Double, radius: Double) {
        let blushColor = Color(hue: 0.98, saturation: 0.45, brightness: 1.0).opacity(0.35)
        for side in [-1.0, 1.0] {
            context.fill(
                Path(ellipseIn: CGRect(x: center.x + side * spread - radius,
                                       y: center.y - radius * 0.7,
                                       width: radius * 2, height: radius * 1.4)),
                with: .color(blushColor)
            )
        }
    }
}
