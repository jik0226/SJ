// OceanMomentSheet — the celebratory "your ocean changed" sheet shown right
// after a session ends. A small "before" thumbnail crossfades into the big
// "after" ocean so the growth caused by *this* session is unmistakable.

import SwiftUI
import StudyCore

struct OceanMomentSheet: View {
    let moment: OceanMoment
    @Environment(\.dismiss) private var dismiss

    /// false = showing the before ocean, true = revealed the after ocean.
    @State private var revealed = false
    @State private var sway: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content so small devices / large Dynamic Type never
            // clip the button pinned below.
            ScrollView {
                VStack(spacing: DT.Spacing.lg) {
                    Text(revealed ? "바다가 변했어요!" : "\(kindLabel) 끝!")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(DT.Color.textPrimary)
                        .padding(.top, DT.Spacing.xl)

                    Text("+\(moment.addedMinutes)분 \(kindLabel)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DT.Spacing.md)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(kindColor))

                    ZStack {
                        PlantCanvasView(parameters: moment.before, sway: sway)
                            .opacity(revealed ? 0 : 1)
                        PlantCanvasView(parameters: moment.after, sway: sway)
                            .opacity(revealed ? 1 : 0)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
                    .padding(.horizontal, DT.Spacing.lg)
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 3)

                    VStack(spacing: DT.Spacing.xs) {
                        ForEach(moment.changeCallouts.prefix(2), id: \.self) { line in
                            Text(line)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(DT.Color.textPrimary)
                        }
                    }
                    .opacity(revealed ? 1 : 0)
                    .frame(minHeight: 40)
                }
                .padding(.bottom, DT.Spacing.md)
            }

            Button {
                dismiss()
            } label: {
                Text("좋아!")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DT.Spacing.md)
                    .background(RoundedRectangle(cornerRadius: DT.Radius.md).fill(DT.Color.primary))
            }
            .padding(.horizontal, DT.Spacing.lg)
            .padding(.bottom, DT.Spacing.lg)
        }
        .background(DT.Color.surface.ignoresSafeArea())
        .task {
            // Hold on the before ocean for a beat, then reveal the growth.
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeInOut(duration: 1.2)) { revealed = true }
            // Gentle sway so the reveal feels alive rather than a static swap.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                sway = (sway + 0.01).truncatingRemainder(dividingBy: 1.0)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var kindLabel: String {
        moment.kind == .workout ? "운동" : "공부"
    }

    private var kindColor: Color {
        moment.kind == .workout ? DT.Color.success : DT.Color.primary
    }
}
