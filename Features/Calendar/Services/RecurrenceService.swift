//
//  RecurrenceService.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Refactoring Initiative
//
import Foundation
import EventKit

/// Responsible for handling all recurrence-related logic
/// Extracted from CalendarViewModel for better separation of concerns and testability
class RecurrenceService {
    
    // MARK: - Recurrence Instance Expansion
    
    /// Expands recurring sessions into individual instances for the specified date range
    /// This is one of the most complex pieces of business logic in the application
    func expandRecurringSession(
        _ session: SessionEntity, 
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [RecurrenceExpansion.Instance] {
        
        return RecurrenceExpansion.expandInstances(
            for: session,
            rule: rule,
            masterStartTime: masterStartTime,
            masterEndTime: masterEndTime,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
    }
    
    /// Expands multiple recurring sessions efficiently
    func expandRecurringSessions(
        _ sessions: [SessionEntity],
        rangeStart: Date,
        rangeEnd: Date
    ) -> [SessionRecurrenceData] {
        
        var expandedData: [SessionRecurrenceData] = []
        
        for session in sessions {
            guard let ruleData = session.recurrenceRuleData,
                  let rule = decodeRecurrenceRule(from: ruleData),
                  let startTime = session.startTime,
                  let endTime = session.endTime else {
                continue
            }
            
            let instances = expandRecurringSession(
                session,
                rule: rule,
                masterStartTime: startTime,
                masterEndTime: endTime,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd
            )
            
            expandedData.append(SessionRecurrenceData(
                masterSession: session,
                rule: rule,
                instances: instances
            ))
            
            print("[RecurrenceService] Expanded session '\(session.title)' into \(instances.count) instances")
        }
        
        return expandedData
    }
    
    // MARK: - Recurrence Rule Utilities
    
    /// Decodes a recurrence rule from stored data
    func decodeRecurrenceRule(from data: Data?) -> EKRecurrenceRule? {
        guard let data = data else { return nil }
        return RecurrenceRuleManager.shared.deserialize(data)
    }
    
    /// Encodes a recurrence rule to data for storage
    func encodeRecurrenceRule(_ rule: EKRecurrenceRule) -> Data? {
        return RecurrenceRuleManager.shared.serialize(rule)
    }
    
    /// Validates if a recurrence rule is valid
    func validateRecurrenceRule(_ rule: EKRecurrenceRule) -> Bool {
        // Basic validation - can be expanded as needed
        return rule.interval > 0
    }
    
    // MARK: - Recurrence Modification Logic
    
    /// Creates a new recurrence rule for "this and future" modifications
    /// Truncates the original series and creates a new one starting from the specified date
    func createTruncatedRule(
        from originalRule: EKRecurrenceRule,
        endingBefore date: Date
    ) -> EKRecurrenceRule? {
        
        let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        let newRecurrenceEnd = EKRecurrenceEnd(end: dayBefore)
        
        return EKRecurrenceRule(
            recurrenceWith: originalRule.frequency,
            interval: originalRule.interval,
            daysOfTheWeek: originalRule.daysOfTheWeek,
            daysOfTheMonth: originalRule.daysOfTheMonth,
            monthsOfTheYear: originalRule.monthsOfTheYear,
            weeksOfTheYear: originalRule.weeksOfTheYear,
            daysOfTheYear: originalRule.daysOfTheYear,
            setPositions: originalRule.setPositions,
            end: newRecurrenceEnd
        )
    }
    
    /// Creates a new recurrence rule starting from a specific date
    func createNewSeriesRule(
        from originalRule: EKRecurrenceRule,
        startingFrom date: Date
    ) -> EKRecurrenceRule {
        
        // For the new series, we keep the same rule but it starts from the new date
        // The end date (if any) should be preserved from the original rule
        return EKRecurrenceRule(
            recurrenceWith: originalRule.frequency,
            interval: originalRule.interval,
            daysOfTheWeek: originalRule.daysOfTheWeek,
            daysOfTheMonth: originalRule.daysOfTheMonth,
            monthsOfTheYear: originalRule.monthsOfTheYear,
            weeksOfTheYear: originalRule.weeksOfTheYear,
            daysOfTheYear: originalRule.daysOfTheYear,
            setPositions: originalRule.setPositions,
            end: originalRule.recurrenceEnd
        )
    }
    
    // MARK: - Instance Filtering
    
    /// Filters recurrence instances based on criteria
    func filterInstances(
        _ instances: [RecurrenceExpansion.Instance],
        excludingDates: Set<Date> = [],
        onlyInDateRange: ClosedRange<Date>? = nil
    ) -> [RecurrenceExpansion.Instance] {
        
        return instances.filter { instance in
            // Exclude specific dates (e.g., for detached instances)
            if excludingDates.contains(instance.instanceStart) {
                return false
            }
            
            // Filter by date range if specified
            if let range = onlyInDateRange {
                return range.contains(instance.instanceStart)
            }
            
            return true
        }
    }
    
    // MARK: - Helper Types
    
    /// Data structure for expanded recurring session information
    struct SessionRecurrenceData {
        let masterSession: SessionEntity
        let rule: EKRecurrenceRule
        let instances: [RecurrenceExpansion.Instance]
    }
    
    // MARK: - Debug and Utilities
    
    /// Provides a human-readable description of a recurrence rule
    func describeRecurrenceRule(_ rule: EKRecurrenceRule) -> String {
        var description = ""
        
        switch rule.frequency {
        case .daily:
            description = rule.interval == 1 ? "Every day" : "Every \(rule.interval) days"
        case .weekly:
            description = rule.interval == 1 ? "Every week" : "Every \(rule.interval) weeks"
            if let daysOfWeek = rule.daysOfTheWeek, !daysOfWeek.isEmpty {
                let dayNames = daysOfWeek.map { dayOfWeek(from: $0.dayOfTheWeek) }.joined(separator: ", ")
                description += " on \(dayNames)"
            }
        case .monthly:
            description = rule.interval == 1 ? "Every month" : "Every \(rule.interval) months"
        case .yearly:
            description = rule.interval == 1 ? "Every year" : "Every \(rule.interval) years"
        @unknown default:
            description = "Custom recurrence"
        }
        
        if let end = rule.recurrenceEnd {
            if let endDate = end.endDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                description += " until \(formatter.string(from: endDate))"
            } else if end.occurrenceCount > 0 {
                description += " for \(end.occurrenceCount) times"
            }
        }
        
        return description
    }
    
    private func dayOfWeek(from ekWeekday: EKWeekday) -> String {
        switch ekWeekday {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        @unknown default: return "Unknown"
        }
    }
    

} 