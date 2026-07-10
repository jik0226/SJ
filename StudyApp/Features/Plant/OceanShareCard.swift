// OceanShareCard — renders the user's ocean as a portrait share image
// (Instagram-story friendly 4:5) with name + nutrient stats + app mark, and
// the UIKit share-sheet bridge used to post it anywhere. This is the outside-
// the-app viral loop: the ocean travels without requiring a friend code.

import SwiftUI
import StudyCore

/// Fixed-size card rendered off-screen by ImageRenderer. 360×450pt at
/// scale 3 → 1080×1350px, Instagram's portrait ratio.
struct OceanShareCard: View {
    let parameters: OceanParameters
    let name: String
    let studyMinutes: Int
    let workoutMinutes: Int

    var body: some View {
        VStack(spacing: 0) {
            PlantCanvasView(parameters: parameters, sway: 0)
                .frame(width: 360, height: 330)
                .clipped()

            VStack(spacing: 6) {
                Text(name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("공부 \(format(studyMinutes)) · 운동 \(format(workoutMinutes))")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Study J — 공부로 자라는 나의 바다")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 6)
            }
            .frame(width: 360, height: 120)
            .background(Color(hue: parameters.mood.bottomHue, saturation: 0.70, brightness: 0.22))
        }
        .frame(width: 360, height: 450)
    }

    private func format(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)시간 \(minutes % 60)분" : "\(minutes)분"
    }
}

@MainActor
enum OceanShareRenderer {
    /// Renders the share card to a UIImage at 3x (1080×1350px).
    static func render(plant: PlantModel) -> UIImage? {
        let card = OceanShareCard(
            parameters: plant.parameters,
            name: plant.name,
            studyMinutes: plant.studyMinutes,
            workoutMinutes: plant.workoutMinutes
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// Thin UIActivityViewController bridge — SwiftUI's ShareLink renders its
/// item eagerly on every body evaluation, which would re-rasterize the ocean
/// constantly; this presents on demand instead.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
