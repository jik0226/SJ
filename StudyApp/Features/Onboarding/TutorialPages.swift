// TutorialPages — individual page content for TutorialView.
// Each page reuses TutorialPageShell for a consistent layout.

import SwiftUI
import SwiftData
import StudyCore

/// Page 1: welcome — sets the "study time becomes your ocean" promise.
struct TutorialWelcomePage: View {
    var body: some View {
        TutorialPageShell(
            systemImage: "water.waves",
            title: "공부한 시간이\n나만의 바다가 됩니다",
            body_: "타이머를 켜고 공부할수록\n바다가 조금씩 풍성해져요.\n어떻게 자라는지 짧게 보여드릴게요."
        )
    }
}

/// Page 2: pure study timer flow — subject select → start → finish.
struct TutorialTimerPage: View {
    var body: some View {
        TutorialPageShell(
            systemImage: "timer",
            title: "순공 타이머",
            body_: "과목을 고르고 시작 버튼만 누르면 끝.\n끝낼 땐 종료만 누르면\n공부 시간이 자동으로 기록돼요."
        )
    }
}

/// Page 3: 10-minute planner block-filling.
struct TutorialPlannerPage: View {
    var body: some View {
        TutorialPageShell(
            systemImage: "calendar",
            title: "10분 플래너",
            body_: "하루를 10분 단위 블록으로 나눠\n계획을 채워보세요.\n촘촘하게, 부담 없이 계획할 수 있어요."
        )
    }
}

/// Page 4: live ocean preview — the core differentiator. Uses the USER'S OWN
/// plant seed (already created at container init) with sample nutrients, so
/// this is a genuine sneak peek of *their* future sea: their mascot color,
/// their fish species and pattern. Falls back to a fixed seed only if the
/// plant somehow isn't ready yet.
struct TutorialOceanPage: View {
    @Query private var plants: [PlantModel]

    private var previewParameters: OceanParameters {
        let seed = plants.first.map { UInt64(bitPattern: Int64($0.seed)) } ?? 12345
        return PlantFormula.parameters(
            seed: seed,
            nutrients: PlantNutrients(studyMinutes: 300, workoutMinutes: 120)
        )
    }

    var body: some View {
        TutorialPageShell(
            systemImage: "sparkles",
            title: "나만의 바다",
            body_: "공부와 운동을 어떻게 섞었는지에 따라\n바다의 모습이 달라져요.\n이건 미래의 '네' 바다 — 같은 바다는 세상에 없어요."
        ) {
            VStack(spacing: DT.Spacing.sm) {
                PlantCanvasView(parameters: previewParameters, sway: 0)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: DT.Radius.xl))
                    .padding(.horizontal, DT.Spacing.xl)
                // Speakable identity line — names their DNA on first meet.
                Text(previewParameters.dna.summary(
                    mascot: previewParameters.mascot,
                    accentHue: previewParameters.mood.accentHue
                ))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(DT.Color.textSecondary)
            }
        }
    }
}

/// Page 5: social — friend codes and shared records.
struct TutorialFriendsPage: View {
    var body: some View {
        TutorialPageShell(
            systemImage: "bubble.left.and.bubble.right",
            title: "친구와 함께",
            body_: "친구 코드로 친구를 추가하고\n서로의 공부 기록을 응원해보세요.\n혼자보다 오래갑니다."
        )
    }
}
