// StudyApp — main entry point.
// Wires up SwiftData container, BackgroundGuard, Firebase, and the root scene.

import SwiftUI
import SwiftData
import StudyCore
import FirebaseCore
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct StudyApp: App {
    @State private var appState = AppState()
    // Skip onboarding for demo/screenshot builds so DemoContentSeeder (in
    // RootView) runs. `--seed-demo` is never set on TestFlight/App Store builds.
    @State private var onboardingComplete: Bool =
        UserDefaults.standard.bool(forKey: "onboarding.complete")
        || ProcessInfo.processInfo.arguments.contains("--seed-demo")
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Configure Firebase only when a valid plist ships with the build.
        // Missing plist would otherwise trap with an NSException — fatal for
        // the local-first features the app should keep offering offline.
        // ServerMode tracks the outcome so the UI can banner the degraded
        // state instead of crashing the whole app on a misconfiguration.
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
        } else {
            ServerMode.shared.reportOffline(reason: "Firebase 설정 파일이 없어요. 로컬 모드로 실행됩니다.")
        }
    }

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
            #if canImport(GoogleSignIn)
            .onOpenURL { url in
                // Google Sign-In hands control back via a custom URL scheme.
                // Forwarding here is required for the post-auth redirect to
                // resolve the awaiting `signIn(withPresenting:)` continuation.
                _ = GIDSignIn.sharedInstance.handle(url)
            }
            #endif
            .task {
                // CloudKit calls hard-trap when the entitlement isn't actually
                // signed into the binary — that's the simulator case while we
                // build with CODE_SIGNING_ALLOWED=NO. Skip the probe there;
                // real devices and TestFlight builds will run it.
                #if !targetEnvironment(simulator)
                await CloudKitService.shared.probeAvailability()
                #endif
                // Sign in anonymously (or re-attach to the cached anon user)
                // so any Firestore writes from this session already carry an
                // auth UID. Failures are surfaced via AuthBootstrap.lastError.
                await AuthBootstrap.shared.signInIfNeeded()
            }
        }
        .modelContainer(AppModelContainer.shared.container)
    }
}
