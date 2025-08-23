import Foundation
import SwiftUI
import SwiftData
import EventKit // Needed for EKEvent
import MapKit
import Combine

// MARK: - Session Status Enum
enum SessionStatus: String, CaseIterable, Identifiable {
    case planned = "Planned"
    case confirmed = "Confirmed"
    case completed = "Completed"
    case cancelled = "Cancelled"
    
    var id: String { self.rawValue }
    
    var systemImage: String {
        switch self {
        case .planned: "calendar.badge.clock"
        case .confirmed: "checkmark.circle"
        case .completed: "checkmark.circle.fill"
        case .cancelled: "xmark.circle"
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Recurrence Options
// ─────────────────────────────────────────────────────────────

enum RecurrenceFrequency: String, CaseIterable, Identifiable {
    case none = "None"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    var id: String { self.rawValue }
}

enum RecurrenceEndType: String, CaseIterable, Identifiable {
    case never = "Never"
    case afterCount = "After"
    case onDate = "On Date"
    var id: String { self.rawValue }
}

// Enum for Monthly/Yearly Recurrence Pattern Type
enum PositionalRecurrenceType: String, CaseIterable, Identifiable {
    case onSpecificDays = "On specific day(s)"
    case onTheOrdinalDayOfWeek = "On the..."
    var id: String { self.rawValue }
}

// Helper Enum for Weekday Selection
enum SelectableWeekday: Int, CaseIterable, Identifiable {
    case monday = 2, tuesday, wednesday, thursday, friday, saturday, sunday = 1

    var id: Int { self.rawValue }

    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
    
    var ekDayOfWeek: EKRecurrenceDayOfWeek {
        return EKRecurrenceDayOfWeek(EKWeekday(rawValue: self.rawValue)!)
    }
}

// Helper for "Day of Week" options in more complex recurrences (e.g. "First Monday")
enum DayOfWeekOption: Int, CaseIterable, Identifiable {
    case day = 0 // Represents any day
    case weekday = 1 // Represents a weekday
    case weekendDay = 2 // Represents a weekend day
    case sunday = 3
    case monday = 4
    case tuesday = 5
    case wednesday = 6
    case thursday = 7
    case friday = 8
    case saturday = 9

    var id: Int { self.rawValue }

    var displayName: String {
        switch self {
        case .day: return "Day"
        case .weekday: return "Weekday"
        case .weekendDay: return "Weekend Day"
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
    
    var ekDayOfWeek: EKRecurrenceDayOfWeek {
        return EKRecurrenceDayOfWeek(EKWeekday(rawValue: self.rawValue)!)
    }
    
    var ekDaysOfWeek: [EKRecurrenceDayOfWeek]? {
        return [ekDayOfWeek]
    }
}

// Helper Enum for Month Selection in Yearly Recurrence
enum SelectableMonth: Int, CaseIterable, Identifiable {
    case january = 1, february, march, april, may, june, july, august, september, october, november, december

    var id: Int { self.rawValue }

    var shortName: String {
        let formatter = DateFormatter()
        return formatter.shortMonthSymbols[self.rawValue - 1]
    }
    
    var fullName: String {
        let formatter = DateFormatter()
        return formatter.monthSymbols[self.rawValue - 1]
    }
}

enum OrdinalSelection: Int, CaseIterable, Identifiable {
    case first = 1
    case second = 2
    case third = 3
    case fourth = 4
    case last = -1

    var id: Int { self.rawValue }

    var displayName: String {
        switch self {
        case .first: "First"
        case .second: "Second"
        case .third: "Third"
        case .fourth: "Fourth"
        case .last: "Last"
        }
    }
    
    init?(intValue: Int) {
        self.init(rawValue: intValue)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - New Session ViewModel
// ─────────────────────────────────────────────────────────────

@MainActor
class NewSessionViewModel: ObservableObject {
    let modelContext: ModelContext
    var sessionToEdit: SessionEntity?
    private let sessionModificationService: SessionModificationService
    
    // MARK: - Save State Management
    @Published var isSaving = false
    @Published var saveError: String? = nil
    private var saveTask: Task<Void, Never>? = nil
    
    // MARK: - Callback Management
    var onSave: ((RecurringEditMode) -> Void)?
    var onSaveCompleted: (() -> Void)?
    var onDelete: ((RecurringEditMode) -> Void)?
    
    // MARK: - Form State (using SessionFormModel as single source of truth)
    @Published var formModel: SessionFormModel
    
    // MARK: - Client & Service Entities (for display, fetched on demand)
    @Published var selectedClient: ClientEntity?
    @Published var selectedClientService: ClientServiceEntity?
    
    // MARK: - Dialog State Management
    @Published var showingRecurringEditOptions = false
    @Published var showingRecurringDeleteOptions = false
    @Published var showingEditModeDialog = false
    @Published var selectedEditMode: RecurringEditMode = .thisOnly

    var googleColorName: String? {
        guard let colorId = formModel.googleCalendarColorId else { return nil }
        return GoogleCalendarColors.standard.first(where: { $0.id == colorId })?.name
    }
    
    var isEditing: Bool { sessionToEdit != nil }
    
    var canCreateSession: Bool {
        formModel.hasBasicRequiredFields
    }

    @Published var formIsValid: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    private func setupValidation() {
        // Validation logic now directly uses formModel's validation
        $formModel
            .map { $0.hasBasicRequiredFields && $0.validateForm().isEmpty }
            .assign(to: \.formIsValid, on: self)
            .store(in: &cancellables)
    }

    init(
        context: ModelContext,
        session: SessionEntity?,
        instanceDate: Date?
    ) {
        self.modelContext = context
        self.sessionModificationService = SessionModificationService(context: context, eventKitService: EventKitSyncService.shared, recurrenceRuleBuilder: RecurrenceRuleBuilder())
        self.sessionToEdit = session
        
        if let session = session {
            self.formModel = SessionFormModel(from: session)
            self.selectedClient = session.client
            self.selectedClientService = session.clientService
        } else {
            self.formModel = SessionFormModel()
            self.formModel.startTime = instanceDate ?? Date()
            self.formModel.endTime = (instanceDate ?? Date()).addingTimeInterval(3600)
        }
        
        setupValidation()
        
        // Listen to changes in formModel.selectedClientID and selectedClientServiceID
        $formModel
            .map { $0.selectedClientID }
            .removeDuplicates()
            .sink { [weak self] newID in
                guard let self = self else { return }
                self.selectedClient = self.getClient(from: newID)
                // Clear service when client changes
                if self.formModel.selectedClientServiceID != nil && self.selectedClient?.id != newID {
                    self.formModel.selectedClientServiceID = nil
                }
            }
            .store(in: &cancellables)
        
        $formModel
            .map { $0.selectedClientServiceID }
            .removeDuplicates()
            .sink { [weak self] newID in
                guard let self = self else { return }
                self.selectedClientService = self.getService(from: newID)
            }
            .store(in: &cancellables)
    }
    
    // Simplified init for creating from an EKEvent
    init(context: ModelContext, from event: EKEvent) {
        self.modelContext = context
        self.sessionModificationService = SessionModificationService(context: context, eventKitService: EventKitSyncService.shared, recurrenceRuleBuilder: RecurrenceRuleBuilder())
        self.formModel = SessionFormModel(from: event)
        
        setupValidation()
        
        // Listen to changes in formModel.selectedClientID and selectedClientServiceID
        $formModel
            .map { $0.selectedClientID }
            .removeDuplicates()
            .sink { [weak self] newID in
                guard let self = self else { return }
                self.selectedClient = self.getClient(from: newID)
                // Clear service when client changes
                if self.formModel.selectedClientServiceID != nil && self.selectedClient?.id != newID {
                    self.formModel.selectedClientServiceID = nil
                }
            }
            .store(in: &cancellables)
        
        $formModel
            .map { $0.selectedClientServiceID }
            .removeDuplicates()
            .sink { [weak self] newID in
                guard let self = self else { return }
                self.selectedClientService = self.getService(from: newID)
            }
            .store(in: &cancellables)
    }
    
    func hasGoogleColor() -> Bool {
        return formModel.googleCalendarColorId != nil
    }

    func getGoogleColor() -> Color? {
        guard formModel.useGoogleColor, let colorId = formModel.googleCalendarColorId else { return nil }
        return GoogleCalendarColors.googleColorMap[colorId]
    }

    /// Call this from the Save button. If editing a recurring session, show dialog; else, save immediately.
    func handleSaveButtonTapped() {
        // Prevent multiple simultaneous save operations
        guard !isSaving else {
            print("[NewSessionViewModel] Save already in progress, ignoring duplicate request")
            return
        }
        
        // Validate the form model first
        let validationErrors = formModel.validateForm()
        if !validationErrors.isEmpty {
            self.saveError = validationErrors.map { $0.localizedDescription }.joined(separator: "\n")
            return
        } else {
            self.saveError = nil
        }
        
        if formModel.hasRecurrence && sessionToEdit != nil {
            showingEditModeDialog = true
        } else {
            // Not recurring, or new session: save as normal
            executeSave(with: .thisOnly)
        }
    }

    /// Call this after user selects an edit mode in the dialog
    func completeSaveWithSelectedMode() {
        showingEditModeDialog = false
        executeSave(with: selectedEditMode)
    }
    
    /// Main save method with comprehensive error handling and state management
    func executeSave(with span: RecurringEditMode) {
        // Prevent multiple simultaneous save operations
        guard !isSaving else {
            print("[NewSessionViewModel] Save already in progress, ignoring duplicate request")
            return
        }
        
        // Cancel any existing save task
        saveTask?.cancel()
        
        // Start new save task
        saveTask = Task { @MainActor in
            await performSave(with: span)
        }
    }
    
    /// Internal save implementation with proper error handling
    private func performSave(with span: RecurringEditMode) async {
        // Set saving state
        isSaving = true
        saveError = nil
        
        defer {
            // Always reset saving state when done
            isSaving = false
        }
        
        if isEditing, let session = sessionToEdit {
            // Determine the appropriate edit mode for recurring sessions
            let span: RecurringEditMode = session.recurrenceRule != nil ? .thisOnly : .thisOnly
            let modificationResult = sessionModificationService.modifySession(session, with: formModel, mode: span, originalInstanceDate: session.occurrenceDate)
            
            switch modificationResult {
            case .success(let result):
                if case .sessionModified(let s) = result {
                    print("[NewSessionViewModel] Session modified successfully: \(s.id.uuidString)")
                } else if case .detachedInstanceCreated(let s) = result {
                    print("[NewSessionViewModel] Detached instance created: \(s.id.uuidString)")
                } else if case .seriesSplit(_, let newSeries) = result {
                    print("[NewSessionViewModel] Series split, new series created: \(newSeries.id.uuidString)")
                }
                onSaveCompleted?()
            case .failure(let error):
                print("[NewSessionViewModel] Save failed: \(error.localizedDescription)")
                self.saveError = error.localizedDescription
            }
        } else {
            let creationResult = sessionModificationService.createSession(from: formModel)
            
            switch creationResult {
            case .success(let session):
                print("[NewSessionViewModel] Session created successfully: \(session.id.uuidString)")
                onSaveCompleted?()
            case .failure(let error):
                print("[NewSessionViewModel] Save failed: \(error.localizedDescription)")
                self.saveError = error.localizedDescription
            }
        }
    }
    
    /// Cleanup method to cancel any ongoing operations
    func cleanup() {
        saveTask?.cancel()
        saveTask = nil
        isSaving = false
        saveError = nil
        
        // Reset dialog states
        showingRecurringEditOptions = false
        showingRecurringDeleteOptions = false
        showingEditModeDialog = false
    }
    
    /// Legacy save method for backward compatibility
    func save() {
        handleSaveButtonTapped() // Redirect to new flow
    }
    
    /// Delete method with proper state management
    func delete() {
        print("[NewSessionViewModel] delete() called. isEditing: \(isEditing), sessionToEdit: \(String(describing: sessionToEdit?.id))")
        
        guard let sessionToDelete = sessionToEdit else { return }
        
        if sessionToDelete.recurrenceRuleData != nil {
            showingRecurringDeleteOptions = true
        } else {
            Task { @MainActor in
                executeDelete(with: .thisOnly)
            }
        }
    }
    
    /// Execute delete with proper error handling
    @MainActor func executeDelete(with span: RecurringEditMode) {
        guard let sessionToDelete = sessionToEdit else { return }
        
        let result = sessionModificationService.deleteSession(sessionToDelete, mode: span, originalInstanceDate: sessionToDelete.occurrenceDate)
        
        switch result {
        case .success(_):
            print("[NewSessionViewModel] Session deletion successful.")
            onSaveCompleted?()
        case .failure(let error):
            print("[NewSessionViewModel] Session deletion failed: \(error)")
            self.saveError = error.localizedDescription // Use saveError for delete errors too
        }
    }
    
    // MARK: - Helper Methods to fetch related entities for display
    private func getClient(from id: UUID?) -> ClientEntity? {
        guard let clientID = id else { return nil }
        let descriptor = FetchDescriptor<ClientEntity>(predicate: #Predicate { $0.id == clientID })
        return try? modelContext.fetch(descriptor).first
    }

    private func getService(from id: UUID?) -> ClientServiceEntity? {
        guard let serviceID = id else { return nil }
        let descriptor = FetchDescriptor<ClientServiceEntity>(predicate: #Predicate { $0.id == serviceID })
        return try? modelContext.fetch(descriptor).first
    }
    
    // MARK: - Address Handling
    
    func updateAddressFromSearchResult(_ address: AddressData) {
        formModel.unitNumber = address.unitNumber ?? ""
        formModel.streetNumber = address.streetNumber ?? ""
        formModel.streetName = address.streetName ?? ""
        formModel.suburb = address.suburb ?? ""
        formModel.state = address.state ?? ""
        formModel.postcode = address.postcode ?? ""
        formModel.country = address.country ?? ""
        formModel.poBox = address.poBox ?? ""
        if let coordinate = address.coordinate {
            formModel.sessionLatitude = coordinate.latitude
            formModel.sessionLongitude = coordinate.longitude
        }
    }
}

// Recurrence Summary Text Extension
extension NewSessionViewModel {
    var recurrenceSummaryText: String {
        guard formModel.hasRecurrence else { return "Does not repeat" }
        
        let frequency = formModel.recurrenceFrequency
        let interval = formModel.recurrenceInterval
        
        var summary = "Every \(interval) \(pluralizeUnit(frequency, interval: interval))"
        
        if frequency == .weekly && !formModel.selectedWeekdays.isEmpty {
            let weekdays = formModel.selectedWeekdays.sorted { $0.rawValue < $1.rawValue }.map { $0.shortName }.joined(separator: ", ")
            summary += " on \(weekdays)"
        }
        
        switch formModel.recurrenceEndType {
        case .afterCount:
            summary += " for \(formModel.recurrenceCount) occurrences"
        case .onDate:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            summary += " until \(formatter.string(from: formModel.recurrenceEndDate))"
        case .never:
            break
        }
        
        return summary
    }
    
    private func pluralizeUnit(_ frequency: RecurrenceFrequency, interval: Int) -> String {
        let unit: String
        switch frequency {
        case .daily: unit = interval == 1 ? "day" : "days"
        case .weekly: unit = interval == 1 ? "week" : "weeks"
        case .monthly: unit = interval == 1 ? "month" : "months"
        case .yearly: unit = interval == 1 ? "year" : "years"
        case .none: unit = "day" // Should not happen if hasRecurrence is true
        }
        return unit
    }
} 

