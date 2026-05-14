// PlannerCalendarTests — cutoff hour, slot index, and slot enumeration.

import XCTest
@testable import StudyCore

final class PlannerCalendarTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ hh: Int, _ mm: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        comps.hour = hh; comps.minute = mm
        return calendar.date(from: comps)!
    }

    func testPlannerDayBeforeCutoffBelongsToPreviousDay() {
        let pc = PlannerCalendar(cutoffHour: 3, calendar: calendar)
        XCTAssertEqual(pc.plannerDay(for: date(2026, 5, 14, 2, 30)), 20260513)
    }

    func testPlannerDayAtCutoffBelongsToNewDay() {
        let pc = PlannerCalendar(cutoffHour: 3, calendar: calendar)
        XCTAssertEqual(pc.plannerDay(for: date(2026, 5, 14, 3, 0)), 20260514)
    }

    func testPlannerDayLateAfternoon() {
        let pc = PlannerCalendar(cutoffHour: 3, calendar: calendar)
        XCTAssertEqual(pc.plannerDay(for: date(2026, 5, 13, 22, 0)), 20260513)
    }

    func testSlotIndexBoundaries() {
        let pc = PlannerCalendar(cutoffHour: 3, calendar: calendar)
        XCTAssertEqual(pc.slotIndex(for: date(2026, 5, 13, 0, 0)), 0)
        XCTAssertEqual(pc.slotIndex(for: date(2026, 5, 13, 0, 9)), 0)
        XCTAssertEqual(pc.slotIndex(for: date(2026, 5, 13, 0, 10)), 1)
        XCTAssertEqual(pc.slotIndex(for: date(2026, 5, 13, 23, 50)), 143)
        XCTAssertEqual(pc.slotIndex(for: date(2026, 5, 13, 23, 59)), 143)
    }

    func testStartOfSlotTruncates() {
        let pc = PlannerCalendar(cutoffHour: 3, calendar: calendar)
        let truncated = pc.startOfSlot(containing: date(2026, 5, 13, 14, 37))
        XCTAssertEqual(pc.slotIndex(for: truncated), 14 * 6 + 3) // 14:30 → idx 87
        XCTAssertEqual(calendar.component(.minute, from: truncated), 30)
        XCTAssertEqual(calendar.component(.second, from: truncated), 0)
    }

    func testSlotsForSessionCovers30MinuteRun() {
        let pc = PlannerCalendar(cutoffHour: 3, calendar: calendar)
        let s = StudySession(
            subjectID: UUID(),
            startedAt: date(2026, 5, 13, 14, 0),
            endedAt: date(2026, 5, 13, 14, 30),
            totalSeconds: 30 * 60,
            plannerDay: 20260513
        )
        let slots = pc.slots(for: s)
        XCTAssertEqual(slots.count, 3)
        XCTAssertEqual(slots.map { $0.slotIndex }, [84, 85, 86]) // 14:00, 14:10, 14:20
    }

    func testSlotsCoverPartialSlotAtEnd() {
        // 14:05 → 14:35 spans four slot buckets even though the run is 30 min.
        let pc = PlannerCalendar(cutoffHour: 3, calendar: calendar)
        let s = StudySession(
            subjectID: UUID(),
            startedAt: date(2026, 5, 13, 14, 5),
            endedAt: date(2026, 5, 13, 14, 35),
            totalSeconds: 30 * 60,
            plannerDay: 20260513
        )
        let slots = pc.slots(for: s)
        XCTAssertEqual(slots.map { $0.slotIndex }, [84, 85, 86, 87])
    }

    func testSlotsSkipFullPause() {
        let pc = PlannerCalendar(cutoffHour: 3, calendar: calendar)
        let pause = PausedRange(
            start: date(2026, 5, 13, 14, 10),
            end: date(2026, 5, 13, 14, 20),
            reason: .userManual
        )
        let s = StudySession(
            subjectID: UUID(),
            startedAt: date(2026, 5, 13, 14, 0),
            endedAt: date(2026, 5, 13, 14, 30),
            totalSeconds: 20 * 60,
            plannerDay: 20260513,
            pausedRanges: [pause]
        )
        let slots = pc.slots(for: s)
        XCTAssertEqual(slots.map { $0.slotIndex }, [84, 86]) // 14:10 slot skipped
    }
}
