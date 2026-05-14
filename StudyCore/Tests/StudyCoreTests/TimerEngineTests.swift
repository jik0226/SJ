// TimerEngineTests — drives the state machine with an injected clock.

import XCTest
@testable import StudyCore

@MainActor
final class TimerEngineTests: XCTestCase {
    private var now = Date(timeIntervalSince1970: 1_780_000_000)
    private lazy var clock: () -> Date = { self.now }

    private func makeSubject(lecture: Bool = false) -> Subject {
        Subject(
            name: "Math",
            colorHex: "#3D7BFF",
            sfSymbol: "function",
            allowPhoneUse: lecture,
            category: .study,
            dailyTargetMinutes: 60
        )
    }

    private func makeEngine() -> TimerEngine {
        TimerEngine(calendar: PlannerCalendar(cutoffHour: 3), clock: clock)
    }

    func testStartTransitionsToRunning() throws {
        let engine = makeEngine()
        let session = try engine.start(subject: makeSubject())
        XCTAssertEqual(engine.state, .running)
        XCTAssertEqual(session.startedAt, now)
        XCTAssertNil(session.endedAt)
    }

    func testCannotStartTwice() throws {
        let engine = makeEngine()
        _ = try engine.start(subject: makeSubject())
        XCTAssertThrowsError(try engine.start(subject: makeSubject())) {
            XCTAssertEqual($0 as? TimerError, .alreadyRunning)
        }
    }

    func testPauseResumeFlow() throws {
        let engine = makeEngine()
        _ = try engine.start(subject: makeSubject())

        now = now.addingTimeInterval(60)
        try engine.pause(reason: .userManual)
        XCTAssertEqual(engine.state, .paused)

        now = now.addingTimeInterval(30)
        try engine.resume()
        XCTAssertEqual(engine.state, .running)

        now = now.addingTimeInterval(60)
        let final = try engine.end()
        XCTAssertEqual(engine.state, .ended)
        // 60 + 60 active, 30 paused -> 120s active.
        XCTAssertEqual(final.totalSeconds, 120)
        XCTAssertEqual(final.pausedRanges.count, 1)
        XCTAssertEqual(final.pausedRanges[0].seconds, 30)
    }

    func testEndWhilePausedClosesDanglingPause() throws {
        let engine = makeEngine()
        _ = try engine.start(subject: makeSubject())
        now = now.addingTimeInterval(100)
        try engine.pause(reason: .backgroundEntered)
        now = now.addingTimeInterval(50)

        let final = try engine.end()
        XCTAssertEqual(final.totalSeconds, 100)
        XCTAssertEqual(final.pausedRanges[0].seconds, 50)
        XCTAssertNotNil(final.pausedRanges[0].end)
    }

    func testElapsedSecondsUpdatesLive() throws {
        let engine = makeEngine()
        _ = try engine.start(subject: makeSubject())
        now = now.addingTimeInterval(45)
        XCTAssertEqual(engine.elapsedSeconds, 45)
    }

    func testLectureCapDetection() throws {
        let engine = makeEngine()
        _ = try engine.start(subject: makeSubject(lecture: true))
        now = now.addingTimeInterval(TimeInterval(Subject.lectureModeMaxSeconds - 1))
        XCTAssertFalse(engine.lectureCapReached)
        now = now.addingTimeInterval(2)
        XCTAssertTrue(engine.lectureCapReached)
    }

    func testNonLectureSubjectNeverHitsCap() throws {
        let engine = makeEngine()
        _ = try engine.start(subject: makeSubject(lecture: false))
        now = now.addingTimeInterval(TimeInterval(Subject.lectureModeMaxSeconds + 1000))
        XCTAssertFalse(engine.lectureCapReached)
    }

    func testCanStartFreshSessionAfterEnd() throws {
        let engine = makeEngine()
        _ = try engine.start(subject: makeSubject())
        now = now.addingTimeInterval(30)
        _ = try engine.end()
        XCTAssertEqual(engine.state, .ended)

        let second = try engine.start(subject: makeSubject())
        XCTAssertEqual(engine.state, .running)
        XCTAssertEqual(second.startedAt, now)
    }

    func testPauseRequiresRunning() throws {
        let engine = makeEngine()
        XCTAssertThrowsError(try engine.pause(reason: .userManual)) {
            XCTAssertEqual($0 as? TimerError, .notRunning)
        }
    }

    func testResumeRequiresPaused() throws {
        let engine = makeEngine()
        _ = try engine.start(subject: makeSubject())
        XCTAssertThrowsError(try engine.resume()) {
            XCTAssertEqual($0 as? TimerError, .notPaused)
        }
    }
}
