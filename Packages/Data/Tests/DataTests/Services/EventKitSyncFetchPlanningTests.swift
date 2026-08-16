import Foundation
import Testing
@testable import Data
import Core
import PersistenceModels

@Suite struct EventKitSyncFetchPlanningTests {
    private var calendarUTC: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    @Test func NormalizedDateRangeReturnsNilWhenEndpointsEqual() {
        let t = Date(timeIntervalSince1970: 1_728_662_400) // Arbitrary anchor
        #expect(EventKitSyncFetchPlanning.normalizedDateRange(start: t, end: t) == nil)
    }

    @Test func NormalizedDateRangeOrdersSwappedBounds() {
        let cal = calendarUTC
        let later = DateComponents(calendar: cal, year: 2026, month: 2, day: 1).date!
        let earlier = DateComponents(calendar: cal, year: 2026, month: 1, day: 1).date!

        let range = EventKitSyncFetchPlanning.normalizedDateRange(start: later, end: earlier)!
        #expect(range.0 == earlier)
        #expect(range.1 == later)
    }

    @Test func BuildSegmentsSplitsRangeByYearWindowUsingCalendar() throws {
        let cal = calendarUTC
        let start = try #require(cal.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let end = try #require(cal.date(from: DateComponents(year: 2028, month: 1, day: 1)))

        let segments = EventKitSyncFetchPlanning.buildSegments(
            start: start,
            end: end,
            maxWindowYears: 1,
            calendar: cal
        )

        #expect(segments.count == 2)

        let boundary2027 = try #require(cal.date(from: DateComponents(year: 2027, month: 1, day: 1)))

        #expect(segments[0].start == start)
        #expect(segments[0].end == boundary2027)

        #expect(segments[1].start == boundary2027)
        #expect(segments[1].end == end)
    }
}
