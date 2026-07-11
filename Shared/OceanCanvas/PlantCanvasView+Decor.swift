// PlantCanvasView+Decor — kawaii fish, starfish, and sky tokens.
// Split from +Creatures so each rendering file stays under the size limit.

import SwiftUI
import StudyCore

extension PlantCanvasView {

    // MARK: - Kawaii fish

    /// Round-bodied fish with a fan tail, top fin, big sparkle eye, smile and
    /// blush. Pastel tint; light belly so it reads soft instead of flat.
    /// `species` (0..3) sets body proportions shared by the whole school and
    /// `pattern` (0 plain / 1 stripes / 2 dots) the markings — both from the
    /// user's permanent OceanDNA.
    func drawKawaiiFish(
        context: GraphicsContext, center: CGPoint, radius: Double,
        facingRight: Bool, hue: Double, species: Int = 0, pattern: Int = 0
    ) {
        let s: Double = facingRight ? 1 : -1
        let body = Color(hue: hue, saturation: 0.42, brightness: 0.96)
        let deep = Color(hue: hue, saturation: 0.52, brightness: 0.84)
        // Species proportions: round / long / tall / chubby.
        let (wMul, hMul): (Double, Double) = [
            (1.15, 0.92), (1.50, 0.72), (0.95, 1.06), (1.25, 1.00),
        ][species % 4]
        let bodyW = radius * wMul
        let bodyH = radius * hMul

        // Fan tail — two rounded lobes behind the body.
        let back = CGPoint(x: center.x - s * bodyW * 0.9, y: center.y)
        for dir in [-1.0, 1.0] {
            var lobe = Path()
            lobe.move(to: back)
            lobe.addQuadCurve(
                to: CGPoint(x: back.x - s * bodyW * 0.65, y: center.y + dir * bodyH * 0.62),
                control: CGPoint(x: back.x - s * bodyW * 0.55, y: center.y + dir * bodyH * 0.1)
            )
            lobe.addQuadCurve(
                to: back,
                control: CGPoint(x: back.x - s * bodyW * 0.15, y: center.y + dir * bodyH * 0.35)
            )
            lobe.closeSubpath()
            context.fill(lobe, with: .color(deep))
        }

        // Top fin — small soft bump.
        var fin = Path()
        fin.move(to: CGPoint(x: center.x - s * bodyW * 0.35, y: center.y - bodyH * 0.75))
        fin.addQuadCurve(
            to: CGPoint(x: center.x + s * bodyW * 0.15, y: center.y - bodyH * 0.85),
            control: CGPoint(x: center.x - s * bodyW * 0.1, y: center.y - bodyH * 1.35)
        )
        fin.closeSubpath()
        context.fill(fin, with: .color(deep))

        // Egg-round body + lighter belly.
        let bodyRect = CGRect(x: center.x - bodyW, y: center.y - bodyH,
                              width: bodyW * 2, height: bodyH * 2)
        context.fill(Path(ellipseIn: bodyRect), with: .color(body))
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - bodyW * 0.62, y: center.y + bodyH * 0.05,
                                   width: bodyW * 1.24, height: bodyH * 0.8)),
            with: .color(.white.opacity(0.35))
        )

        // DNA markings, clipped to the body so they never spill out.
        if pattern != 0 {
            var inked = context
            inked.clip(to: Path(ellipseIn: bodyRect))
            if pattern == 1 {
                // Two soft vertical stripes across the back.
                for off in [-0.25, 0.2] {
                    let sx = center.x + s * bodyW * off
                    inked.fill(
                        Path(roundedRect: CGRect(x: sx - bodyW * 0.09, y: center.y - bodyH,
                                                 width: bodyW * 0.18, height: bodyH * 1.2),
                             cornerRadius: bodyW * 0.09),
                        with: .color(deep.opacity(0.55))
                    )
                }
            } else {
                // Three little dots on the upper back.
                for (dx, dy) in [(-0.35, -0.45), (0.0, -0.6), (0.3, -0.4)] {
                    let dr = bodyW * 0.10
                    inked.fill(
                        Path(ellipseIn: CGRect(x: center.x + s * bodyW * dx - dr,
                                               y: center.y + bodyH * dy - dr,
                                               width: dr * 2, height: dr * 2)),
                        with: .color(deep.opacity(0.55))
                    )
                }
            }
        }

        // Face — one big sparkle eye + smile + blush on the facing side.
        let eyeC = CGPoint(x: center.x + s * bodyW * 0.42, y: center.y - bodyH * 0.18)
        let eyeR = max(1.8, radius * 0.24)
        context.fill(
            Path(ellipseIn: CGRect(x: eyeC.x - eyeR, y: eyeC.y - eyeR,
                                   width: eyeR * 2, height: eyeR * 2)),
            with: .color(Color(hue: 0.65, saturation: 0.45, brightness: 0.22))
        )
        let sparkR = eyeR * 0.42
        context.fill(
            Path(ellipseIn: CGRect(x: eyeC.x - eyeR * 0.45, y: eyeC.y - eyeR * 0.55,
                                   width: sparkR, height: sparkR)),
            with: .color(.white.opacity(0.95))
        )
        var smile = Path()
        smile.addArc(center: CGPoint(x: eyeC.x + s * eyeR * 0.4, y: center.y + bodyH * 0.3),
                     radius: max(1.0, radius * 0.14),
                     startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
        context.stroke(smile, with: .color(Color(hue: 0.65, saturation: 0.4, brightness: 0.3).opacity(0.7)),
                       style: StrokeStyle(lineWidth: max(0.8, radius * 0.08), lineCap: .round))
        let blushR = max(1.0, radius * 0.12)
        context.fill(
            Path(ellipseIn: CGRect(x: center.x + s * bodyW * 0.1 - blushR, y: center.y + bodyH * 0.14,
                                   width: blushR * 2, height: blushR * 1.4)),
            with: .color(Color(hue: 0.98, saturation: 0.45, brightness: 1.0).opacity(0.35))
        )
    }

    // MARK: - Starfish (with a tiny face)

    func drawStarfish(
        context: GraphicsContext, center: CGPoint, radius: Double, hue: Double
    ) {
        let color = Color(hue: hue, saturation: 0.48, brightness: 0.95)
        let points = 5
        // Puffy star: quad-curve between outer points through inner controls
        // so the arms are rounded instead of spiky.
        var path = Path()
        for i in 0..<points {
            let outerAngle = Double(i) * 2 * .pi / Double(points) - .pi / 2
            let nextOuter = Double(i + 1) * 2 * .pi / Double(points) - .pi / 2
            let innerAngle = (outerAngle + nextOuter) / 2
            let p0 = CGPoint(x: center.x + cos(outerAngle) * radius,
                             y: center.y + sin(outerAngle) * radius)
            let ctrl = CGPoint(x: center.x + cos(innerAngle) * radius * 0.35,
                               y: center.y + sin(innerAngle) * radius * 0.35)
            let p1 = CGPoint(x: center.x + cos(nextOuter) * radius,
                             y: center.y + sin(nextOuter) * radius)
            if i == 0 { path.move(to: p0) }
            path.addQuadCurve(to: p1, control: ctrl)
        }
        path.closeSubpath()
        context.fill(path, with: .color(color))

        // Tiny face in the middle — dot eyes + smile.
        let ink = Color(hue: 0.65, saturation: 0.45, brightness: 0.25).opacity(0.75)
        let eyeR = max(0.8, radius * 0.08)
        for side in [-1.0, 1.0] {
            context.fill(
                Path(ellipseIn: CGRect(x: center.x + side * radius * 0.22 - eyeR,
                                       y: center.y - radius * 0.10 - eyeR,
                                       width: eyeR * 2, height: eyeR * 2)),
                with: .color(ink)
            )
        }
        var smile = Path()
        smile.addArc(center: CGPoint(x: center.x, y: center.y + radius * 0.08),
                     radius: max(0.9, radius * 0.12),
                     startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
        context.stroke(smile, with: .color(ink),
                       style: StrokeStyle(lineWidth: max(0.7, radius * 0.07), lineCap: .round))
    }

    // MARK: - Sky tokens

    func drawSkyToken(
        context: GraphicsContext, size: CGSize, token: SkyToken, mood: OceanMood
    ) {
        let corner = CGPoint(x: size.width * 0.82, y: size.height * 0.10)
        switch token {
        case .moon:   drawMoon(context: context, center: corner, radius: size.width * 0.045)
        case .cloud:  drawCloud(context: context, center: corner, radius: size.width * 0.045)
        case .sun:    drawSun(context: context, center: corner, radius: size.width * 0.042)
        }
    }

    private func drawMoon(context: GraphicsContext, center: CGPoint, radius: Double) {
        // Full sleepy moon with a soft glow — the old crescent cut-out used a
        // hardcoded dark disc that clashed with the light sky gradient.
        let moon = Color(hue: 0.13, saturation: 0.28, brightness: 1.0)
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius * 1.9, y: center.y - radius * 1.9,
                                   width: radius * 3.8, height: radius * 3.8)),
            with: .color(moon.opacity(0.18))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                   width: radius * 2, height: radius * 2)),
            with: .color(moon)
        )
        // Closed sleepy eyes + tiny smile.
        let ink = Color(hue: 0.10, saturation: 0.55, brightness: 0.55)
        for side in [-1.0, 1.0] {
            var lid = Path()
            lid.addArc(center: CGPoint(x: center.x + side * radius * 0.4, y: center.y - radius * 0.1),
                       radius: radius * 0.18,
                       startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            context.stroke(lid, with: .color(ink),
                           style: StrokeStyle(lineWidth: max(0.9, radius * 0.1), lineCap: .round))
        }
        var smile = Path()
        smile.addArc(center: CGPoint(x: center.x, y: center.y + radius * 0.3),
                     radius: radius * 0.16,
                     startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
        context.stroke(smile, with: .color(ink),
                       style: StrokeStyle(lineWidth: max(0.9, radius * 0.1), lineCap: .round))
        // Sparkle stars nearby.
        for (dx, dy, scale) in [(-2.3, -0.6, 1.0), (-1.5, 1.3, 0.7), (-3.1, 0.7, 0.5)] {
            drawSparkleStar(context: context,
                            center: CGPoint(x: center.x + dx * radius, y: center.y + dy * radius),
                            radius: radius * 0.22 * scale)
        }
    }

    /// Four-point twinkle star (two thin crossing lozenges).
    private func drawSparkleStar(context: GraphicsContext, center: CGPoint, radius: Double) {
        var star = Path()
        star.move(to: CGPoint(x: center.x, y: center.y - radius))
        star.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: center)
        star.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: center)
        star.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: center)
        star.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: center)
        star.closeSubpath()
        context.fill(star, with: .color(.white.opacity(0.9)))
    }

    private func drawCloud(context: GraphicsContext, center: CGPoint, radius: Double) {
        let cloud = Color.white.opacity(0.92)
        for (dx, dy, scale) in [(0.0, -0.15, 1.0), (-0.95, 0.2, 0.7), (0.95, 0.2, 0.7)] {
            let r = radius * scale
            context.fill(
                Path(ellipseIn: CGRect(x: center.x + dx * radius - r, y: center.y + dy * radius - r,
                                       width: r * 2, height: r * 2)),
                with: .color(cloud)
            )
        }
        // Flat base so it reads as one cloud, not three balls.
        context.fill(
            Path(roundedRect: CGRect(x: center.x - radius * 1.5, y: center.y + radius * 0.1,
                                     width: radius * 3.0, height: radius * 0.75),
                 cornerRadius: radius * 0.35),
            with: .color(cloud)
        )
    }

    private func drawSun(context: GraphicsContext, center: CGPoint, radius: Double) {
        let sun = Color(hue: 0.12, saturation: 0.62, brightness: 1.0)
        // Soft glow + rounded rays.
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius * 2.0, y: center.y - radius * 2.0,
                                   width: radius * 4, height: radius * 4)),
            with: .color(sun.opacity(0.15))
        )
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4
            var ray = Path()
            ray.move(to: CGPoint(x: center.x + cos(angle) * radius * 1.35,
                                 y: center.y + sin(angle) * radius * 1.35))
            ray.addLine(to: CGPoint(x: center.x + cos(angle) * radius * 1.8,
                                    y: center.y + sin(angle) * radius * 1.8))
            context.stroke(ray, with: .color(sun.opacity(0.8)),
                           style: StrokeStyle(lineWidth: radius * 0.18, lineCap: .round))
        }
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                   width: radius * 2, height: radius * 2)),
            with: .color(sun)
        )
        // Happy sun face.
        let ink = Color(hue: 0.08, saturation: 0.7, brightness: 0.6)
        for side in [-1.0, 1.0] {
            let er = radius * 0.10
            context.fill(
                Path(ellipseIn: CGRect(x: center.x + side * radius * 0.35 - er,
                                       y: center.y - radius * 0.15 - er,
                                       width: er * 2, height: er * 2)),
                with: .color(ink)
            )
        }
        var smile = Path()
        smile.addArc(center: CGPoint(x: center.x, y: center.y + radius * 0.15),
                     radius: radius * 0.28,
                     startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
        context.stroke(smile, with: .color(ink),
                       style: StrokeStyle(lineWidth: max(1.0, radius * 0.1), lineCap: .round))
    }
}
