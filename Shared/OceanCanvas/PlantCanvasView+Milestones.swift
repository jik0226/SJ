// PlantCanvasView+Milestones — long-term decorations unlocked by accumulated
// minutes: coral (10h) → seaweed (25h) → shipwreck (50h) → lighthouse (100h)
// → whale (300h). Shared unlock rules, seed-derived placement. Kawaii style:
// rounded strokes, pastel fills, and a face on the whale.

import SwiftUI
import StudyCore

extension PlantCanvasView {

    // MARK: - Coral (10h)

    func drawCoral(context: GraphicsContext, base: CGPoint, scale: Double) {
        let coral = Color(hue: 0.97, saturation: 0.42, brightness: 0.95)
        // Three rounded branches fanning up from the base.
        for (angle, len) in [(-0.5, 0.85), (0.0, 1.0), (0.45, 0.75)] {
            var branch = Path()
            branch.move(to: base)
            let tip = CGPoint(x: base.x + sin(angle) * scale * len,
                              y: base.y - cos(angle) * scale * len)
            branch.addQuadCurve(
                to: tip,
                control: CGPoint(x: base.x + sin(angle) * scale * len * 0.7,
                                 y: base.y - cos(angle) * scale * len * 0.4)
            )
            context.stroke(branch, with: .color(coral),
                           style: StrokeStyle(lineWidth: scale * 0.22, lineCap: .round))
            // Lighter tip bud.
            let br = scale * 0.14
            context.fill(
                Path(ellipseIn: CGRect(x: tip.x - br, y: tip.y - br, width: br * 2, height: br * 2)),
                with: .color(coral.opacity(0.6))
            )
        }
    }

    // MARK: - Seaweed (25h)

    func drawSeaweed(context: GraphicsContext, base: CGPoint, scale: Double, sway: Double) {
        let green = Color(hue: 0.38, saturation: 0.42, brightness: 0.82)
        let bend = sin(sway * 2 * .pi) * scale * 0.14
        for (dx, hMul) in [(-0.22, 0.75), (0.0, 1.0), (0.24, 0.85)] {
            let x0 = base.x + dx * scale
            var blade = Path()
            blade.move(to: CGPoint(x: x0, y: base.y))
            blade.addCurve(
                to: CGPoint(x: x0 + bend, y: base.y - scale * hMul),
                control1: CGPoint(x: x0 - scale * 0.18, y: base.y - scale * hMul * 0.35),
                control2: CGPoint(x: x0 + scale * 0.22 + bend, y: base.y - scale * hMul * 0.7)
            )
            context.stroke(blade, with: .color(green.opacity(0.9)),
                           style: StrokeStyle(lineWidth: scale * 0.13, lineCap: .round))
        }
    }

    // MARK: - Shipwreck (50h)

    func drawShipwreck(context: GraphicsContext, base: CGPoint, scale: Double) {
        let wood = Color(hue: 0.08, saturation: 0.45, brightness: 0.60)
        let woodDark = Color(hue: 0.08, saturation: 0.50, brightness: 0.45)
        // Tilted hull — a half-ellipse resting on the sand.
        var hull = Path()
        hull.move(to: CGPoint(x: base.x - scale, y: base.y - scale * 0.42))
        hull.addQuadCurve(
            to: CGPoint(x: base.x + scale, y: base.y - scale * 0.25),
            control: CGPoint(x: base.x, y: base.y + scale * 0.65)
        )
        hull.addLine(to: CGPoint(x: base.x + scale * 0.8, y: base.y - scale * 0.5))
        hull.addQuadCurve(
            to: CGPoint(x: base.x - scale, y: base.y - scale * 0.42),
            control: CGPoint(x: base.x, y: base.y - scale * 0.15)
        )
        hull.closeSubpath()
        context.fill(hull, with: .color(wood))
        // Broken mast, slightly tilted.
        var mast = Path()
        mast.move(to: CGPoint(x: base.x - scale * 0.1, y: base.y - scale * 0.3))
        mast.addLine(to: CGPoint(x: base.x + scale * 0.12, y: base.y - scale * 1.15))
        context.stroke(mast, with: .color(woodDark),
                       style: StrokeStyle(lineWidth: scale * 0.11, lineCap: .round))
        // Porthole.
        let pr = scale * 0.11
        context.fill(
            Path(ellipseIn: CGRect(x: base.x - scale * 0.45 - pr, y: base.y - scale * 0.18 - pr,
                                   width: pr * 2, height: pr * 2)),
            with: .color(.white.opacity(0.55))
        )
    }

    // MARK: - Lighthouse (100h)

    func drawLighthouse(context: GraphicsContext, base: CGPoint, scale: Double) {
        let white = Color(hue: 0.0, saturation: 0.02, brightness: 0.98)
        let red = Color(hue: 0.99, saturation: 0.55, brightness: 0.92)
        let towerW = scale * 0.38
        let towerH = scale * 1.15
        // Tower with rounded corners, slightly tapered look via rounded rect.
        context.fill(
            Path(roundedRect: CGRect(x: base.x - towerW / 2, y: base.y - towerH,
                                     width: towerW, height: towerH),
                 cornerRadius: towerW * 0.25),
            with: .color(white)
        )
        // Two red bands.
        for yMul in [0.35, 0.7] {
            context.fill(
                Path(roundedRect: CGRect(x: base.x - towerW / 2, y: base.y - towerH * yMul - towerH * 0.1,
                                         width: towerW, height: towerH * 0.14),
                     cornerRadius: towerW * 0.1),
                with: .color(red)
            )
        }
        // Dome + glowing lamp.
        let domeR = towerW * 0.55
        context.fill(
            Path(ellipseIn: CGRect(x: base.x - domeR, y: base.y - towerH - domeR * 1.2,
                                   width: domeR * 2, height: domeR * 1.4)),
            with: .color(red)
        )
        let lampR = towerW * 0.3
        context.fill(
            Path(ellipseIn: CGRect(x: base.x - lampR * 2.2, y: base.y - towerH - lampR * 3.4,
                                   width: lampR * 4.4, height: lampR * 4.4)),
            with: .color(Color(hue: 0.13, saturation: 0.5, brightness: 1.0).opacity(0.25))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: base.x - lampR, y: base.y - towerH - lampR * 2.2,
                                   width: lampR * 2, height: lampR * 2)),
            with: .color(Color(hue: 0.13, saturation: 0.6, brightness: 1.0))
        )
    }

    // MARK: - Whale (300h) — the grand prize, swims mid-water

    func drawWhale(context: GraphicsContext, center: CGPoint, radius: Double, sway: Double) {
        let bob = sin(sway * 2 * .pi) * radius * 0.10
        let c = CGPoint(x: center.x, y: center.y + bob)
        let body = Color(hue: 0.60, saturation: 0.38, brightness: 0.88)
        let deep = Color(hue: 0.60, saturation: 0.46, brightness: 0.76)

        // Tail fluke — two rounded lobes at the back-left.
        let back = CGPoint(x: c.x - radius * 1.5, y: c.y - radius * 0.1)
        for dir in [-1.0, 1.0] {
            var lobe = Path()
            lobe.move(to: back)
            lobe.addQuadCurve(
                to: CGPoint(x: back.x - radius * 0.55, y: back.y + dir * radius * 0.55),
                control: CGPoint(x: back.x - radius * 0.5, y: back.y + dir * radius * 0.05)
            )
            lobe.addQuadCurve(
                to: back,
                control: CGPoint(x: back.x - radius * 0.1, y: back.y + dir * radius * 0.3)
            )
            lobe.closeSubpath()
            context.fill(lobe, with: .color(deep))
        }

        // Big soft body + lighter belly.
        context.fill(
            Path(ellipseIn: CGRect(x: c.x - radius * 1.6, y: c.y - radius * 0.9,
                                   width: radius * 3.2, height: radius * 1.8)),
            with: .color(body)
        )
        context.fill(
            Path(ellipseIn: CGRect(x: c.x - radius * 1.1, y: c.y + radius * 0.1,
                                   width: radius * 2.4, height: radius * 0.75)),
            with: .color(.white.opacity(0.4))
        )

        // Face on the right.
        drawSparkleEye(context: context,
                       center: CGPoint(x: c.x + radius * 0.95, y: c.y - radius * 0.2),
                       radius: radius * 0.16)
        drawSmile(context: context,
                  center: CGPoint(x: c.x + radius * 1.15, y: c.y + radius * 0.15),
                  radius: radius * 0.14)
        drawBlush(context: context,
                  center: CGPoint(x: c.x + radius * 0.7, y: c.y + radius * 0.1),
                  spread: radius * 0.0, radius: radius * 0.12)

        // Spout — two cute droplets above the head.
        for (dx, dy, sMul) in [(0.45, -1.35, 1.0), (0.7, -1.6, 0.6)] {
            let dr = radius * 0.12 * sMul
            context.fill(
                Path(ellipseIn: CGRect(x: c.x + radius * dx - dr, y: c.y + radius * dy - dr,
                                       width: dr * 2, height: dr * 2.4)),
                with: .color(.white.opacity(0.6))
            )
        }
    }
}
