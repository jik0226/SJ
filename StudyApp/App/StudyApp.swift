// StudyApp — main entry point.
// Wires up SwiftData container, BackgroundGuard, and the root scene.

import SwiftUI
import SwiftData
import StudyCore

@main
struct StudyApp: App {
    @State private var appState = AppState()
    @State private var onboardingComplete: Bool = UserDefaults.standard.bool(forKey: "onboarding.complete")
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingComplete {
                    RootView()
                        .environment(appState)
                } else {
                    AgeOnboardingView {
                        onboardingComplete = true
                    }
                    .environment(appState)
                }
            }
            .preferredColorScheme(.light)
            .onChange(of: scenePhase, initial: false) { _, phase in
                appState.handleScenePhase(phase)
            }
            .task {
                // CloudKit calls hard-trap when the entitlement isn't actually
                // signed into the binary — that's the simulator case while we
                // build with CODE_SIGNING_ALLOWED=NO. Skip the probe there;
                // real devices and TestFlight builds will run it.
                #if !targetEnvironment(simulator)
                await CloudKitService.shared.probeAvailability()
                #endif
            }
        }
        .modelContainer(AppModelContainer.shared.container)
    }
}
