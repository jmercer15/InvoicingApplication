import EventKit
import Foundation

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension RecurrenceExpansion {
    
    internal static func makeFoundationRule(
        from ekRule: EKRecurrenceRule,
        calendar: Calendar
    ) -> Calendar.RecurrenceRule? {
        guard let frequency = mapFoundationFrequency(from: ekRule.frequency) else {
            return nil
        }

        return Calendar.RecurrenceRule(
            calendar: calendar,
            frequency: frequency,
            interval: max(ekRule.interval, 1),
            end: foundationRuleEnd(from: ekRule.recurrenceEnd),
            matchingPolicy: .nextTimePreservingSmallerComponents,
            repeatedTimePolicy: .first,
            months: foundationRuleMonths(from: ekRule),
            daysOfTheYear: ekRule.daysOfTheYear?.map(\.intValue) ?? [],
            daysOfTheMonth: ekRule.daysOfTheMonth?.map(\.intValue) ?? [],
            weeks: ekRule.weeksOfTheYear?.map(\.intValue) ?? [],
            weekdays: foundationRuleWeekdays(from: ekRule),
            hours: [],
            minutes: [],
            seconds: [],
            setPositions: ekRule.setPositions?.map(\.intValue) ?? []
        )
    }

    internal static func mapFoundationFrequency(
        from frequency: EKRecurrenceFrequency
    ) -> Calendar.RecurrenceRule.Frequency? {
        switch frequency {
        case .daily:
            return .daily
        case .weekly:
            return .weekly
        case .monthly:
            return .monthly
        case .yearly:
            return .yearly
        @unknown default:
            return nil
        }
    }

    internal static func foundationRuleEnd(
        from recurrenceEnd: EKRecurrenceEnd?
    ) -> Calendar.RecurrenceRule.End {
        guard let recurrenceEnd else { return .never }
        if recurrenceEnd.occurrenceCount > 0 {
            return .afterOccurrences(recurrenceEnd.occurrenceCount)
        }
        if let endDate = recurrenceEnd.endDate {
            return .afterDate(endDate)
        }
        return .never
    }

    internal static func foundationRuleWeekdays(
        from rule: EKRecurrenceRule
    ) -> [Calendar.RecurrenceRule.Weekday] {
        (rule.daysOfTheWeek ?? []).compactMap { day in
            guard let weekday = localeWeekday(from: day.dayOfTheWeek) else { return nil }
            if day.weekNumber == 0 {
                return .every(weekday)
            }
            return .nth(day.weekNumber, weekday)
        }
    }

    internal static func foundationRuleMonths(
        from rule: EKRecurrenceRule
    ) -> [Calendar.RecurrenceRule.Month] {
        (rule.monthsOfTheYear ?? []).compactMap { month in
            let index = month.intValue
            guard (1...12).contains(index) else { return nil }
            return Calendar.RecurrenceRule.Month(index)
        }
    }

    internal static func localeWeekday(from weekday: EKWeekday) -> Locale.Weekday? {
        switch weekday {
        case .sunday:
            return .sunday
        case .monday:
            return .monday
        case .tuesday:
            return .tuesday
        case .wednesday:
            return .wednesday
        case .thursday:
            return .thursday
        case .friday:
            return .friday
        case .saturday:
            return .saturday
        @unknown default:
            return nil
        }
    }
}
