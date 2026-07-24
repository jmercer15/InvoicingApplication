import EventKit
import Foundation

extension RecurrenceExpansion {
    
    internal struct LegacyExpansionState {
        var currentIteration: Int = 0
        var matchedOccurrences: Int = 0
        var iterationDate: Date
    }

    internal static func expandInstancesLegacy(
        isAllDay: Bool,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [Instance] {
        if shouldUseWeeklyLegacyPath(for: rule) {
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
        var state = LegacyExpansionState(iterationDate: masterStartTime)

        while shouldContinueLegacyExpansion(
            state: state,
            rule: rule,
            recurrenceActualEndDate: recurrenceActualEndDate,
            maxIterations: maxIterations
        ) {
            if let occurrenceStart = legacyOccurrenceStartIfMatching(
                iterationDate: state.iterationDate,
                rule: rule,
                masterStartTime: masterStartTime,
                calendar: calendar,
                isAllDay: isAllDay
            ) {
                let instanceEndDate = occurrenceStart.addingTimeInterval(masterDuration)
                if overlaps(
                    instanceStart: occurrenceStart,
                    instanceEnd: instanceEndDate,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd
                ) {
                    instances.append(Instance(instanceStart: occurrenceStart, instanceEnd: instanceEndDate))
                }
                state.matchedOccurrences += 1
            }

            guard let nextDate = nextLegacyIterationDate(
                from: state.iterationDate,
                rule: rule,
                calendar: calendar,
                rangeEnd: rangeEnd
            ) else { break }
            state.iterationDate = nextDate
            state.currentIteration += 1
        }

        return instances
    }

    internal static func shouldContinueLegacyExpansion(
        state: LegacyExpansionState,
        rule: EKRecurrenceRule,
        recurrenceActualEndDate: Date?,
        maxIterations: Int
    ) -> Bool {
        guard state.currentIteration < maxIterations else { return false }
        if let ruleEndDate = recurrenceActualEndDate, state.iterationDate > ruleEndDate {
            return false
        }
        if let ruleEndCount = rule.recurrenceEnd?.occurrenceCount,
           ruleEndCount > 0,
           state.matchedOccurrences >= ruleEndCount {
            return false
        }
        return true
    }

    internal static func legacyOccurrenceStartIfMatching(
        iterationDate: Date,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        calendar: Calendar,
        isAllDay: Bool
    ) -> Date? {
        guard matchesRule(
            date: iterationDate,
            rule: rule,
            masterStartTime: masterStartTime,
            calendar: calendar,
            templateIsAllDay: isAllDay
        ) else {
            return nil
        }
        if isAllDay {
            return iterationDate
        }
        let masterTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: masterStartTime)
        return calendar.date(
            bySettingHour: masterTimeComponents.hour ?? 0,
            minute: masterTimeComponents.minute ?? 0,
            second: masterTimeComponents.second ?? 0,
            of: iterationDate
        ) ?? iterationDate
    }

    internal static func nextLegacyIterationDate(
        from date: Date,
        rule: EKRecurrenceRule,
        calendar: Calendar,
        rangeEnd: Date
    ) -> Date? {
        let interval = max(rule.interval, 1)
        let nextDateOpt: Date?
        switch rule.frequency {
        case .daily:
            nextDateOpt = calendar.date(byAdding: .day, value: interval, to: date)
        case .weekly:
            nextDateOpt = calendar.date(byAdding: .weekOfYear, value: interval, to: date)
        case .monthly:
            nextDateOpt = calendar.date(byAdding: .month, value: interval, to: date)
        case .yearly:
            nextDateOpt = calendar.date(byAdding: .year, value: interval, to: date)
        @unknown default:
            return nil
        }
        guard let nextDate = nextDateOpt, nextDate > date, nextDate <= rangeEnd else {
            return nil
        }
        return nextDate
    }

    internal static func matchesRule(
        date: Date,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        calendar: Calendar,
        templateIsAllDay _: Bool
    ) -> Bool {
        guard
            matchesMonthRule(date: date, rule: rule, calendar: calendar),
            matchesWeeklyRule(date: date, rule: rule, masterStartTime: masterStartTime, calendar: calendar),
            matchesMonthlyRule(date: date, rule: rule, calendar: calendar),
            matchesYearlyRule(date: date, rule: rule, calendar: calendar),
            checkSetPositionMatch(date: date, rule: rule, calendar: calendar)
        else {
            return false
        }
        return true
    }

    internal static func matchesMonthRule(date: Date, rule: EKRecurrenceRule, calendar: Calendar) -> Bool {
        guard let months = rule.monthsOfTheYear, !months.isEmpty else { return true }
        let currentMonth = calendar.component(.month, from: date)
        return months.contains(where: { $0.intValue == currentMonth })
    }

    internal static func matchesWeeklyRule(
        date: Date,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        calendar: Calendar
    ) -> Bool {
        guard rule.frequency == .weekly else { return true }
        if let days = rule.daysOfTheWeek, !days.isEmpty {
            let currentWeekday = calendar.component(.weekday, from: date)
            return days.contains(where: { $0.dayOfTheWeek.rawValue == currentWeekday })
        }
        return calendar.component(.weekday, from: date) == calendar.component(.weekday, from: masterStartTime)
    }

    internal static func matchesMonthlyRule(date: Date, rule: EKRecurrenceRule, calendar: Calendar) -> Bool {
        guard rule.frequency == .monthly else { return true }
        guard let days = rule.daysOfTheMonth, !days.isEmpty else { return true }
        let currentDay = calendar.component(.day, from: date)
        return days.contains(where: { $0.intValue == currentDay })
    }

    internal static func matchesYearlyRule(date: Date, rule: EKRecurrenceRule, calendar: Calendar) -> Bool {
        guard rule.frequency == .yearly else { return true }
        guard let days = rule.daysOfTheYear, !days.isEmpty else { return true }
        guard let currentDayOfYear = calendar.ordinality(of: .day, in: .year, for: date) else { return false }
        return days.contains(where: { $0.intValue == currentDayOfYear })
    }

    internal static func checkSetPositionMatch(date: Date, rule: EKRecurrenceRule, calendar: Calendar) -> Bool {
        guard let daysOfTheWeek = rule.daysOfTheWeek, !daysOfTheWeek.isEmpty,
              let setPositions = rule.setPositions, !setPositions.isEmpty else {
            return true
        }

        let targetWeekdayComponent = calendar.component(.weekday, from: date)
        guard daysOfTheWeek.contains(where: { $0.dayOfTheWeek.rawValue == targetWeekdayComponent }) else {
            return false
        }

        guard let targetWeekday = daysOfTheWeek.first?.dayOfTheWeek.rawValue,
              let startOfMonth = monthStart(for: date, calendar: calendar),
              let weekdayInstancesInMonth = weekdayInstancesInMonth(
                  startOfMonth: startOfMonth,
                  targetWeekday: targetWeekday,
                  calendar: calendar
              ),
              !weekdayInstancesInMonth.isEmpty else {
            return false
        }

        for position in setPositions.map(\.intValue) {
            if setPositionMatches(
                position,
                date: date,
                weekdayInstancesInMonth: weekdayInstancesInMonth,
                calendar: calendar
            ) {
                return true
            }
        }
        return false
    }

    internal static func monthStart(for date: Date, calendar: Calendar) -> Date? {
        let yearMonth = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: yearMonth)
    }

    internal static func weekdayInstancesInMonth(
        startOfMonth: Date,
        targetWeekday: Int,
        calendar: Calendar
    ) -> [Date]? {
        guard let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return nil
        }
        var instances: [Date] = []
        for dayOffset in 0..<range.count {
            guard let testDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfMonth) else {
                continue
            }
            if calendar.component(.weekday, from: testDate) == targetWeekday {
                instances.append(testDate)
            }
        }
        return instances
    }

    internal static func setPositionMatches(
        _ position: Int,
        date: Date,
        weekdayInstancesInMonth: [Date],
        calendar: Calendar
    ) -> Bool {
        guard let index = setPositionIndex(position, count: weekdayInstancesInMonth.count) else {
            return false
        }
        return calendar.isDate(weekdayInstancesInMonth[index], inSameDayAs: date)
    }

    internal static func setPositionIndex(_ position: Int, count: Int) -> Int? {
        if position > 0, position <= count {
            return position - 1
        }
        if position < 0 {
            let indexFromEnd = count + position
            if indexFromEnd >= 0, indexFromEnd < count {
                return indexFromEnd
            }
        }
        return nil
    }
}
