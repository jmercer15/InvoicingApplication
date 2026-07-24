@testable import Data
import Core
import Foundation
import XCTest

final class EventKitAliasSetTests: XCTestCase {
    func testAliasMergeDeduplicatesAndNormalizes() {
        var aliases = EventKitAliasSet()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = makeDate(
            year: 2026,
            month: 2,
            day: 17,
            hour: 10,
            minute: 15,
            second: 10,
            calendar: calendar
        )

        aliases.merge(
            eventIdentifier: " evt-1 ",
            externalIdentifier: " ext-1 ",
            calendarIdentifier: " cal-1 ",
            sourceIdentifier: " src-1 ",
            occurrenceDate: anchor,
            token: " tok-1 ",
            isAllDay: false
        )

        aliases.merge(
            eventIdentifier: "evt-1",
            externalIdentifier: "ext-1",
            calendarIdentifier: "cal-1",
            sourceIdentifier: "src-1",
            occurrenceDate: anchor.addingTimeInterval(30), // same minute
            token: "tok-1",
            isAllDay: false
        )

        XCTAssertEqual(aliases.eventIdentifiers, ["evt-1"])
        XCTAssertEqual(aliases.externalIdentifiers, ["ext-1"])
        XCTAssertEqual(aliases.calendarIdentifiers, ["cal-1"])
        XCTAssertEqual(aliases.sourceIdentifiers, ["src-1"])
        XCTAssertEqual(aliases.occurrenceAnchors.count, 1)
        XCTAssertEqual(aliases.token, "tok-1")
    }

    func testDisambiguationRankingPrefersStrongestCandidate() {
        var aliases = EventKitAliasSet()
        let anchor = Date(timeIntervalSinceReferenceDate: 20_000)
        aliases.merge(
            eventIdentifier: "evt-1",
            externalIdentifier: "ext-1",
            calendarIdentifier: "cal-1",
            sourceIdentifier: "src-1",
            occurrenceDate: anchor,
            token: "tok",
            isAllDay: false
        )

        let candidates = [
            EventKitAliasCandidate(
                eventIdentifier: nil,
                externalIdentifier: "ext-1",
                calendarIdentifier: nil,
                sourceIdentifier: nil,
                occurrenceDate: nil,
                startDate: anchor
            ),
            EventKitAliasCandidate(
                eventIdentifier: "evt-1",
                externalIdentifier: "ext-1",
                calendarIdentifier: "cal-1",
                sourceIdentifier: "src-1",
                occurrenceDate: anchor,
                startDate: nil
            ),
            EventKitAliasCandidate(
                eventIdentifier: nil,
                externalIdentifier: nil,
                calendarIdentifier: "cal-1",
                sourceIdentifier: "src-1",
                occurrenceDate: nil,
                startDate: nil
            )
        ]

        let bestIndex = aliases.bestCandidateIndex(in: candidates, isAllDay: false)
        XCTAssertEqual(bestIndex, 1)
    }

    func testRecurrenceOccurrenceKeyBehavior() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let timedA = makeDate(year: 2026, month: 2, day: 17, hour: 10, minute: 15, second: 10, calendar: calendar)
        let timedB = makeDate(year: 2026, month: 2, day: 17, hour: 10, minute: 15, second: 55, calendar: calendar)
        let timedKeyA = EventKitAliasSet.recurrenceOccurrenceKey(
            externalIdentifier: "ext-1",
            calendarIdentifier: "cal-1",
            occurrenceDate: timedA,
            isAllDay: false,
            calendar: calendar
        )
        let timedKeyB = EventKitAliasSet.recurrenceOccurrenceKey(
            externalIdentifier: "ext-1",
            calendarIdentifier: "cal-1",
            occurrenceDate: timedB,
            isAllDay: false,
            calendar: calendar
        )
        XCTAssertEqual(timedKeyA, timedKeyB)

        let allDayA = makeDate(year: 2026, month: 2, day: 17, hour: 1, minute: 0, second: 0, calendar: calendar)
        let allDayB = makeDate(year: 2026, month: 2, day: 17, hour: 23, minute: 59, second: 59, calendar: calendar)
        let allDayKeyA = EventKitAliasSet.recurrenceOccurrenceKey(
            externalIdentifier: "ext-1",
            calendarIdentifier: "cal-1",
            occurrenceDate: allDayA,
            isAllDay: true,
            calendar: calendar
        )
        let allDayKeyB = EventKitAliasSet.recurrenceOccurrenceKey(
            externalIdentifier: "ext-1",
            calendarIdentifier: "cal-1",
            occurrenceDate: allDayB,
            isAllDay: true,
            calendar: calendar
        )
        XCTAssertEqual(allDayKeyA, allDayKeyB)
    }

    func testDisambiguationPrefersTokenConfirmedCandidate() {
        var aliases = EventKitAliasSet()
        aliases.merge(
            eventIdentifier: nil,
            externalIdentifier: "ext-1",
            calendarIdentifier: "cal-1",
            sourceIdentifier: "src-1",
            occurrenceDate: Date(timeIntervalSinceReferenceDate: 50_000),
            token: "tok-123",
            isAllDay: false
        )

        let candidates = [
            EventKitAliasCandidate(
                eventIdentifier: nil,
                externalIdentifier: "ext-1",
                calendarIdentifier: "cal-1",
                sourceIdentifier: "src-1",
                token: nil,
                occurrenceDate: nil,
                startDate: Date(timeIntervalSinceReferenceDate: 50_000)
            ),
            EventKitAliasCandidate(
                eventIdentifier: nil,
                externalIdentifier: "ext-1",
                calendarIdentifier: "cal-1",
                sourceIdentifier: "src-1",
                token: "tok-123",
                occurrenceDate: nil,
                startDate: Date(timeIntervalSinceReferenceDate: 50_000)
            )
        ]

        let bestIndex = aliases.bestCandidateIndex(in: candidates, isAllDay: false)
        XCTAssertEqual(bestIndex, 1)
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
        calendar: Calendar
    ) -> Date {
        let components = DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
        return calendar.date(from: components)!
    }
}
