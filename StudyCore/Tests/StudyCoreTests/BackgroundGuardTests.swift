// BackgroundGuardTests — verifies the policy table against the spec.

import XCTest
@testable import StudyCore

final class BackgroundGuardTests: XCTestCase {
    private let policy = GuardPolicy()

    private func ctx(lecture: Bool = false, lockOK: Bool = false, elapsed: Int = 0) -> GuardContext {
        GuardContext(
            subjectAllowsPhoneUse: lecture,
            lockedScreenAllowed: lockOK,
            lectureSecondsElapsed: elapsed
        )
    }

    // MARK: - Stop signals
    func testBackgroundStops() {
        XCTAssertEqual(policy.decide(signal: .enteredBackground, context: ctx()),
                       .stop(reason: .background))
    }

    func testScreenLockStopsByDefault() {
        XCTAssertEqual(policy.decide(signal: .screenLocked, context: ctx()),
                       .stop(reason: .screenLock))
    }

    func testScreenLockIgnoredWhenAllowed() {
        XCTAssertEqual(policy.decide(signal: .screenLocked, context: ctx(lockOK: true)),
                       .ignore)
    }

    func testPiPStops() {
        XCTAssertEqual(policy.decide(signal: .pictureInPictureStarted, context: ctx()),
                       .stop(reason: .pip))
    }

    func testSplitViewShrunkStops() {
        XCTAssertEqual(policy.decide(signal: .splitViewShrunk, context: ctx()),
                       .stop(reason: .splitView))
    }

    // MARK: - Pause signals
    func testPhoneCallPausesAndResumes() {
        XCTAssertEqual(policy.decide(signal: .phoneCallStarted, context: ctx()),
                       .pause(reason: .phoneCall))
        XCTAssertEqual(policy.decide(signal: .phoneCallEnded, context: ctx()),
                       .resume)
    }

    func testAudioInterruptPauses() {
        XCTAssertEqual(policy.decide(signal: .audioInterruptionBegan, context: ctx()),
                       .pause(reason: .audio))
        XCTAssertEqual(policy.decide(signal: .audioInterruptionEnded, context: ctx()),
                       .resume)
    }

    // MARK: - Ignore signals (false-positive protection)
    func testInactiveIgnored() {
        XCTAssertEqual(policy.decide(signal: .becameInactive, context: ctx()), .ignore)
        XCTAssertEqual(policy.decide(signal: .becameActive, context: ctx()), .ignore)
    }

    // MARK: - Lecture mode
    func testLectureModeIgnoresDistractions() {
        XCTAssertEqual(policy.decide(signal: .enteredBackground, context: ctx(lecture: true)),
                       .ignore)
        XCTAssertEqual(policy.decide(signal: .screenLocked, context: ctx(lecture: true)),
                       .ignore)
        XCTAssertEqual(policy.decide(signal: .pictureInPictureStarted, context: ctx(lecture: true)),
                       .ignore)
    }

    func testLectureModeStillPausesOnPhoneCall() {
        XCTAssertEqual(policy.decide(signal: .phoneCallStarted, context: ctx(lecture: true)),
                       .pause(reason: .phoneCall))
    }

    func testLectureCapAlwaysStops() {
        XCTAssertEqual(policy.decide(signal: .lectureCapReached, context: ctx(lecture: true)),
                       .stop(reason: .lectureCap))
    }

    // MARK: - User actions
    func testUserActions() {
        XCTAssertEqual(policy.decide(signal: .userPaused, context: ctx()),
                       .pause(reason: .userManual))
        XCTAssertEqual(policy.decide(signal: .userResumed, context: ctx()), .resume)
        XCTAssertEqual(policy.decide(signal: .userEnded, context: ctx()), .end)
    }

    // MARK: - BackgroundGuard runtime wiring
    @MainActor
    func testGuardDispatchesDecision() {
        var lectureMode = false
        let guard_ = BackgroundGuard {
            GuardContext(subjectAllowsPhoneUse: lectureMode)
        }
        var captured: [GuardAction] = []
        guard_.onDecision = { _, action in captured.append(action) }

        guard_.ingest(.enteredBackground)
        XCTAssertEqual(captured.last, .stop(reason: .background))

        lectureMode = true
        guard_.ingest(.enteredBackground)
        XCTAssertEqual(captured.last, .ignore)
    }
}
