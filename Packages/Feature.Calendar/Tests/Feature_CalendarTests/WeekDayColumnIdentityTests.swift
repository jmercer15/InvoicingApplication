import Foundation
import Testing
@testable import Feature_Calendar

@Suite(.tags(.unit))
struct WeekDayColumnIdentityTests {
    @Test func identityStableAcrossSameCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 9))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 21))!

        let morningIdentity = WeekDayColumnIdentity(calendarDay: morning, calendar: calendar)
        let eveningIdentity = WeekDayColumnIdentity(calendarDay: evening, calendar: calendar)

        #expect(morningIdentity == eveningIdentity)
        #expect(morningIdentity.id == "2026-3-8")
    }

    @Test func resolvedDateUsesStartOfDayComponents() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let identity = WeekDayColumnIdentity(
            calendarDay: calendar.date(from: DateComponents(year: 2026, month: 7, day: 28, hour: 15))!,
            calendar: calendar)
        let resolved = identity.resolvedDate(calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: resolved)
        #expect(components.year == 2026)
        #expect(components.month == 7)
        #expect(components.day == 28)
        #expect(components.hour == 0)
    }
}
