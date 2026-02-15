import Foundation
import EventKit
import Core

public struct RecurrenceExpansion {
    public struct Instance {
        public let instanceStart: Date
        public let instanceEnd: Date
    }

    // Legacy SessionEntity overload restored for internal Data usage
    public static func expandInstances(
        for entity: SessionEntity,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [Instance] {
        expandInstances(
            isAllDay: entity.isAllDay,
            rule: rule,
            masterStartTime: masterStartTime,
            masterEndTime: masterEndTime,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
    }

    /// Expands a recurring session into all instances within the given date range.
    /// Overload for Session domain model.
    public static func expandInstances(
        for templateSession: Session,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [Instance] {
        expandInstances(
            isAllDay: templateSession.isAllDay,
            rule: rule,
            masterStartTime: masterStartTime,
            masterEndTime: masterEndTime,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
    }

    /// Internal implementation that only needs `isAllDay`.
    private static func expandInstances(
        isAllDay: Bool,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [Instance] {
        guard rangeStart < rangeEnd, masterEndTime >= masterStartTime else { return [] }
        let duration = masterEndTime.timeIntervalSince(masterStartTime)

        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *),
           let foundationRule = makeFoundationRule(from: rule, calendar: Calendar.current) {
            let recurrenceRange = rangeStart..<rangeEnd
            let recurrenceSequence = foundationRule.recurrences(of: masterStartTime, in: recurrenceRange)

            return recurrenceSequence.compactMap { start in
                let end = start.addingTimeInterval(duration)
                guard overlaps(
                    instanceStart: start,
                    instanceEnd: end,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd
                ) else {
                    return nil
                }
                return Instance(instanceStart: start, instanceEnd: end)
            }
        }

        return expandInstancesLegacy(
            isAllDay: isAllDay,
            rule: rule,
            masterStartTime: masterStartTime,
            masterEndTime: masterEndTime,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
    }

    private static func overlaps(
        instanceStart: Date,
        instanceEnd: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> Bool {
        instanceStart < rangeEnd && instanceEnd > rangeStart
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    private static func makeFoundationRule(
        from ekRule: EKRecurrenceRule,
        calendar: Calendar
    ) -> Calendar.RecurrenceRule? {
        let frequency: Calendar.RecurrenceRule.Frequency
        switch ekRule.frequency {
        case .daily:
            frequency = .daily
        case .weekly:
            frequency = .weekly
        case .monthly:
            frequency = .monthly
        case .yearly:
            frequency = .yearly
        @unknown default:
            return nil
        }

        let end: Calendar.RecurrenceRule.End
        if let recurrenceEnd = ekRule.recurrenceEnd {
            if recurrenceEnd.occurrenceCount > 0 {
                end = .afterOccurrences(recurrenceEnd.occurrenceCount)
            } else if let endDate = recurrenceEnd.endDate {
                end = .afterDate(endDate)
            } else {
                end = .never
            }
        } else {
            end = .never
        }

        let weekdays = (ekRule.daysOfTheWeek ?? []).compactMap { day -> Calendar.RecurrenceRule.Weekday? in
            guard let weekday = localeWeekday(from: day.dayOfTheWeek) else { return nil }
            if day.weekNumber == 0 {
                return .every(weekday)
            }
            return .nth(day.weekNumber, weekday)
        }

        let months = (ekRule.monthsOfTheYear ?? []).compactMap { month -> Calendar.RecurrenceRule.Month? in
            let index = month.intValue
            guard (1...12).contains(index) else { return nil }
            return Calendar.RecurrenceRule.Month(index)
        }

        return Calendar.RecurrenceRule(
            calendar: calendar,
            frequency: frequency,
            interval: max(ekRule.interval, 1),
            end: end,
            matchingPolicy: .nextTimePreservingSmallerComponents,
            repeatedTimePolicy: .first,
            months: months,
            daysOfTheYear: ekRule.daysOfTheYear?.map(\.intValue) ?? [],
            daysOfTheMonth: ekRule.daysOfTheMonth?.map(\.intValue) ?? [],
            weeks: ekRule.weeksOfTheYear?.map(\.intValue) ?? [],
            weekdays: weekdays,
            hours: [],
            minutes: [],
            seconds: [],
            setPositions: ekRule.setPositions?.map(\.intValue) ?? []
        )
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    private static func localeWeekday(from weekday: EKWeekday) -> Locale.Weekday? {
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

    // MARK: - Legacy fallback expansion

    private static func expandInstancesLegacy(
        isAllDay: Bool,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [Instance] {
        if rule.frequency == .weekly,
           let daysOfTheWeek = rule.daysOfTheWeek,
           !daysOfTheWeek.isEmpty {
            return expandWeeklyInstancesLegacy(
                isAllDay: isAllDay,
                rule: rule,
                masterStartTime: masterStartTime,
                masterEndTime: masterEndTime,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd
            )
        }

        var instances: [Instance] = []
        let calendar = Calendar.current
        let masterDuration = masterEndTime.timeIntervalSince(masterStartTime)
        let recurrenceActualEndDate = rule.recurrenceEnd?.endDate
        let maxIterations = 2000
        var currentIteration = 0
        var matchedOccurrences = 0
        var iterationDate = masterStartTime

        while currentIteration < maxIterations {
            if let ruleEndDate = recurrenceActualEndDate, iterationDate > ruleEndDate {
                break
            }
            if let ruleEndCount = rule.recurrenceEnd?.occurrenceCount,
               ruleEndCount > 0,
               matchedOccurrences >= ruleEndCount {
                break
            }

            if matchesRule(
                date: iterationDate,
                rule: rule,
                masterStartTime: masterStartTime,
                calendar: calendar,
                templateIsAllDay: isAllDay
            ) {
                var finalInstanceStartDate = iterationDate
                if !isAllDay {
                    let masterTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: masterStartTime)
                    finalInstanceStartDate = calendar.date(
                        bySettingHour: masterTimeComponents.hour ?? 0,
                        minute: masterTimeComponents.minute ?? 0,
                        second: masterTimeComponents.second ?? 0,
                        of: iterationDate
                    ) ?? iterationDate
                }

                let instanceEndDate = finalInstanceStartDate.addingTimeInterval(masterDuration)
                if overlaps(
                    instanceStart: finalInstanceStartDate,
                    instanceEnd: instanceEndDate,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd
                ) {
                    instances.append(Instance(instanceStart: finalInstanceStartDate, instanceEnd: instanceEndDate))
                }
                matchedOccurrences += 1
            }

            let interval = max(rule.interval, 1)
            let nextDateOpt: Date?
            switch rule.frequency {
            case .daily:
                nextDateOpt = calendar.date(byAdding: .day, value: interval, to: iterationDate)
            case .weekly:
                nextDateOpt = calendar.date(byAdding: .weekOfYear, value: interval, to: iterationDate)
            case .monthly:
                nextDateOpt = calendar.date(byAdding: .month, value: interval, to: iterationDate)
            case .yearly:
                nextDateOpt = calendar.date(byAdding: .year, value: interval, to: iterationDate)
            @unknown default:
                return instances
            }

            guard let nextDate = nextDateOpt else { break }
            if nextDate <= iterationDate { break }
            if nextDate > rangeEnd { break }

            iterationDate = nextDate
            currentIteration += 1
        }

        return instances
    }

    private static func expandWeeklyInstancesLegacy(
        isAllDay: Bool,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [Instance] {
        var instances: [Instance] = []
        let calendar = Calendar.current
        let masterDuration = masterEndTime.timeIntervalSince(masterStartTime)
        let recurrenceActualEndDate = rule.recurrenceEnd?.endDate
        let recurrenceMaxCount = rule.recurrenceEnd?.occurrenceCount ?? 0
        let maxIterations = 2000
        var currentIteration = 0
        var matchedOccurrences = 0

        let weekdays = (rule.daysOfTheWeek ?? [])
            .map { $0.dayOfTheWeek.rawValue }
            .sorted()
        guard !weekdays.isEmpty else { return [] }

        let interval = max(rule.interval, 1)
        let masterWeekStart = startOfWeek(for: masterStartTime, calendar: calendar)
        var currentWeekStart = masterWeekStart

        while currentIteration < maxIterations {
            if let ruleEndDate = recurrenceActualEndDate, currentWeekStart > ruleEndDate {
                break
            }
            if recurrenceMaxCount > 0, matchedOccurrences >= recurrenceMaxCount {
                break
            }

            for weekday in weekdays {
                if recurrenceMaxCount > 0, matchedOccurrences >= recurrenceMaxCount {
                    break
                }

                guard let dayInWeek = dateInWeek(
                    weekStart: currentWeekStart,
                    targetWeekday: weekday,
                    calendar: calendar
                ) else {
                    continue
                }

                let occurrenceStart: Date
                if isAllDay {
                    occurrenceStart = calendar.startOfDay(for: dayInWeek)
                } else {
                    occurrenceStart = dateByCombining(
                        day: dayInWeek,
                        timeSource: masterStartTime,
                        calendar: calendar
                    )
                }

                if occurrenceStart < masterStartTime {
                    continue
                }
                if let ruleEndDate = recurrenceActualEndDate, occurrenceStart > ruleEndDate {
                    continue
                }

                matchedOccurrences += 1
                let occurrenceEnd = occurrenceStart.addingTimeInterval(masterDuration)
                if overlaps(
                    instanceStart: occurrenceStart,
                    instanceEnd: occurrenceEnd,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd
                ) {
                    instances.append(Instance(instanceStart: occurrenceStart, instanceEnd: occurrenceEnd))
                }
            }

            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: interval, to: currentWeekStart),
                  nextWeek > currentWeekStart else {
                break
            }

            if nextWeek > rangeEnd && recurrenceMaxCount <= 0 {
                break
            }

            currentWeekStart = nextWeek
            currentIteration += 1
        }

        return instances
    }

    private static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: startOfDay) ?? startOfDay
    }

    private static func dateInWeek(
        weekStart: Date,
        targetWeekday: Int,
        calendar: Calendar
    ) -> Date? {
        let weekStartWeekday = calendar.component(.weekday, from: weekStart)
        let offset = (targetWeekday - weekStartWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: offset, to: weekStart)
    }

    private static func dateByCombining(
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

    private static func matchesRule(
        date: Date,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        calendar: Calendar,
        templateIsAllDay _: Bool
    ) -> Bool {
        // Check months.
        if let months = rule.monthsOfTheYear, !months.isEmpty {
            let currentMonth = calendar.component(.month, from: date)
            if !months.contains(where: { $0.intValue == currentMonth }) {
                return false
            }
        }

        // Weekly.
        if rule.frequency == .weekly {
            if let days = rule.daysOfTheWeek, !days.isEmpty {
                let currentWeekday = calendar.component(.weekday, from: date)
                if !days.contains(where: { $0.dayOfTheWeek.rawValue == currentWeekday }) {
                    return false
                }
            } else if calendar.component(.weekday, from: date) != calendar.component(.weekday, from: masterStartTime) {
                return false
            }
        }

        // Monthly.
        if rule.frequency == .monthly {
            if let days = rule.daysOfTheMonth, !days.isEmpty {
                let currentDay = calendar.component(.day, from: date)
                if !days.contains(where: { $0.intValue == currentDay }) {
                    return false
                }
            }
        }

        // Yearly.
        if rule.frequency == .yearly {
            if let days = rule.daysOfTheYear, !days.isEmpty {
                let currentDayOfYear = calendar.ordinality(of: .day, in: .year, for: date)
                if let currentDayOfYear,
                   !days.contains(where: { $0.intValue == currentDayOfYear }) {
                    return false
                }
            }
        }

        // Set positions (for ordinal rules).
        if !checkSetPositionMatch(date: date, rule: rule, calendar: calendar) {
            return false
        }

        return true
    }

    private static func checkSetPositionMatch(date: Date, rule: EKRecurrenceRule, calendar: Calendar) -> Bool {
        guard let daysOfTheWeek = rule.daysOfTheWeek, !daysOfTheWeek.isEmpty,
              let setPositions = rule.setPositions, !setPositions.isEmpty else {
            return true
        }
        let targetWeekdayComponent = calendar.component(.weekday, from: date)
        guard daysOfTheWeek.contains(where: { $0.dayOfTheWeek.rawValue == targetWeekdayComponent }) else {
            return false
        }
        let yearMonth = calendar.dateComponents([.year, .month], from: date)
        let startOfMonth = calendar.date(from: yearMonth)!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        var weekdayInstancesInMonth: [Date] = []
        for dayOffset in 0..<range.count {
            let testDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfMonth)!
            if calendar.component(.weekday, from: testDate) == daysOfTheWeek.first!.dayOfTheWeek.rawValue {
                weekdayInstancesInMonth.append(testDate)
            }
        }
        if weekdayInstancesInMonth.isEmpty { return false }
        for pos in setPositions {
            let position = pos.intValue
            if position > 0 && position <= weekdayInstancesInMonth.count {
                if calendar.isDate(weekdayInstancesInMonth[position - 1], inSameDayAs: date) {
                    return true
                }
            } else if position < 0 {
                let indexFromEnd = weekdayInstancesInMonth.count + position
                if indexFromEnd >= 0 && indexFromEnd < weekdayInstancesInMonth.count {
                    if calendar.isDate(weekdayInstancesInMonth[indexFromEnd], inSameDayAs: date) {
                        return true
                    }
                }
            }
        }
        return false
    }
}
