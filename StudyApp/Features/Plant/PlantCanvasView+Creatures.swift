// PlantCanvasView+Creatures — parametric draw helpers for mascot creatures,
// seabed starfish, and sky tokens. Pure functions; no state.

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
        let shellColor = Color(hue: accentHue, saturation: 0.50, brightness: 0.55)
        let patternColor = Color(hue: accentHue, saturation: 0.30, brightness: 0.38)
        let skinColor = Color(hue: accentHue, saturation: 0.40, brightness: 0.70)

        // Shell — large rounded ellipse.
        let shellW = radius * 1.3
        let shellH = radius * 1.0
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - shellW, y: center.y - shellH * 0.6,
                                   width: shellW * 2, height: shellH * 1.2)),
            with: .color(shellColor)
        )
        // Shell hex pattern — 3 small circles on top.
        for i in -1...1 {
            let px = center.x + Double(i) * radius * 0.42
            let pr = radius * 0.18
            context.fill(
                Path(ellipseIn: CGRect(x: px - pr, y: center.y - radius * 0.55,
                                       width: pr * 2, height: pr * 2)),
                with: .color(patternColor)
            )
        }

        // 4 stubby flippers (top-left, top-right, bottom-left, bottom-right).
        let flipperOffsets: [(Double, Double)] = [(-0.85, -0.45), (0.85, -0.45),
                                                   (-0.85, 0.35),  (0.85, 0.35)]
        for (dx, dy) in flipperOffsets {
            let fx = center.x + dx * radius
            let fy = center.y + dy * radius
            context.fill(
                Path(ellipseIn: CGRect(x: fx - radius * 0.28, y: fy - radius * 0.20,
                                       width: radius * 0.56, height: radius * 0.40)),
                with: .color(skinColor)
            )
        }

        // Head — small circle to the right.
        let headX = center.x + shellW * 0.85
        let headR = radius * 0.30
        context.fill(
            Path(ellipseIn: CGRect(x: headX - headR, y: center.y - headR * 0.9,
                                   width: headR * 2, height: headR * 2)),
            with: .color(skinColor)
        )
        // Big cute eye.
        drawCuteEye(context: context, center: CGPoint(x: headX + headR * 0.3, y: center.y - headR * 0.25),
                    radius: headR * 0.45)
    }

    // MARK: - Octopus (balanced)

    func drawOctopus(
        context: GraphicsContext, center: CGPoint, radius: Double, accentHue: Double
    ) {
        let bodyColor = Color(hue: accentHue, saturation: 0.55, brightness: 0.72)
        // Tentacles first so head sits on top (5, fixed for visual balance).
        for i in 0..<5 {
            let angle = Double(i) / 5.0 * .pi + 0.1
            let tx = center.x + cos(angle) * radius * 1.6
            let ty = center.y + radius * 0.4 + sin(angle) * radius * 1.3
            var path = Path()
            path.move(to: CGPoint(x: center.x + cos(angle) * radius * 0.7, y: center.y + radius * 0.3))
            let mid1 = CGPoint(x: center.x + cos(angle) * radius + sin(angle) * radius * 0.5, y: center.y + radius * 0.8)
            let mid2 = CGPoint(x: tx - sin(angle) * radius * 0.4, y: ty - radius * 0.4)
            path.addCurve(to: CGPoint(x: tx, y: ty), control1: mid1, control2: mid2)
            context.stroke(path, with: .color(bodyColor.opacity(0.85)),
                           style: StrokeStyle(lineWidth: radius * 0.22, lineCap: .round))
        }
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 1.05,
                                   width: radius * 2, height: radius * 1.85)),
            with: .color(bodyColor)
        )
        drawCuteEye(context: context,
                    center: CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.25),
                    radius: radius * 0.28)
        drawCuteEye(context: context,
                    center: CGPoint(x: center.x + radius * 0.35, y: center.y - radius * 0.25),
                    radius: radius * 0.28)
    }

    // MARK: - Crab (active-dominant)

    func drawCrab(
        context: GraphicsContext, center: CGPoint, radius: Double, accentHue: Double
    ) {
        let bodyColor = Color(hue: accentHue, saturation: 0.65, brightness: 0.75)

        // 4 small legs on each side (drawn first, behind body).
        for side in [-1.0, 1.0] {
            for j in 0..<3 {
                let legAngle = side * (.pi * 0.5 + Double(j - 1) * 0.28)
                let lx = center.x + cos(legAngle) * radius * 1.6
                let ly = center.y + sin(legAngle) * radius * 0.6 + Double(j) * radius * 0.18
                var leg = Path()
                leg.move(to: CGPoint(x: center.x + cos(legAngle) * radius * 0.8, y: center.y + Double(j - 1) * radius * 0.2))
                leg.addLine(to: CGPoint(x: lx, y: ly))
                context.stroke(leg, with: .color(bodyColor.opacity(0.80)),
                               style: StrokeStyle(lineWidth: radius * 0.14, lineCap: .round))
            }
        }

        // Two claws — larger and bent.
        for side in [-1.0, 1.0] {
            let clawBaseX = center.x + side * radius * 0.90
            let clawBaseY = center.y - radius * 0.20
            let clawTipX = center.x + side * radius * 1.75
            let clawTipY = center.y - radius * 0.55
            var claw = Path()
            claw.move(to: CGPoint(x: clawBaseX, y: clawBaseY))
            claw.addLine(to: CGPoint(x: clawTipX, y: clawTipY))
            context.stroke(claw, with: .color(bodyColor),
                           style: StrokeStyle(lineWidth: radius * 0.22, lineCap: .round))
            // Claw pincer — small V shape at tip.
            var pincer = Path()
            pincer.move(to: CGPoint(x: clawTipX - side * radius * 0.15, y: clawTipY - radius * 0.20))
            pincer.addLine(to: CGPoint(x: clawTipX, y: clawTipY))
            pincer.addLine(to: CGPoint(x: clawTipX - side * radius * 0.15, y: clawTipY + radius * 0.18))
            context.stroke(pincer, with: .color(bodyColor),
                           style: StrokeStyle(lineWidth: radius * 0.16, lineCap: .round))
        }

        // Round body.
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.7,
                                   width: radius * 2, height: radius * 1.4)),
            with: .color(bodyColor)
        )

        // Two big eyes on stalks.
        for side in [-1.0, 1.0] {
            let stalkX = center.x + side * radius * 0.42
            let stalkY = center.y - radius * 0.7
            var stalk = Path()
            stalk.move(to: CGPoint(x: stalkX, y: stalkY + radius * 0.18))
            stalk.addLine(to: CGPoint(x: stalkX, y: stalkY - radius * 0.12))
            context.stroke(stalk, with: .color(bodyColor.opacity(0.9)),
                           style: StrokeStyle(lineWidth: radius * 0.10, lineCap: .round))
            drawCuteEye(context: context,
                        center: CGPoint(x: stalkX, y: stalkY - radius * 0.12),
                        radius: radius * 0.22)
        }
    }

    // MARK: - Seabed starfish

    func drawStarfish(
        context: GraphicsContext, center: CGPoint, radius: Double, hue: Double
    ) {
        let color = Color(hue: hue, saturation: 0.70, brightness: 0.80)
        let points = 5
        var path = Path()
        for i in 0..<(points * 2) {
            let r = (i % 2 == 0) ? radius : radius * 0.42
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let px = center.x + cos(angle) * r
            let py = center.y + sin(angle) * r
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        path.closeSubpath()
        context.fill(path, with: .color(color))
        // Light center dot.
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius * 0.18, y: center.y - radius * 0.18,
                                   width: radius * 0.36, height: radius * 0.36)),
            with: .color(color.opacity(0.55))
        )
    }

    // MARK: - Sky tokens

    func drawSkyToken(
        context: GraphicsContext, size: CGSize, token: SkyToken, mood: OceanMood
    ) {
        let corner = CGPoint(x: size.width * 0.82, y: size.height * 0.07)
        switch token {
        case .moon:   drawMoon(context: context, center: corner, radius: size.width * 0.045)
        case .cloud:  drawCloud(context: context, center: corner, radius: size.width * 0.045)
        case .sun:    drawSun(context: context, center: corner, radius: size.width * 0.040)
        }
    }

    private func drawMoon(context: GraphicsContext, center: CGPoint, radius: Double) {
        // Crescent: large disc minus offset disc.
        let moonColor = Color(hue: 0.13, saturation: 0.15, brightness: 0.97)
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                   width: radius * 2, height: radius * 2)),
            with: .color(moonColor)
        )
        // Cut-out using a slightly offset disc filled with the bg color.
        let cutColor = Color(hue: 0.67, saturation: 0.30, brightness: 0.20).opacity(0.90)
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius * 0.55, y: center.y - radius * 1.05,
                                   width: radius * 1.8, height: radius * 1.8)),
            with: .color(cutColor)
        )
        // 2-3 tiny star dots nearby.
        let starPositions: [(Double, Double)] = [(-2.2, -0.8), (-1.6, 1.5), (-3.0, 0.6)]
        for (dx, dy) in starPositions {
            let sr = radius * 0.09
            context.fill(
                Path(ellipseIn: CGRect(x: center.x + dx * radius - sr,
                                       y: center.y + dy * radius - sr,
                                       width: sr * 2, height: sr * 2)),
                with: .color(moonColor.opacity(0.85))
            )
        }
    }

    private func drawCloud(context: GraphicsContext, center: CGPoint, radius: Double) {
        let cloudColor = Color.white.opacity(0.88)
        // Three overlapping circles form a fluffy cloud.
        let circles: [(Double, Double, Double)] = [
            (0, 0, 1.0),   // center
            (-radius, radius * 0.25, 0.72),  // left
            (radius, radius * 0.25, 0.72),   // right
        ]
        for (dx, dy, scale) in circles {
            let r = radius * scale
            context.fill(
                Path(ellipseIn: CGRect(x: center.x + dx - r, y: center.y + dy - r,
                                       width: r * 2, height: r * 2)),
                with: .color(cloudColor)
            )
        }
    }

    private func drawSun(context: GraphicsContext, center: CGPoint, radius: Double) {
        let sunColor = Color(hue: 0.13, saturation: 0.85, brightness: 1.0)
        // Rays — 8 short lines.
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4
            let inner = radius * 1.3
            let outer = radius * 1.8
            var ray = Path()
            ray.move(to: CGPoint(x: center.x + cos(angle) * inner,
                                 y: center.y + sin(angle) * inner))
            ray.addLine(to: CGPoint(x: center.x + cos(angle) * outer,
                                    y: center.y + sin(angle) * outer))
            context.stroke(ray, with: .color(sunColor.opacity(0.75)),
                           style: StrokeStyle(lineWidth: radius * 0.18, lineCap: .round))
        }
        // Sun disc.
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                   width: radius * 2, height: radius * 2)),
            with: .color(sunColor)
        )
    }

    // MARK: - Shared helpers

    func drawCuteEye(context: GraphicsContext, center: CGPoint, radius: Double) {
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                   width: radius * 2, height: radius * 2)),
            with: .color(.white)
        )
        let pupilR = radius * 0.55
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - pupilR * 0.6, y: center.y - pupilR,
                                   width: pupilR * 1.2, height: pupilR * 2)),
            with: .color(.black)
        )
        let sparkR = radius * 0.18
        context.fill(
            Path(ellipseIn: CGRect(x: center.x + radius * 0.15, y: center.y - radius * 0.35,
                                   width: sparkR * 2, height: sparkR * 2)),
            with: .color(.white.opacity(0.9))
        )
    }
}
