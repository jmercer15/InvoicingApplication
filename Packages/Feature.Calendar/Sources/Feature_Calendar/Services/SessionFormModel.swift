//
//  SessionFormModel.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Refactoring Initiative
//
import Foundation
import SwiftUI
import Core
import EventKit
import Data
import SharedUI

/// A simple struct to hold the raw, mutable state of session form fields
/// Extracted from NewSessionViewModel to separate data from logic
struct SessionFormModel {
    
    // MARK: - Basic Session Properties
    var title: String = ""
    var isAllDay: Bool = false
    var startTime: Date = Date()
    var endTime: Date = Date().addingTimeInterval(3600) // 1 hour later
    var status: String = String.sessionStatusPlanned
    var location: String = ""
    var notes: String = ""
    
    // MARK: - Client and Service Selection
    var selectedClientID: UUID? = nil
    var selectedClientServiceID: UUID? = nil
    
    // MARK: - Address Components
    var unitNumber: String = ""
    var streetNumber: String = ""
    var streetName: String = ""
    var suburb: String = ""
    var state: String = ""
    var postcode: String = ""
    var country: String = ""
    var poBox: String = ""
    var sessionLatitude: Double = 0.0
    var sessionLongitude: Double = 0.0
    var addressSearchText: String = ""
    var selectedAddress: AddressData? = nil
    
    // MARK: - Visual Customization
    var useGoogleColor: Bool = true
    var googleCalendarColorId: String? = nil
    
    // MARK: - External Calendar Event Tracking
    var sourceEventIdentifier: String? = nil
    
    // MARK: - Recurrence Configuration
    var recurrenceFrequency: RecurrenceFrequency = .none
    var recurrenceInterval: Int = 1
    var recurrenceEndType: RecurrenceEndType = .never
    var recurrenceCount: Int = 10
    var recurrenceEndDate: Date = Date().addingTimeInterval(3600 * 24 * 30)
    var selectedWeekdays: Set<SelectableWeekday> = []
    var daysOfTheMonth: [Int] = []
    var monthsOfTheYear: [Int] = []
    var weeksOfTheYear: [Int] = []
    var daysOfTheYear: [Int] = []
    var setPositions: [Int] = []
    var monthlyRecurrenceType: PositionalRecurrenceType = .onSpecificDays
    var selectedMonthDaysNumbers: Set<Int> = []
    var yearlyRecurrenceType: PositionalRecurrenceType = .onSpecificDays
    var selectedYearlyDaysNumbers: Set<Int> = []
    var selectedYearMonths: Set<SelectableMonth> = []
    var selectedOrdinal: Int = 1
    var selectedDayOfWeekForOrdinal: DayOfWeekOption = .monday
    
    // MARK: - Computed Properties
    
    var hasBasicRequiredFields: Bool {
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               selectedClientID != nil &&
               selectedClientServiceID != nil &&
               (isAllDay || startTime < endTime)
    }
    
    var fullAddress: String {
        let line1: String
        if !poBox.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            line1 = "PO Box \(poBox.trimmingCharacters(in: .whitespacesAndNewlines))"
        } else {
            var streetParts: [String] = []
            let unit = unitNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let number = streetNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = streetName.trimmingCharacters(in: .whitespacesAndNewlines)

            if !unit.isEmpty && !number.isEmpty {
                streetParts.append("\(unit)/\(number)")
            } else if !number.isEmpty {
                streetParts.append(number)
            }
            
            if !name.isEmpty {
                streetParts.append(name)
            }
            line1 = streetParts.joined(separator: " ")
        }
        
        var localityParts: [String] = []
        if !suburb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { localityParts.append(suburb.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if !state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { localityParts.append(state.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if !postcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { localityParts.append(postcode.trimmingCharacters(in: .whitespacesAndNewlines)) }
        
        let line2 = localityParts.joined(separator: " ")
        
        return [line1, line2]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
    
    var hasRecurrence: Bool {
        return recurrenceFrequency != .none
    }
    
    // MARK: - Initialization
    
    init() {
        // Default initialization
    }
    
    /// Initialize from an existing SessionEntity
    init(from session: SessionEntity) {
        self.title = session.title
        self.isAllDay = session.isAllDay
        self.startTime = session.startTime ?? Date()
        self.endTime = session.endTime ?? Date().addingTimeInterval(3600)
        self.status = session.status?.rawValue ?? String.sessionStatusPlanned
        self.location = session.location ?? ""
        self.notes = session.notes ?? ""
        
        self.selectedClientID = session.client?.id
        self.selectedClientServiceID = session.clientService?.id
        
        // Load address data from linked AddressEntity
        if let address = session.address {
            self.unitNumber = address.unitNumber
            self.streetNumber = address.streetNumber
            self.streetName = address.streetName
            self.suburb = address.suburb
            self.state = address.state
            self.postcode = address.postcode
            self.country = address.country
            self.poBox = address.poBox
            self.sessionLatitude = address.latitude
            self.sessionLongitude = address.longitude
        } else {
            // Fallback to legacy location field and session coordinates
            self.sessionLatitude = session.sessionLatitude
            self.sessionLongitude = session.sessionLongitude
        }
        
        self.googleCalendarColorId = session.googleColorId
        self.useGoogleColor = session.googleColorId != nil
        
        // Load recurrence settings if present
        if let ruleData = session.recurrenceRuleData,
           let rule = RecurrenceRuleManager.shared.deserialize(ruleData) {
            populateRecurrenceSettings(from: rule)
        }
    }
    
    /// Initialize from a Session domain model
    init(from session: Session) {
        self.title = session.title
        self.isAllDay = session.isAllDay
        self.startTime = session.startTime ?? Date()
        self.endTime = session.endTime ?? Date().addingTimeInterval(3600)
        self.status = session.status ?? String.sessionStatusPlanned
        self.location = session.location ?? ""
        self.notes = session.notes ?? ""
        
        self.selectedClientID = session.clientId
        self.selectedClientServiceID = session.clientServiceId
        
        // Session domain model has addressId but not full address details
        // Address details should be fetched using AddressRepository when needed
        // For now, use session coordinates which are sufficient for most cases
        // Address details can be loaded when editing if needed by fetching from SessionEntity or AddressRepository
        self.sessionLatitude = session.sessionLatitude
        self.sessionLongitude = session.sessionLongitude
        
        self.googleCalendarColorId = session.googleColorId
        self.useGoogleColor = session.googleColorId != nil
        
        // Load recurrence settings if present
        if let ruleData = session.recurrenceRuleData,
           let rule = RecurrenceRuleManager.shared.deserialize(ruleData) {
            populateRecurrenceSettings(from: rule)
        }
    }
    
    /// Initialize from an EKEvent
    init(from event: EKEvent) {
        self.title = event.title ?? "New Session"
        self.isAllDay = event.isAllDay
        self.startTime = event.startDate
        self.endTime = event.endDate
        
        // Normalize location: replace newlines with ', '
        let normalizedLocation = (event.location ?? "").replacingOccurrences(of: "\n", with: ", ")
        self.location = normalizedLocation
        self.notes = event.notes ?? ""
        self.sourceEventIdentifier = event.eventIdentifier
        
        // Handle Google Calendar color
        if let colorId = GoogleCalendarColors.getGoogleEventColorId(event) {
            self.googleCalendarColorId = colorId
            self.useGoogleColor = true
        }
        
        // Mirror EKEvent's recurrence rule
        if let ekRule = event.recurrenceRules?.first {
            populateRecurrenceSettings(from: ekRule)
        }
    }
    
    // MARK: - Recurrence Settings Population
    
    private mutating func populateRecurrenceSettings(from rule: EKRecurrenceRule) {
        switch rule.frequency {
        case .daily: self.recurrenceFrequency = .daily
        case .weekly: self.recurrenceFrequency = .weekly
        case .monthly: self.recurrenceFrequency = .monthly
        case .yearly: self.recurrenceFrequency = .yearly
        @unknown default: self.recurrenceFrequency = .none
        }
        
        self.recurrenceInterval = rule.interval
        
        // Days of the week - properly convert EKRecurrenceDayOfWeek to SelectableWeekday
        if let days = rule.daysOfTheWeek, !days.isEmpty {
            self.selectedWeekdays = Set(days.compactMap { ekDay in
                // Convert EKWeekday raw value to SelectableWeekday
                let ekWeekdayRawValue = ekDay.dayOfTheWeek.rawValue
                switch ekWeekdayRawValue {
                case 1: return .sunday
                case 2: return .monday
                case 3: return .tuesday
                case 4: return .wednesday
                case 5: return .thursday
                case 6: return .friday
                case 7: return .saturday
                default: return nil
                }
            })
            // Detect ordinal pattern for monthly/yearly rules using weekNumber on daysOfTheWeek
            if rule.frequency == .monthly || rule.frequency == .yearly,
               let first = days.first, first.weekNumber != 0 {
                let wk = first.weekNumber
                if rule.frequency == .monthly {
                    self.monthlyRecurrenceType = .onTheOrdinalDayOfWeek
                } else {
                    self.yearlyRecurrenceType = .onTheOrdinalDayOfWeek
                }
                self.selectedOrdinal = wk
                // Map EKWeekday to DayOfWeekOption single day
                switch first.dayOfTheWeek {
                case .sunday: self.selectedDayOfWeekForOrdinal = .sunday
                case .monday: self.selectedDayOfWeekForOrdinal = .monday
                case .tuesday: self.selectedDayOfWeekForOrdinal = .tuesday
                case .wednesday: self.selectedDayOfWeekForOrdinal = .wednesday
                case .thursday: self.selectedDayOfWeekForOrdinal = .thursday
                case .friday: self.selectedDayOfWeekForOrdinal = .friday
                case .saturday: self.selectedDayOfWeekForOrdinal = .saturday
                @unknown default: self.selectedDayOfWeekForOrdinal = .monday
                }
            }
        }
        
        // Fallback: If this is a weekly recurrence but no weekdays were selected,
        // default to the day of the week of the session's start time
        if self.recurrenceFrequency == .weekly && self.selectedWeekdays.isEmpty {
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: self.startTime)
            // Convert Calendar weekday (1=Sunday, 2=Monday, etc.) to SelectableWeekday
            switch weekday {
            case 1: self.selectedWeekdays = [.sunday]
            case 2: self.selectedWeekdays = [.monday]
            case 3: self.selectedWeekdays = [.tuesday]
            case 4: self.selectedWeekdays = [.wednesday]
            case 5: self.selectedWeekdays = [.thursday]
            case 6: self.selectedWeekdays = [.friday]
            case 7: self.selectedWeekdays = [.saturday]
            default: self.selectedWeekdays = [.monday] // Fallback to Monday
            }
        }
        
        // Other recurrence properties
        self.daysOfTheMonth = rule.daysOfTheMonth?.map { $0.intValue } ?? []
        self.monthsOfTheYear = rule.monthsOfTheYear?.map { $0.intValue } ?? []
        self.weeksOfTheYear = rule.weeksOfTheYear?.map { $0.intValue } ?? []
        self.daysOfTheYear = rule.daysOfTheYear?.map { $0.intValue } ?? []
        self.setPositions = rule.setPositions?.map { $0.intValue } ?? []

        // Keep selected sets in sync with array properties so UI/validation remain consistent
        self.selectedMonthDaysNumbers = Set(self.daysOfTheMonth)
        self.selectedYearlyDaysNumbers = Set(self.daysOfTheYear)
        self.selectedYearMonths = Set(self.monthsOfTheYear.compactMap { SelectableMonth(rawValue: $0) })
        
        // Recurrence end
        if let end = rule.recurrenceEnd {
            if let endDate = end.endDate {
                self.recurrenceEndType = .onDate
                self.recurrenceEndDate = endDate
            } else if end.occurrenceCount > 0 {
                self.recurrenceEndType = .afterCount
                self.recurrenceCount = end.occurrenceCount
            } else {
                self.recurrenceEndType = .never
            }
        } else {
            self.recurrenceEndType = .never
        }
    }
    
    // MARK: - Validation
    
    func validateForm() -> [ValidationError] {
        var errors: [ValidationError] = []
        
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyTitle)
        }
        
        if selectedClientID == nil {
            errors.append(.noClientSelected)
        }
        
        if selectedClientServiceID == nil {
            errors.append(.noServiceSelected)
        }
        
        if !isAllDay && startTime >= endTime {
            errors.append(.invalidTimeRange)
        }
        
        if hasRecurrence {
            let recurrenceErrors = validateRecurrenceSettings()
            errors.append(contentsOf: recurrenceErrors)
        }
        
        return errors
    }
    
    private func validateRecurrenceSettings() -> [ValidationError] {
        var errors: [ValidationError] = []
        
        if recurrenceInterval <= 0 {
            errors.append(.invalidRecurrenceInterval)
        }
        
        // For weekly, allow empty selection to default to the startTime weekday downstream
        
        if recurrenceEndType == .afterCount && recurrenceCount <= 0 {
            errors.append(.invalidRecurrenceCount)
        }
        
        if recurrenceEndType == .onDate && recurrenceEndDate <= startTime {
            errors.append(.invalidRecurrenceEndDate)
        }
        

        return errors
    }
    
    // MARK: - Mutation Methods
    
    mutating func updateStartTime(_ newStartTime: Date) {
        startTime = newStartTime
        
        // Only adjust end time if it would create an invalid time range
        if !isAllDay && endTime <= startTime {
            endTime = startTime.addingTimeInterval(3600)
        }
    }
    
    mutating func updateEndTime(_ newEndTime: Date) {
        endTime = newEndTime
        
        // Only adjust start time if it would create an invalid time range
        if !isAllDay && endTime <= startTime {
            startTime = endTime.addingTimeInterval(-3600)
        }
    }
    
    mutating func clearRecurrence() {
        recurrenceFrequency = .none
        recurrenceInterval = 1
        recurrenceEndType = .never
        recurrenceCount = 10
        recurrenceEndDate = Date().addingTimeInterval(3600 * 24 * 30)
        selectedWeekdays = []
        daysOfTheMonth = []
        monthsOfTheYear = []
        weeksOfTheYear = []
        daysOfTheYear = []
        setPositions = []
        monthlyRecurrenceType = .onSpecificDays
        selectedMonthDaysNumbers = []
        yearlyRecurrenceType = .onSpecificDays
        selectedYearlyDaysNumbers = []
        selectedYearMonths = []
        selectedOrdinal = 1
        selectedDayOfWeekForOrdinal = .monday
    }
    
    mutating func updateFromEKEvent(_ event: EKEvent) {
        title = event.title ?? title
        isAllDay = event.isAllDay
        startTime = event.startDate
        endTime = event.endDate
        
        let normalizedLocation = (event.location ?? "").replacingOccurrences(of: "\n", with: ", ")
        location = normalizedLocation
        notes = event.notes ?? notes
        sourceEventIdentifier = event.eventIdentifier
        
        if let colorId = GoogleCalendarColors.getGoogleEventColorId(event) {
            googleCalendarColorId = colorId
            useGoogleColor = true
        }
        
        if let ekRule = event.recurrenceRules?.first {
            populateRecurrenceSettings(from: ekRule)
        } else {
            clearRecurrence()
        }
    }
    
    // MARK: - Supporting Types
    
    enum ValidationError: String, CaseIterable {
        case emptyTitle = "Title cannot be empty"
        case noClientSelected = "Please select a client"
        case noServiceSelected = "Please select a service"
        case invalidTimeRange = "End time must be after start time"
        case invalidRecurrenceInterval = "Recurrence interval must be greater than 0"
        case noWeekdaysSelected = "Please select at least one weekday for weekly recurrence"
        case invalidRecurrenceCount = "Recurrence count must be greater than 0"
        case invalidRecurrenceEndDate = "Recurrence end date must be after start time"
        
        var localizedDescription: String {
            return self.rawValue
        }
    }
} 