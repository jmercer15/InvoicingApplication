//
//  RecurrenceRuleBuilder.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Refactoring Initiative
//
import Foundation
import EventKit

/// Responsible for building EKRecurrenceRule objects from SessionFormModel data
/// Extracted from NewSessionViewModel to isolate complex rule construction logic
class RecurrenceRuleBuilder {
    
    // MARK: - Rule Construction
    
    /// Builds an EKRecurrenceRule from the recurrence settings in a SessionFormModel
    /// Returns nil if no recurrence is configured
    func buildRecurrenceRule(from formModel: SessionFormModel) -> EKRecurrenceRule? {
        // None means no recurrence
        guard formModel.recurrenceFrequency != .none else {
            return nil
        }
        
        let frequency = convertFrequency(formModel.recurrenceFrequency)
        let interval = formModel.recurrenceInterval
        
        // Days of the week (primarily for weekly recurrence)
        let daysOfTheWeek = buildDaysOfTheWeek(formModel)
        
        // Monthly/yearly specific settings
        // Prefer the UI selection sets when present to avoid desync with array fields
        let effectiveMonthDays: [Int]
        if formModel.monthlyRecurrenceType == .onSpecificDays, !formModel.selectedMonthDaysNumbers.isEmpty {
            effectiveMonthDays = Array(formModel.selectedMonthDaysNumbers).sorted()
        } else {
            effectiveMonthDays = formModel.daysOfTheMonth
        }
        let daysOfTheMonth = effectiveMonthDays.isEmpty ? nil : effectiveMonthDays.map { NSNumber(value: $0) }

        let effectiveMonths: [Int]
        if !formModel.selectedYearMonths.isEmpty {
            effectiveMonths = formModel.selectedYearMonths.map { $0.rawValue }.sorted()
        } else {
            effectiveMonths = formModel.monthsOfTheYear
        }
        let monthsOfTheYear = effectiveMonths.isEmpty ? nil : effectiveMonths.map { NSNumber(value: $0) }

        let weeksOfTheYear = formModel.weeksOfTheYear.isEmpty ? nil : formModel.weeksOfTheYear.map { NSNumber(value: $0) }

        let effectiveYearDays: [Int]
        if formModel.yearlyRecurrenceType == .onSpecificDays, !formModel.selectedYearlyDaysNumbers.isEmpty {
            effectiveYearDays = Array(formModel.selectedYearlyDaysNumbers).sorted()
        } else {
            effectiveYearDays = formModel.daysOfTheYear
        }
        let daysOfTheYear = effectiveYearDays.isEmpty ? nil : effectiveYearDays.map { NSNumber(value: $0) }
        let setPositions = formModel.setPositions.isEmpty ? nil : formModel.setPositions.map { NSNumber(value: $0) }
        
        // Recurrence end
        let recurrenceEnd = buildRecurrenceEnd(formModel)
        
        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            daysOfTheWeek: daysOfTheWeek,
            daysOfTheMonth: daysOfTheMonth,
            monthsOfTheYear: monthsOfTheYear,
            weeksOfTheYear: weeksOfTheYear,
            daysOfTheYear: daysOfTheYear,
            setPositions: setPositions,
            end: recurrenceEnd
        )
    }
    
    // MARK: - Frequency Conversion
    
    private func convertFrequency(_ frequency: RecurrenceFrequency) -> EKRecurrenceFrequency {
        switch frequency {
        case .none:
            return .daily // This shouldn't happen, but provide a fallback
        case .daily:
            return .daily
        case .weekly:
            return .weekly
        case .monthly:
            return .monthly
        case .yearly:
            return .yearly
        }
    }
    
    // MARK: - Days of Week Processing
    
    private func buildDaysOfTheWeek(_ formModel: SessionFormModel) -> [EKRecurrenceDayOfWeek]? {
        switch formModel.recurrenceFrequency {
        case .weekly:
            // For weekly recurrence, use selected weekdays or default to startTime's weekday
            var weekdays = formModel.selectedWeekdays
            if weekdays.isEmpty {
                let calendar = Calendar.current
                let weekday = calendar.component(.weekday, from: formModel.startTime)
                if let fallback = SelectableWeekday(rawValue: weekday) {
                    weekdays = [fallback]
                }
            }
            guard !weekdays.isEmpty else { return nil }
            return weekdays
                .sorted { $0.rawValue < $1.rawValue }
                .map { $0.ekDayOfWeek }
            
        case .monthly:
            // For monthly recurrence with ordinal pattern (e.g., "first Monday")
            if formModel.monthlyRecurrenceType == .onTheOrdinalDayOfWeek {
                return buildOrdinalDaysOfWeek(
                    ordinal: formModel.selectedOrdinal,
                    dayOfWeek: formModel.selectedDayOfWeekForOrdinal
                )
            }
            return nil
            
        case .yearly:
            // For yearly recurrence with ordinal pattern
            if formModel.yearlyRecurrenceType == .onTheOrdinalDayOfWeek {
                return buildOrdinalDaysOfWeek(
                    ordinal: formModel.selectedOrdinal,
                    dayOfWeek: formModel.selectedDayOfWeekForOrdinal
                )
            }
            return nil
            
        default:
            return nil
        }
    }
    
    private func buildOrdinalDaysOfWeek(ordinal: Int, dayOfWeek: DayOfWeekOption) -> [EKRecurrenceDayOfWeek]? {
        // Convert our DayOfWeekOption to EKRecurrenceDayOfWeek
        guard let ekDays = dayOfWeek.ekDaysOfWeek else { return nil }
        
        // Apply the ordinal (1st, 2nd, 3rd, 4th, or last)
        return ekDays.map { ekDay in
            EKRecurrenceDayOfWeek(ekDay.dayOfTheWeek, weekNumber: ordinal)
        }
    }
    
    // MARK: - Recurrence End Processing
    
    private func buildRecurrenceEnd(_ formModel: SessionFormModel) -> EKRecurrenceEnd? {
        switch formModel.recurrenceEndType {
        case .never:
            return nil
        case .afterCount:
            return EKRecurrenceEnd(occurrenceCount: formModel.recurrenceCount)
        case .onDate:
            return EKRecurrenceEnd(end: formModel.recurrenceEndDate)
        }
    }
    
    // MARK: - Validation
    
    /// Validates recurrence settings and returns any errors
    func validateRecurrenceSettings(_ formModel: SessionFormModel) -> [RecurrenceValidationError] {
        var errors: [RecurrenceValidationError] = []
        
        // Only validate if recurrence is enabled
        guard formModel.recurrenceFrequency != .none else { return errors }
        
        // Basic validations
        if formModel.recurrenceInterval <= 0 {
            errors.append(.invalidInterval(formModel.recurrenceInterval))
        }
        
        // Frequency-specific validations
        switch formModel.recurrenceFrequency {
        case .weekly:
            if formModel.selectedWeekdays.isEmpty {
                errors.append(.noWeekdaysSelected)
            }
            
        case .monthly:
            if formModel.monthlyRecurrenceType == .onSpecificDays && formModel.selectedMonthDaysNumbers.isEmpty {
                errors.append(.noMonthDaysSelected)
            }
            
        case .yearly:
            if formModel.yearlyRecurrenceType == .onSpecificDays && formModel.selectedYearlyDaysNumbers.isEmpty {
                errors.append(.noYearDaysSelected)
            }
            if formModel.selectedYearMonths.isEmpty {
                errors.append(.noMonthsSelected)
            }
            
        default:
            break
        }
        
        // End date validations
        switch formModel.recurrenceEndType {
        case .afterCount:
            if formModel.recurrenceCount <= 0 {
                errors.append(.invalidOccurrenceCount(formModel.recurrenceCount))
            }
            
        case .onDate:
            if formModel.recurrenceEndDate <= formModel.startTime {
                errors.append(.endDateBeforeStart)
            }
            
        default:
            break
        }
        
        return errors
    }
    
    // MARK: - Rule Analysis
    
    /// Provides a human-readable summary of the recurrence rule
    func buildRecurrenceSummary(from formModel: SessionFormModel) -> String {
        guard formModel.recurrenceFrequency != .none else {
            return "Does not repeat"
        }
        
        var summary = ""
        
        // Base frequency
        switch formModel.recurrenceFrequency {
        case .daily:
            summary = formModel.recurrenceInterval == 1 ? "Repeats every day" : "Repeats every \(formModel.recurrenceInterval) days"
            
        case .weekly:
            let base = formModel.recurrenceInterval == 1 ? "Repeats every week" : "Repeats every \(formModel.recurrenceInterval) weeks"
            if !formModel.selectedWeekdays.isEmpty {
                let days = formModel.selectedWeekdays
                    .sorted { $0.rawValue < $1.rawValue }
                    .map { $0.shortName }
                    .joined(separator: ", ")
                summary = "\(base) on \(days)"
            } else {
                summary = base
            }
            
        case .monthly:
            let base = formModel.recurrenceInterval == 1 ? "Repeats every month" : "Repeats every \(formModel.recurrenceInterval) months"
            if formModel.monthlyRecurrenceType == .onSpecificDays {
                let days = formModel.selectedMonthDaysNumbers.sorted().map { String($0) }.joined(separator: ", ")
                summary = days.isEmpty ? base : "\(base) on day(s) \(days)"
            } else {
                let ordinal = OrdinalSelection(intValue: formModel.selectedOrdinal)?.displayName ?? "First"
                let weekday = formModel.selectedDayOfWeekForOrdinal.displayName
                summary = "\(base) on the \(ordinal) \(weekday)"
            }
            
        case .yearly:
            let base = formModel.recurrenceInterval == 1 ? "Repeats every year" : "Repeats every \(formModel.recurrenceInterval) years"
            let months = formModel.selectedYearMonths
                .sorted { $0.rawValue < $1.rawValue }
                .map { $0.shortName }
                .joined(separator: ", ")
            
            if formModel.yearlyRecurrenceType == .onSpecificDays {
                let days = formModel.selectedYearlyDaysNumbers.sorted().map { String($0) }.joined(separator: ", ")
                summary = "\(base) in \(months)" + (days.isEmpty ? "" : " on day(s) \(days)")
            } else {
                let ordinal = OrdinalSelection(intValue: formModel.selectedOrdinal)?.displayName ?? "First"
                let weekday = formModel.selectedDayOfWeekForOrdinal.displayName
                summary = "\(base) in \(months) on the \(ordinal) \(weekday)"
            }
            
        case .none:
            summary = "Does not repeat"
        }
        
        // Add end condition
        switch formModel.recurrenceEndType {
        case .never:
            break // No additional text needed
        case .afterCount:
            summary += " for \(formModel.recurrenceCount) times"
        case .onDate:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            summary += " until \(formatter.string(from: formModel.recurrenceEndDate))"
        }
        
        return summary
    }
    
    /// Estimates the number of occurrences for a recurrence rule within a date range
    func estimateOccurrenceCount(
        from formModel: SessionFormModel,
        in dateRange: ClosedRange<Date>
    ) -> Int {
        guard buildRecurrenceRule(from: formModel) != nil else { return 1 }
        
        // This is a simplified estimation - a full implementation would need
        // to actually expand the recurrence rule to count exact occurrences
        let dayRange = dateRange.upperBound.timeIntervalSince(dateRange.lowerBound) / (24 * 60 * 60)
        
        switch formModel.recurrenceFrequency {
        case .daily:
            return Int(dayRange / Double(formModel.recurrenceInterval))
        case .weekly:
            return Int(dayRange / (7.0 * Double(formModel.recurrenceInterval)))
        case .monthly:
            return Int(dayRange / (30.0 * Double(formModel.recurrenceInterval))) // Approximate
        case .yearly:
            return Int(dayRange / (365.0 * Double(formModel.recurrenceInterval))) // Approximate
        case .none:
            return 1
        }
    }
    
    // MARK: - Supporting Types
    
    enum RecurrenceValidationError: LocalizedError {
        case invalidInterval(Int)
        case noWeekdaysSelected
        case noMonthDaysSelected
        case noYearDaysSelected
        case noMonthsSelected
        case invalidOccurrenceCount(Int)
        case endDateBeforeStart
        
        var errorDescription: String? {
            switch self {
            case .invalidInterval(let interval):
                return "Recurrence interval must be greater than 0 (got \(interval))"
            case .noWeekdaysSelected:
                return "Please select at least one weekday for weekly recurrence"
            case .noMonthDaysSelected:
                return "Please select at least one day for monthly recurrence"
            case .noYearDaysSelected:
                return "Please select at least one day for yearly recurrence"
            case .noMonthsSelected:
                return "Please select at least one month for yearly recurrence"
            case .invalidOccurrenceCount(let count):
                return "Occurrence count must be greater than 0 (got \(count))"
            case .endDateBeforeStart:
                return "Recurrence end date must be after the session start time"
            }
        }
    }
} 