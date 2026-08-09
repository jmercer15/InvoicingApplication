//
//  SessionFormModel.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Refactoring Initiative
//
import Foundation
import SwiftUI
import Core
import PersistenceModels
import EventKit
import Data
import SharedUI

struct SessionSupportLogDraft: Sendable {
    var isEnabled: Bool = false
    var participantName: String = ""
    var participantNdisNumber: String = ""
    var supportItemNumber: String = ""
    var serviceDescription: String = ""
    var location: String = ""
    var deliveredFrom: Date = Date()
    var deliveredTo: Date = Date().addingTimeInterval(3600)
    var deliveredBy: String = ""
    var attestedBy: String = ""
    var attestedAt: Date = Date()
    var signatureMethod: String? = SignatureMethod.attestation.rawValue
    var signedBy: String? = nil
    var signedAt: Date? = nil
    var cancellationReasonCode: String? = nil
    var notes: String? = nil
}

/// A simple struct to hold the raw, mutable state of session form fields
/// Extracted from NewSessionViewModel to separate data from logic
struct SessionFormModel: Sendable {
    
    // MARK: - Basic Session Properties
    var title: String = ""
    var isAllDay: Bool = false
    var startTime: Date = Date()
    var endTime: Date = Date().addingTimeInterval(3600) // 1 hour later
    var status: String = String.sessionStatusPlanned
    var location: String = ""
    var notes: String = ""
    var supportLogDraft: SessionSupportLogDraft = SessionSupportLogDraft()
    
    // MARK: - Client and Service Selection
    var selectedClientID: UUID? = nil
    var selectedClientServiceID: UUID? = nil
    
    // MARK: - Address Components
    var unitNumber: String = ""
    var streetNumber: String = ""
    var streetName: String = ""
    var suburb: String = ""
    var city: String = ""
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
    // MARK: - External Calendar Event Tracking
    var sourceEventIdentifier: String? = nil
    var preventEventLinking: Bool = false
    
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
    
    var hasRecurrence: Bool {
        return recurrenceFrequency != .none
    }

    /// True when any structured address field used by the map / manual address UI is non-empty.
    var hasStructuredAddressInput: Bool {
        !unitNumber.isEmpty || !streetNumber.isEmpty || !streetName.isEmpty ||
            !suburb.isEmpty || !city.isEmpty || !state.isEmpty || !postcode.isEmpty ||
            !country.isEmpty || !poBox.isEmpty
    }
    
    // MARK: - Initialization
    
    init() {
        // Default initialization
    }
    
    /// Initialize from a Session domain model
    init(from session: Session, recurrenceRuleManager: Core.RecurrenceRuleManager) {
        self.title = session.title
        self.isAllDay = session.isAllDay
        self.startTime = session.startTime ?? Date()
        self.endTime = session.endTime ?? Date().addingTimeInterval(3600)
        self.status = session.status?.rawValue ?? String.sessionStatusPlanned
        self.location = session.location ?? ""
        self.notes = session.notes ?? ""
        self.supportLogDraft.deliveredFrom = self.startTime
        self.supportLogDraft.deliveredTo = self.endTime
        self.supportLogDraft.location = self.location
        
        self.selectedClientID = session.clientId
        self.selectedClientServiceID = session.clientServiceId
        
        // Session stores coordinates directly; full address lookup can be derived from `Session` when needed.
        self.sessionLatitude = session.sessionLatitude
        self.sessionLongitude = session.sessionLongitude
        
        self.googleCalendarColorId = session.googleColorId
        self.useGoogleColor = session.googleColorId != nil
        
        // Load recurrence settings if present
        if let ruleData = session.recurrenceRuleData,
           let rule = recurrenceRuleManager.deserialize(ruleData) {
            populateRecurrenceSettings(from: rule)
        }
    }
    
    /// Initialize from an EKEvent
    init(from event: EKEvent) {
        let parsedLocation = Core.EventKitLocationParser.parse(event: event)
        self.title = event.title ?? "New Session"
        self.isAllDay = event.isAllDay
        self.startTime = event.startDate
        self.endTime = event.endDate
        
        self.location = parsedLocation.preferredLocation ?? ""
        self.notes = event.notes ?? ""
        self.supportLogDraft.deliveredFrom = event.startDate
        self.supportLogDraft.deliveredTo = event.endDate
        self.supportLogDraft.location = parsedLocation.preferredLocation ?? ""
        self.sourceEventIdentifier = event.eventIdentifier
        self.unitNumber = parsedLocation.unitNumber
        self.streetNumber = parsedLocation.streetNumber
        self.streetName = parsedLocation.streetName
        self.suburb = parsedLocation.suburb
        self.city = parsedLocation.city
        self.state = parsedLocation.state
        self.postcode = parsedLocation.postcode
        self.country = parsedLocation.country
        self.poBox = parsedLocation.poBox
        self.sessionLatitude = parsedLocation.latitude
        self.sessionLongitude = parsedLocation.longitude
        self.addressSearchText = parsedLocation.fullAddressText
        
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

    // MARK: - Address sheet undo (cancel without saving)

    struct AddressEditingUndoSnapshot: Equatable {
        var unitNumber: String
        var streetNumber: String
        var streetName: String
        var suburb: String
        var city: String
        var state: String
        var postcode: String
        var country: String
        var poBox: String
        var sessionLatitude: Double
        var sessionLongitude: Double
        var addressSearchText: String
        var selectedAddress: AddressData?
    }

    var addressEditingUndoSnapshot: AddressEditingUndoSnapshot {
        AddressEditingUndoSnapshot(
            unitNumber: unitNumber,
            streetNumber: streetNumber,
            streetName: streetName,
            suburb: suburb,
            city: city,
            state: state,
            postcode: postcode,
            country: country,
            poBox: poBox,
            sessionLatitude: sessionLatitude,
            sessionLongitude: sessionLongitude,
            addressSearchText: addressSearchText,
            selectedAddress: selectedAddress
        )
    }

    mutating func restoreAddressEditingUndo(_ snapshot: AddressEditingUndoSnapshot) {
        unitNumber = snapshot.unitNumber
        streetNumber = snapshot.streetNumber
        streetName = snapshot.streetName
        suburb = snapshot.suburb
        city = snapshot.city
        state = snapshot.state
        postcode = snapshot.postcode
        country = snapshot.country
        poBox = snapshot.poBox
        sessionLatitude = snapshot.sessionLatitude
        sessionLongitude = snapshot.sessionLongitude
        addressSearchText = snapshot.addressSearchText
        selectedAddress = snapshot.selectedAddress
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
