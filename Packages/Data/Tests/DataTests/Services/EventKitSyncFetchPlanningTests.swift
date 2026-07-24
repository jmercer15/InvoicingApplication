import Foundation
import XCTest
@testable import Data
import Core

final class EventKitSyncFetchPlanningTests: XCTestCase {
    private var calendarUTC: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    func testNormalizedDateRangeReturnsNilWhenEndpointsEqual() {
        let t = Date(timeIntervalSince1970: 1_728_662_400) // Arbitrary anchor
        XCTAssertNil(EventKitSyncFetchPlanning.normalizedDateRange(start: t, end: t))
    }

    func testNormalizedDateRangeOrdersSwappedBounds() {
        let cal = calendarUTC
        let later = DateComponents(calendar: cal, year: 2026, month: 2, day: 1).date!
        let earlier = DateComponents(calendar: cal, year: 2026, month: 1, day: 1).date!

        let range = EventKitSyncFetchPlanning.normalizedDateRange(start: later, end: earlier)!
        XCTAssertEqual(range.0, earlier)
        XCTAssertEqual(range.1, later)
    }

    func testBuildSegmentsSplitsRangeByYearWindowUsingCalendar() throws {
        let cal = calendarUTC
        let start = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let end = try XCTUnwrap(cal.date(from: DateComponents(year: 2028, month: 1, day: 1)))

        let segments = EventKitSyncFetchPlanning.buildSegments(
            start: start,
            end: end,
            maxWindowYears: 1,
            calendar: cal
        )

        XCTAssertEqual(segments.count, 2)

        let boundary2027 = try XCTUnwrap(cal.date(from: DateComponents(year: 2027, month: 1, day: 1)))

        XCTAssertEqual(segments[0].start, start)
        XCTAssertEqual(segments[0].end, boundary2027)

        XCTAssertEqual(segments[1].start, boundary2027)
        XCTAssertEqual(segments[1].end, end)
    }
}
