// PomodoroDialView — 60-minute kitchen-timer style dial.
// A red pie slice represents the *remaining* work time and shrinks counter-
// clockwise to zero. Mirrors the analogue pomodoro timers users buy at
// 다이소 — instantly recognisable, no second-hand fiddling.
//
// Inputs are pure (remainingSeconds + workSeconds) so the view is trivial to
// preview and never depends on AppState directly.

import SwiftUI

struct PomodoroDialView: View {
    /// 0 .. workSeconds. Clamped internally.
    let remainingSeconds: Int
    /// Total length of one pomodoro work block in seconds. > 0.
    let workSeconds: Int

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                DialFace()
                RemainingSlice(progress: clampedProgress)
                CenterKnob()
                centerLabel
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var clampedProgress: Double {
        guard workSeconds > 0 else { return 0 }
        let r = max(0, min(remainingSeconds, workSeconds))
        return Double(r) / Double(workSeconds)
    }

    private var centerLabel: some View {
        VStack(spacing: 2) {
            Text(timeText)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DT.Color.textPrimary)
            Text("남음")
                .font(.caption)
                .foregroundStyle(DT.Color.textSecondary)
        }
    }

    private var timeText: String {
        let r = max(0, remainingSeconds)
        let m = r / 60
        let s = r % 60
        return String(format: "%02d:%02d", m, s)
    }
}

/// Dial face with 60 tick marks and 0/5/10/.../55 numerals.
private struct DialFace: View {
    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 2

            // Outer rim — soft cream to mimic the physical-timer look.
            let rim = Path(ellipseIn: CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            ))
            ctx.fill(rim, with: .color(Color(red: 0.98, green: 0.97, blue: 0.94)))
            ctx.stroke(rim, with: .color(.black.opacity(0.10)), lineWidth: 1.5)

            // Tick marks: minute (short) and 5-minute (long).
            for minute in 0..<60 {
                let isFive = minute % 5 == 0
                let angle = Angle(degrees: Double(minute) * 6 - 90).radians
                let outer = radius - 4
                let inner = isFive ? radius - 18 : radius - 10
                let p1 = CGPoint(
                    x: center.x + cos(angle) * outer,
                    y: center.y + sin(angle) * outer
                )
                let p2 = CGPoint(
                    x: center.x + cos(angle) * inner,
                    y: center.y + sin(angle) * inner
                )
                var tick = Path()
                tick.move(to: p1)
                tick.addLine(to: p2)
                ctx.stroke(
                    tick,
                    with: .color(.black.opacity(isFive ? 0.55 : 0.20)),
                    lineWidth: isFive ? 1.6 : 1.0
                )
            }
        }
        .overlay(
            // Numerals 0, 5, 10, ... 55. Overlay so SwiftUI handles text
            // rendering rather than Canvas glyph emission.
            GeometryReader { proxy in
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                let radius = min(proxy.size.width, proxy.size.height) / 2 - 28
                ForEach(0..<12) { i in
                    let minute = i * 5
                    let angle = Angle(degrees: Double(minute) * 6 - 90).radians
                    Text("\(minute)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.65))
                        .position(
                            x: center.x + cos(angle) * radius,
                            y: center.y + sin(angle) * radius
                        )
                }
            }
        )
    }
}

/// Blue pie slice — shrinks counter-clockwise as time passes. Uses the app
/// primary tone so the dial sits inside the existing ocean palette.
private struct RemainingSlice: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = min(proxy.size.width, proxy.size.height) / 2 - 22
            let sweep = 360.0 * progress
            Path { path in
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + sweep),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(DT.Color.primary)
            .overlay(
                Path { path in
                    path.move(to: center)
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + sweep),
                        clockwise: false
                    )
                    path.closeSubpath()
                }
                .stroke(DT.Color.primary.opacity(0.65), lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.4), value: progress)
        }
    }
}

private struct CenterKnob: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height) * 0.22
            ZStack {
                Circle()
                    .fill(Color(red: 0.86, green: 0.85, blue: 0.83))
                Circle()
                    .stroke(.black.opacity(0.10), lineWidth: 1)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}

#Preview {
    PomodoroDialView(remainingSeconds: 18 * 60, workSeconds: 25 * 60)
        .frame(width: 280, height: 280)
        .padding()
        .background(Color(.systemBackground))
}
