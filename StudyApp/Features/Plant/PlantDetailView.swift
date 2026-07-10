// PlantDetailView — preview canvas + nutrient breakdown + the actual math
// formulas. The "내 바다의 식" section is what makes the ocean inspectable:
// every line shows formula + current value so the visual is mathematically
// transparent, not a black-box illustration.

import SwiftUI
import SwiftData
import StudyCore

struct PlantDetailView: View {
    @Environment(\.modelContext) private var context
    @Query private var plants: [PlantModel]

    @State private var draftName: String = ""
    @State private var sway: Double = 0
    @State private var shareImage: UIImage?

    var body: some View {
        if let plant = plants.first {
            content(plant: plant)
                .navigationTitle("내 바다")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            shareImage = OceanShareRenderer.render(plant: plant)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("바다 이미지 공유")
                    }
                }
                .sheet(isPresented: Binding(
                    get: { shareImage != nil },
                    set: { if !$0 { shareImage = nil } }
                )) {
                    if let shareImage {
                        ActivityShareSheet(items: [shareImage])
                            .presentationDetents([.medium, .large])
                    }
                }
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    private func content(plant: PlantModel) -> some View {
        ScrollView {
            VStack(spacing: DT.Spacing.lg) {
                canvasCard(plant: plant)
                nameSection(plant: plant)
                nutrientSection(plant: plant)
                formulaSection(plant: plant)
                seedSection(plant: plant)
                Spacer(minLength: DT.Spacing.xxl)
            }
            .padding(.horizontal, DT.Spacing.lg)
            .padding(.top, DT.Spacing.lg)
        }
        .background(DT.Color.surface.ignoresSafeArea())
        .onAppear { draftName = plant.name }
        .task {
            // Gentle sway animation driven by a continuous timer.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                await MainActor.run {
                    sway = (sway + 0.01).truncatingRemainder(dividingBy: 1.0)
                }
            }
        }
    }

    private func canvasCard(plant: PlantModel) -> some View {
        PlantCanvasView(parameters: plant.parameters, sway: sway)
            .frame(height: 260)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        DT.Color.primary.opacity(0.08),
                        DT.Color.background,
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }

    private func nameSection(plant: PlantModel) -> some View {
        VStack(alignment: .leading, spacing: DT.Spacing.xs) {
            Text("이름")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
            HStack {
                TextField("내 바다", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                Button("저장") {
                    plant.name = draftName.trimmingCharacters(in: .whitespaces)
                    if plant.name.isEmpty { plant.name = "내 바다" }
                    Persistence.save({ try context.save() }, context: "plant.name")
                }
                .disabled(draftName.trimmingCharacters(in: .whitespaces) == plant.name)
            }
        }
        .padding(DT.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: DT.Radius.card).fill(DT.Color.background))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }

    private func nutrientSection(plant: PlantModel) -> some View {
        VStack(alignment: .leading, spacing: DT.Spacing.sm) {
            Text("영양분")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
            HStack {
                NutrientPill(label: "공부", minutes: plant.studyMinutes, color: DT.Color.primary)
                NutrientPill(label: "운동", minutes: plant.workoutMinutes, color: DT.Color.success)
            }
            Text("공부와 운동이 쌓일수록 파도가 깊어지고 물고기가 모입니다.")
                .font(.caption)
                .foregroundStyle(DT.Color.textSecondary)
        }
        .padding(DT.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: DT.Radius.card).fill(DT.Color.background))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }

    private func formulaSection(plant: PlantModel) -> some View {
        VStack(alignment: .leading, spacing: DT.Spacing.sm) {
            Text("내 바다의 식")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
            ForEach(plant.formulaLines, id: \.label) { line in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(line.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DT.Color.textPrimary)
                        Spacer()
                        Text(line.value)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DT.Color.primary)
                    }
                    Text(line.formula)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DT.Color.textSecondary)
                }
                .padding(.vertical, 4)
                Divider().opacity(0.4)
            }
        }
        .padding(DT.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: DT.Radius.card).fill(DT.Color.background))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }

    private func seedSection(plant: PlantModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("씨앗 ID")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
            Text(String(plant.seed))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(DT.Color.textPrimary)
                .textSelection(.enabled)
            Text("같은 씨앗·같은 영양분이면 누구든 동일한 파도와 물고기가 그려집니다. 바다의 시작점입니다.")
                .font(.caption2)
                .foregroundStyle(DT.Color.textSecondary)
        }
        .padding(DT.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DT.Radius.card).fill(DT.Color.background))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }
}

private struct NutrientPill: View {
    let label: String
    let minutes: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(color)
            Text("\(minutes)분")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(DT.Color.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, DT.Spacing.md)
        .padding(.vertical, DT.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.md)
                .fill(color.opacity(0.10))
        )
    }
}
