// SceneSignalTests — cover the value-type contract for SceneSignal & GuardPolicy
// pairings the iOS adapters depend on. These complement BackgroundGuardTests
// which already exercise the decision matrix end-to-end.

import XCTest
@testable import StudyCore

final class SceneSignalTests: XCTestCase {
    func testSceneSignalIsEquatable() {
        XCTAssertEqual(SceneSignal.enteredBackground, .enteredBackground)
        XCTAssertNotEqual(SceneSignal.enteredBackground, .becameActive)
    }

    func testGuardActionEquatable() {
        XCTAssertEqual(GuardAction.stop(reason: .background), .stop(reason: .background))
        XCTAssertNotEqual(GuardAction.stop(reason: .background), .stop(reason: .screenLock))
        XCTAssertNotEqual(GuardAction.pause(reason: .phoneCall), .pause(reason: .audio))
    }

    func testPauseTriggerLabelsAreStable() {
        // Underpins the AppState → core pause-reason mapping.
        let allTriggers: [PauseTrigger] = [
            .userManual, .background, .screenLock, .phoneCall,
            .audio, .pip, .splitView, .lectureCap,
        ]
        XCTAssertEqual(Set(allTriggers).count, allTriggers.count)
    }

    @MainActor
    func testBackgroundGuardRoutesDistinctSignalsToDistinctActions() {
        var captured: [(SceneSignal, GuardAction)] = []
        let g = BackgroundGuard(contextProvider: {
            GuardContext(subjectAllowsPhoneUse: false)
        })
        g.onDecision = { signal, action in captured.append((signal, action)) }

        let signals: [SceneSignal] = [
            .enteredBackground, .screenLocked, .pictureInPictureStarted,
            .splitViewShrunk, .phoneCallStarted, .audioInterruptionBegan,
            .becameInactive, .becameActive, .userPaused, .userResumed, .userEnded,
        ]
        g.ingest(signals)

        XCTAssertEqual(captured.count, signals.count)
        XCTAssertEqual(captured[0].1, .stop(reason: .background))
        XCTAssertEqual(captured[1].1, .stop(reason: .screenLock))
        XCTAssertEqual(captured[2].1, .stop(reason: .pip))
        XCTAssertEqual(captured[3].1, .stop(reason: .splitView))
        XCTAssertEqual(captured[4].1, .pause(reason: .phoneCall))
        XCTAssertEqual(captured[5].1, .pause(reason: .audio))
        XCTAssertEqual(captured[6].1, .ignore)
        XCTAssertEqual(captured[7].1, .ignore)
        XCTAssertEqual(captured[8].1, .pause(reason: .userManual))
        XCTAssertEqual(captured[9].1, .resume)
        XCTAssertEqual(captured[10].1, .end)
    }
}
