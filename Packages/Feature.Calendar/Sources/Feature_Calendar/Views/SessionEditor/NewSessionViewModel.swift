import Foundation
import SwiftUI
import SwiftData
import Core
import EventKit // Needed for EKEvent
import MapKit
import Combine
import Data
import SharedUI

// MARK: - Session Status Enum



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
    
    // MARK: - Client & Service Domain Models (for display, fetched on demand)
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
            let span: RecurringEditMode = session.recurrenceRuleData != nil ? .thisOnly : .thisOnly
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
    
    // MARK: - Helper Methods to fetch related domain models for display
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
        formModel.unitNumber = address.unitNumber
        formModel.streetNumber = address.streetNumber
        formModel.streetName = address.streetName
        formModel.suburb = address.suburb
        formModel.state = address.state
        formModel.postcode = address.postcode
        formModel.country = address.country
        formModel.poBox = address.poBox
        // Note: AddressData no longer has coordinate property
        // Coordinates would need to be set separately if needed
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

