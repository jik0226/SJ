// TutorialView — one-time, page-style feature walkthrough shown right after
// AgeOnboardingView on a fresh install. Five swipeable pages introduce the
// timer, planner, ocean growth, and social features. Page content lives in
// TutorialPages.swift to keep this file under the 300-line limit.

import SwiftUI
import StudyCore

struct TutorialView: View {
    let onComplete: () -> Void
    @State private var page: Int = 0

    private let lastPageIndex = 4

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $page) {
                TutorialWelcomePage()
                    .tag(0)
                TutorialTimerPage()
                    .tag(1)
                TutorialPlannerPage()
                    .tag(2)
                TutorialOceanPage()
                    .tag(3)
                TutorialFriendsPage()
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .background(DT.Color.surface.ignoresSafeArea())

            if page < lastPageIndex {
                Button("건너뛰기", action: complete)
                    .font(DT.Typography.body)
                    .foregroundStyle(DT.Color.textSecondary)
                    .padding(.top, DT.Spacing.lg)
                    .padding(.trailing, DT.Spacing.lg)
            }

            if page == lastPageIndex {
                VStack {
                    Spacer()
                    Button(action: complete) {
                        Text("시작하기")
                            .font(DT.Typography.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DT.Spacing.md)
                            .background(Capsule().fill(DT.Color.primary))
                            .padding(.horizontal, DT.Spacing.xl)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, DT.Spacing.xxl)
                }
            }
        }
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: "tutorial.complete")
        onComplete()
    }
}

/// Shared visual shell for each tutorial page: icon, headline, body copy,
/// plus an optional custom preview view (e.g. the live ocean canvas).
struct TutorialPageShell<Preview: View>: View {
    let systemImage: String
    let title: String
    let body_: String
    @ViewBuilder var preview: () -> Preview

    var body: some View {
        VStack(spacing: DT.Spacing.xl) {
            Spacer(minLength: DT.Spacing.xxl)

            preview()

            VStack(spacing: DT.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 44))
                    .foregroundStyle(DT.Color.primary)
                Text(title)
                    .font(DT.Typography.title2)
                    .foregroundStyle(DT.Color.textPrimary)
                    .multilineTextAlignment(.center)
                Text(body_)
                    .font(DT.Typography.body)
                    .foregroundStyle(DT.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DT.Spacing.xl)
            }

            Spacer(minLength: DT.Spacing.xxl * 2)
        }
        .frame(maxWidth: .infinity)
        .background(DT.Color.surface.ignoresSafeArea())
    }
}

extension TutorialPageShell where Preview == EmptyView {
    init(systemImage: String, title: String, body_: String) {
        self.init(systemImage: systemImage, title: title, body_: body_) { EmptyView() }
    }
}
