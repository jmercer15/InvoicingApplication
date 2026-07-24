import EventKit
import Foundation

extension RecurrenceExpansion {
    
    internal struct WeeklyExpansionState {
        var currentIteration: Int = 0
        var matchedOccurrences: Int = 0
        var currentWeekStart: Date
    }

    internal struct WeeklyExpansionContext {
        let isAllDay: Bool
        let recurrenceActualEndDate: Date?
        let recurrenceMaxCount: Int
        let masterStartTime: Date
        let masterDuration: TimeInterval
        let rangeStart: Date
        let rangeEnd: Date
        let calendar: Calendar
    }

    internal struct WeeklyOccurrencesResult {
        let instances: [Instance]
        let matchedOccurrencesAdded: Int
    }

    internal static func expandWeeklyInstancesLegacy(
        isAllDay: Bool,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [Instance] {
        let calendar = Calendar.current
        let weekdays = sortedWeekdays(from: rule)
        guard !weekdays.isEmpty else { return [] }

        let context = WeeklyExpansionContext(
            isAllDay: isAllDay,
            recurrenceActualEndDate: rule.recurrenceEnd?.endDate,
            recurrenceMaxCount: rule.recurrenceEnd?.occurrenceCount ?? 0,
            masterStartTime: masterStartTime,
            masterDuration: masterEndTime.timeIntervalSince(masterStartTime),
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            calendar: calendar
        )
        let maxIterations = 2000
        var state = WeeklyExpansionState(currentWeekStart: startOfWeek(for: masterStartTime, calendar: calendar))
        var instances: [Instance] = []

        while shouldContinueWeeklyExpansion(state: state, context: context, maxIterations: maxIterations) {
            let weeklyResult = weeklyOccurrencesForWeek(
                weekStart: state.currentWeekStart,
                weekdays: weekdays,
                matchedOccurrences: state.matchedOccurrences,
                context: context
            )
            instances.append(contentsOf: weeklyResult.instances)
            state.matchedOccurrences += weeklyResult.matchedOccurrencesAdded

            guard let nextWeek = nextWeeklyIterationDate(
                from: state.currentWeekStart,
                interval: max(rule.interval, 1),
                calendar: calendar
            ) else { break }
            if nextWeek > rangeEnd && context.recurrenceMaxCount <= 0 {
                break
            }
            state.currentWeekStart = nextWeek
            state.currentIteration += 1
        }

        return instances
    }

    internal static func shouldUseWeeklyLegacyPath(for rule: EKRecurrenceRule) -> Bool {
        rule.frequency == .weekly && !(rule.daysOfTheWeek ?? []).isEmpty
    }

    internal static func sortedWeekdays(from rule: EKRecurrenceRule) -> [Int] {
        (rule.daysOfTheWeek ?? [])
            .map { $0.dayOfTheWeek.rawValue }
            .sorted()
    }

    internal static func shouldContinueWeeklyExpansion(
        state: WeeklyExpansionState,
        context: WeeklyExpansionContext,
        maxIterations: Int
    ) -> Bool {
        guard state.currentIteration < maxIterations else { return false }
        if let ruleEndDate = context.recurrenceActualEndDate, state.currentWeekStart > ruleEndDate {
            return false
        }
        if context.recurrenceMaxCount > 0, state.matchedOccurrences >= context.recurrenceMaxCount {
            return false
        }
        return true
    }

    internal static func weeklyOccurrencesForWeek(
        weekStart: Date,
        weekdays: [Int],
        matchedOccurrences: Int,
        context: WeeklyExpansionContext
    ) -> WeeklyOccurrencesResult {
        var weeklyInstances: [Instance] = []
        var matchedAdded = 0
        var localMatchedOccurrences = matchedOccurrences

        for weekday in weekdays {
            if context.recurrenceMaxCount > 0, localMatchedOccurrences >= context.recurrenceMaxCount {
                break
            }

            guard let dayInWeek = dateInWeek(
                weekStart: weekStart,
                targetWeekday: weekday,
                calendar: context.calendar
            ) else { continue }

            let occurrenceStart = weeklyOccurrenceStart(
                isAllDay: context.isAllDay,
                dayInWeek: dayInWeek,
                masterStartTime: context.masterStartTime,
                calendar: context.calendar
            )
            if occurrenceStart < context.masterStartTime { continue }
            if let ruleEndDate = context.recurrenceActualEndDate, occurrenceStart > ruleEndDate { continue }

            localMatchedOccurrences += 1
            matchedAdded += 1
            let occurrenceEnd = occurrenceStart.addingTimeInterval(context.masterDuration)
            if overlaps(
                instanceStart: occurrenceStart,
                instanceEnd: occurrenceEnd,
                rangeStart: context.rangeStart,
                rangeEnd: context.rangeEnd
            ) {
                weeklyInstances.append(Instance(instanceStart: occurrenceStart, instanceEnd: occurrenceEnd))
            }
        }

        return WeeklyOccurrencesResult(
            instances: weeklyInstances,
            matchedOccurrencesAdded: matchedAdded
        )
    }

    internal static func weeklyOccurrenceStart(
        isAllDay: Bool,
        dayInWeek: Date,
        masterStartTime: Date,
        calendar: Calendar
    ) -> Date {
        if isAllDay {
            return calendar.startOfDay(for: dayInWeek)
        }
        return dateByCombining(
            day: dayInWeek,
            timeSource: masterStartTime,
            calendar: calendar
        )
    }

    internal static func nextWeeklyIterationDate(
        from weekStart: Date,
        interval: Int,
        calendar: Calendar
    ) -> Date? {
        guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: interval, to: weekStart),
              nextWeek > weekStart else {
            return nil
        }
        return nextWeek
    }

    internal static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: startOfDay) ?? startOfDay
    }

    internal static func dateInWeek(
        weekStart: Date,
        targetWeekday: Int,
        calendar: Calendar
    ) -> Date? {
        let weekStartWeekday = calendar.component(.weekday, from: weekStart)
        let offset = (targetWeekday - weekStartWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: offset, to: weekStart)
    }

    internal static func dateByCombining(
        day: Date,
        timeSource: Date,
        calendar: Calendar
    ) -> Date {
        let dayParts = calendar.dateComponents([.year, .month, .day], from: day)
        let timeParts = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: timeSource)
        var components = DateComponents()
        components.year = dayParts.year
        components.month = dayParts.month
        components.day = dayParts.day
        components.hour = timeParts.hour
        components.minute = timeParts.minute
        components.second = timeParts.second
        components.nanosecond = timeParts.nanosecond
        return calendar.date(from: components) ?? day
    }
}
