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
    var sessionToEdit: Session? // Changed to domain model
    let sessionModificationService: SessionModificationService // Made internal for CalendarViewModel access
    private let clientsRepository: ClientsRepository
    private let clientServicesRepository: ClientServicesRepository
    let addressRepository: AddressRepository
    
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
    @Published var selectedClient: Client?
    @Published var selectedClientService: ClientService?
    @Published var availableClients: [Client] = []
    @Published var availableServices: [ClientService] = []
    
    // MARK: - Instance Date Tracking
    private var originalInstanceDate: Date? // Store instance date for recurring session edits
    
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
        session: Session?,
        instanceDate: Date?,
        clientsRepository: ClientsRepository,
        clientServicesRepository: ClientServicesRepository,
        addressRepository: AddressRepository
    ) {
        self.modelContext = context
        self.clientsRepository = clientsRepository
        self.clientServicesRepository = clientServicesRepository
        self.addressRepository = addressRepository
        self.sessionModificationService = SessionModificationService(
            context: context,
            addressRepository: addressRepository,
            eventKitService: EventKitSyncService.shared,
            recurrenceRuleBuilder: RecurrenceRuleBuilder()
        )
        self.sessionToEdit = session
        self.originalInstanceDate = instanceDate // Store instance date for recurring session edits
        
        if let session = session {
            self.formModel = SessionFormModel(from: session)
            
            // Fetch address if addressId is present
            if let addressId = session.addressId {
                Task {
                    if let address = try? await addressRepository.fetch(by: addressId) {
                        await MainActor.run {
                            populateFormFromAddress(address)
                        }
                    }
                }
            }
            // If editing a recurring session and instanceDate is provided, use it
            // Otherwise, use the session's startTime as fallback for recurring sessions
            if session.recurrenceRuleData != nil {
                self.originalInstanceDate = instanceDate ?? session.startTime
            }
            // Fetch client and service asynchronously
            Task {
                if let clientId = session.clientId {
                    self.selectedClient = try? await clientsRepository.fetch(by: clientId)
                }
                if let serviceId = session.clientServiceId {
                    // Fetch service via client
                    if let clientId = session.clientId {
                        let services = try? await clientServicesRepository.fetch(for: clientId)
                        self.selectedClientService = services?.first(where: { $0.id == serviceId })
                    }
                }
            }
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
                guard let self = self, let newID = newID else { return }
                Task {
                    self.selectedClient = try? await self.clientsRepository.fetch(by: newID)
                    // Fetch services for the selected client
                    if let clientId = self.selectedClient?.id {
                        let services = try? await self.clientServicesRepository.fetch(for: clientId)
                        self.availableServices = services ?? []
                    } else {
                        self.availableServices = []
                    }
                }
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
                Task {
                    if let clientId = self.selectedClient?.id {
                        let services = try? await self.clientServicesRepository.fetch(for: clientId)
                        self.selectedClientService = services?.first(where: { $0.id == newID })
                    } else if let clientId = self.formModel.selectedClientID {
                        let services = try? await self.clientServicesRepository.fetch(for: clientId)
                        self.selectedClientService = services?.first(where: { $0.id == newID })
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // Simplified init for creating from an EKEvent
    init(
        context: ModelContext,
        from event: EKEvent,
        clientsRepository: ClientsRepository,
        clientServicesRepository: ClientServicesRepository,
        addressRepository: AddressRepository
    ) {
        self.modelContext = context
        self.clientsRepository = clientsRepository
        self.clientServicesRepository = clientServicesRepository
        self.addressRepository = addressRepository
        self.sessionModificationService = SessionModificationService(
            context: context,
            addressRepository: addressRepository,
            eventKitService: EventKitSyncService.shared,
            recurrenceRuleBuilder: RecurrenceRuleBuilder()
        )
        self.formModel = SessionFormModel(from: event)
        
        setupValidation()
        
        // Fetch available clients for picker
        Task {
            do {
                self.availableClients = try await clientsRepository.fetchAll()
            } catch {
                print("[NewSessionViewModel] Failed to fetch clients: \(error)")
            }
        }
        
        // Listen to changes in formModel.selectedClientID and selectedClientServiceID
        $formModel
            .map { $0.selectedClientID }
            .removeDuplicates()
            .sink { [weak self] newID in
                guard let self = self, let newID = newID else { return }
                Task {
                    self.selectedClient = try? await self.clientsRepository.fetch(by: newID)
                    // Fetch services for the selected client
                    if let clientId = self.selectedClient?.id {
                        let services = try? await self.clientServicesRepository.fetch(for: clientId)
                        self.availableServices = services ?? []
                    } else {
                        self.availableServices = []
                    }
                }
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
                Task {
                    if let clientId = self.selectedClient?.id {
                        let services = try? await self.clientServicesRepository.fetch(for: clientId)
                        self.selectedClientService = services?.first(where: { $0.id == newID })
                    } else if let clientId = self.formModel.selectedClientID {
                        let services = try? await self.clientServicesRepository.fetch(for: clientId)
                        self.selectedClientService = services?.first(where: { $0.id == newID })
                    }
                }
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
            // Use stored instance date for recurring session edits
            let instanceDate = session.recurrenceRuleData != nil ? originalInstanceDate : nil
            
            do {
                let modifiedSession = try await sessionModificationService.modifySession(
                    session,
                    with: formModel,
                    mode: span,
                    originalInstanceDate: instanceDate
                )
                print("[NewSessionViewModel] Session modified successfully: \(modifiedSession.id.uuidString)")
                onSaveCompleted?()
            } catch {
                print("[NewSessionViewModel] Save failed: \(error.localizedDescription)")
                self.saveError = error.localizedDescription
            }
        } else {
            do {
                let newSession = try await sessionModificationService.createSession(from: formModel)
                print("[NewSessionViewModel] Session created successfully: \(newSession.id.uuidString)")
                onSaveCompleted?()
            } catch {
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
                await executeDelete(with: .thisOnly)
            }
        }
    }
    
    /// Execute delete with proper error handling
    @MainActor func executeDelete(with span: RecurringEditMode) async {
        guard let sessionToDelete = sessionToEdit else { return }
        
        // Use stored instance date for recurring session deletes
        let instanceDate = sessionToDelete.recurrenceRuleData != nil ? originalInstanceDate : nil
        
        do {
            try await sessionModificationService.deleteSession(sessionToDelete, mode: span, originalInstanceDate: instanceDate)
            print("[NewSessionViewModel] Session deletion successful.")
            onSaveCompleted?()
        } catch {
            print("[NewSessionViewModel] Session deletion failed: \(error)")
            self.saveError = error.localizedDescription // Use saveError for delete errors too
        }
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
    
    private func populateFormFromAddress(_ address: Address) {
        formModel.unitNumber = address.unitNumber
        formModel.streetNumber = address.streetNumber
        formModel.streetName = address.streetName
        formModel.suburb = address.suburb
        formModel.state = address.state
        formModel.postcode = address.postcode
        formModel.country = address.country
        formModel.poBox = address.poBox
        formModel.sessionLatitude = address.latitude
        formModel.sessionLongitude = address.longitude
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

