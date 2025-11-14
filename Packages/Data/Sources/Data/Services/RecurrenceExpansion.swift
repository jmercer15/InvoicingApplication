import Foundation
import EventKit
import Core

public struct RecurrenceExpansion {
    public struct Instance {
        public let instanceStart: Date
        public let instanceEnd: Date
    }

    /// Expands a recurring session into all instances within the given date range.
    /// Overload for SessionEntity (legacy, kept for backward compatibility)
    public static func expandInstances(
        for templateSession: SessionEntity,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [Instance] {
        return expandInstances(
            isAllDay: templateSession.isAllDay,
            rule: rule,
            masterStartTime: masterStartTime,
            masterEndTime: masterEndTime,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
    }
    
    /// Expands a recurring session into all instances within the given date range.
    /// Overload for Session domain model
    public static func expandInstances(
        for templateSession: Session,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [Instance] {
        return expandInstances(
            isAllDay: templateSession.isAllDay,
            rule: rule,
            masterStartTime: masterStartTime,
            masterEndTime: masterEndTime,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
    }
    
    /// Internal implementation that only needs isAllDay
    private static func expandInstances(
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
        let maxIterations = 500 // Safety limit
        var currentIteration = 0
        var occurrenceCountSinceMaster = 0
        var iterationDate = masterStartTime // Always start at masterStartTime
        while currentIteration < maxIterations {
            if let ruleEndDate = recurrenceActualEndDate, iterationDate > ruleEndDate {
                break
            }
            if let ruleEndCount = rule.recurrenceEnd?.occurrenceCount, ruleEndCount > 0 && occurrenceCountSinceMaster >= ruleEndCount {
                break
            }
            if matchesRule(date: iterationDate, rule: rule, masterStartTime: masterStartTime, calendar: calendar, templateIsAllDay: isAllDay) {
                let instanceStartDate = iterationDate
                var finalInstanceStartDate = instanceStartDate
                if !isAllDay {
                    let masterTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: masterStartTime)
                    finalInstanceStartDate = calendar.date(bySettingHour: masterTimeComponents.hour ?? 0,
                                                           minute: masterTimeComponents.minute ?? 0,
                                                           second: masterTimeComponents.second ?? 0,
                                                           of: instanceStartDate) ?? instanceStartDate
                }
                let instanceEndDate = finalInstanceStartDate.addingTimeInterval(masterDuration)
                // Only add if this instance occurs within the range
                if finalInstanceStartDate >= rangeStart && finalInstanceStartDate < rangeEnd {
                    instances.append(Instance(instanceStart: finalInstanceStartDate, instanceEnd: instanceEndDate))
                }
            }
            occurrenceCountSinceMaster += 1
            // Advance iterationDate based on the rule's frequency and interval
            let interval = rule.interval > 0 ? rule.interval : 1
            var nextDateOpt: Date?
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
                currentIteration = maxIterations
            }
            guard let nextDate = nextDateOpt else { break }
            if nextDate > rangeEnd { break } // Stop if next occurrence is after the range
            if let ruleEndDate = recurrenceActualEndDate, nextDate > ruleEndDate { break }
            if nextDate <= iterationDate { break }
            iterationDate = nextDate
            currentIteration += 1
        }
        return instances
    }

    private static func matchesRule(date: Date, rule: EKRecurrenceRule, masterStartTime: Date, calendar: Calendar, templateIsAllDay: Bool) -> Bool {
        // Check months
        if let months = rule.monthsOfTheYear, !months.isEmpty {
            let currentMonth = calendar.component(.month, from: date)
            if !months.contains(where: { $0.intValue == currentMonth }) {
                return false
            }
        }
        // Weekly
        if rule.frequency == .weekly {
            if let days = rule.daysOfTheWeek, !days.isEmpty {
                let currentWeekday = calendar.component(.weekday, from: date)
                if !days.contains(where: { $0.dayOfTheWeek.rawValue == currentWeekday }) {
                    return false
                }
            } else {
                if calendar.component(.weekday, from: date) != calendar.component(.weekday, from: masterStartTime) {
                    return false
                }
            }
        }
        // Monthly
        if rule.frequency == .monthly {
            if let days = rule.daysOfTheMonth, !days.isEmpty {
                let currentDay = calendar.component(.day, from: date)
                if !days.contains(where: { $0.intValue == currentDay }) {
                    return false
                }
            }
        }
        // Yearly
        if rule.frequency == .yearly {
            if let days = rule.daysOfTheYear, !days.isEmpty {
                let currentDayOfYear = calendar.ordinality(of: .day, in: .year, for: date)
                if let currentDayOfYear = currentDayOfYear, !days.contains(where: { $0.intValue == currentDayOfYear }) {
                    return false
                }
            }
        }
        // Set positions (for ordinal rules)
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