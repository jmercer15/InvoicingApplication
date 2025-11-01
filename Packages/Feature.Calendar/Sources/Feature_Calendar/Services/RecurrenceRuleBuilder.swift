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
    

} 