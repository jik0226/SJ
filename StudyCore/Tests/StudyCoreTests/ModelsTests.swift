// ModelsTests — value-type invariants and Codable round-trip smoke tests.

import XCTest
@testable import StudyCore

final class ModelsTests: XCTestCase {
    func testDDayCountsCalendarDaysNotHours() {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = c.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 23, minute: 30))!
        let target = c.date(from: DateComponents(year: 2026, month: 5, day: 20, hour: 0, minute: 30))!
        let d = DDay(title: "수능", targetDate: target)
        XCTAssertEqual(d.daysRemaining(from: now, calendar: c), 7)
    }

    func testDDayNegativeWhenPast() {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = c.date(from: DateComponents(year: 2026, month: 5, day: 13))!
        let target = c.date(from: DateComponents(year: 2026, month: 5, day: 10))!
        let d = DDay(title: "지난 시험", targetDate: target)
        XCTAssertEqual(d.daysRemaining(from: now, calendar: c), -3)
    }

    func testPlannerBlockCompositeKey() {
        let b = PlannerBlock(plannerDay: 20260513, slotIndex: 87)
        XCTAssertEqual(b.compositeKey, "20260513-87")
    }

    func testDailyPageClampsProgress() {
        let over = DailyPage(plannerDay: 20260513, progressPercent: 200)
        XCTAssertEqual(over.progressPercent, 100)
        let under = DailyPage(plannerDay: 20260513, progressPercent: -10)
        XCTAssertEqual(under.progressPercent, 0)
    }

    func testMascotStageClamped() {
        let m = Mascot(species: .fox, name: "Hodu", exp: 100, stage: 99)
        XCTAssertEqual(m.stage, Mascot.maxStage)
    }

    func testSubjectCodableRoundTrip() throws {
        let original = Subject(
            name: "Korean", colorHex: "#FF6B6B", sfSymbol: "book",
            allowPhoneUse: true, category: .study, dailyTargetMinutes: 120
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Subject.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testRunSessionKilometers() {
        let r = RunSession(startedAt: Date(), distanceMeters: 5300, plannerDay: 20260513)
        XCTAssertEqual(r.distanceKilometers, 5.3, accuracy: 0.001)
    }

    func testPauseRangeOpenRangeSecondsGrowsWithClock() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let pr = PausedRange(start: start, end: nil, reason: .userManual)
        XCTAssertGreaterThanOrEqual(pr.seconds, 0)
    }
}
