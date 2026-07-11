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
    // One-time post-onboarding walkthrough. Only ever shown to a fresh
    // install — see the backfill logic in init() for existing users.
    // No inline default here: it must be assigned inside init(), after the
    // backfill runs, since Swift applies property default-value expressions
    // before the init() body executes (which would otherwise read the
    // UserDefaults key before the backfill has a chance to set it).
    @State private var tutorialComplete: Bool
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

        // Backfill: users who already completed onboarding before this
        // tutorial existed must never see it retroactively on update. Mark
        // it complete for them so only fresh installs go through it.
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "onboarding.complete"),
           defaults.object(forKey: "tutorial.complete") == nil {
            defaults.set(true, forKey: "tutorial.complete")
        }
        _tutorialComplete = State(initialValue:
            defaults.bool(forKey: "tutorial.complete")
            || ProcessInfo.processInfo.arguments.contains("--seed-demo")
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !onboardingComplete {
                    AgeOnboardingView {
                        onboardingComplete = true
                    }
                    .environment(appState)
                } else if !tutorialComplete {
                    TutorialView {
                        tutorialComplete = true
                    }
                    .environment(appState)
                } else {
                    RootView()
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
