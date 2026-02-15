//
//  NewSessionViewModel.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Refactoring Initiative
//
import Foundation
import SwiftUI
import SwiftData
import Core
import EventKit // Needed for EKEvent
import MapKit
import Combine
import Data
import SharedUI

// MARK: - New Session ViewModel

/// Coordinates session create/edit form state, validation, save/delete, and recurring-edit dialogs.
@MainActor
class NewSessionViewModel: ObservableObject {
    // MARK: - Dependencies
    let unitOfWork: UnitOfWorkService
    let sessionModificationService: SessionModificationService
    
    /// Address repository for fetching addresses (used by NativeSessionFormView)
    var addressRepository: AddressRepository {
        unitOfWork.addresses
    }
    
    // MARK: - State
    var sessionToEdit: Session?
    
    // MARK: - Save State Management
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var persistenceError: String? = nil
    private var saveTask: Task<Void, Never>? = nil
    private var deleteTask: Task<Void, Never>? = nil
    private var pendingSaveSnapshot: SessionFormModel? = nil
    
    // MARK: - Callback Management
    var onSave: ((RecurringEditMode) -> Void)?
    var onSaveCompleted: (() -> Void)?
    var onDelete: ((RecurringEditMode) -> Void)?
    
    // MARK: - Form State
    @Published var formModel: SessionFormModel
    
    // MARK: - Client & Service Domain Models
    @Published var selectedClient: Client?
    @Published var selectedClientService: ClientService?
    @Published var availableClients: [Client] = []
    @Published var availableServices: [ClientService] = []
    private var clientLookupTask: Task<Void, Never>?
    private var serviceLookupTask: Task<Void, Never>?
    private var servicesLoadedForClientID: UUID?
    
    // MARK: - Instance Date Tracking
    private var originalInstanceDate: Date?
    private var lastSelectedClientID: UUID?
    
    // MARK: - Dialog State Management
    @Published var showingRecurringDeleteOptions = false
    @Published var showingEditModeDialog = false

    var googleColorName: String? {
        guard let colorId = formModel.googleCalendarColorId else { return nil }
        return GoogleCalendarColors.standard.first(where: { $0.id == colorId })?.name
    }
    
    var isEditing: Bool { sessionToEdit != nil }

    /// True when editing an existing session that has recurrence (series).
    var isEditingRecurringSession: Bool { sessionToEdit?.recurrenceRuleData != nil }
    
    var canCreateSession: Bool {
        formModel.hasBasicRequiredFields
    }
    
    var isPerformingPersistence: Bool {
        isSaving || isDeleting
    }

    var requiresSaveScopeSelection: Bool {
        availableSaveModes.count > 1
    }

    var requiresDeleteScopeSelection: Bool {
        availableDeleteModes.count > 1
    }

    var saveButtonTitle: String {
        isEditing ? "Save Changes" : "Create Session"
    }

    var availableSaveModes: [RecurringEditMode] {
        if isEditingRecurringSession {
            // Editing the series master (no clicked occurrence) only supports series-wide updates.
            if originalInstanceDate == nil {
                return [.all]
            }
            return [.thisOnly, .thisAndFuture, .all]
        }

        // Event conversion with recurrence supports either one-off or full-series creation.
        if !isEditing && formModel.sourceEventIdentifier != nil && formModel.hasRecurrence {
            return [.thisOnly, .all]
        }

        return [.thisOnly]
    }

    var availableDeleteModes: [RecurringEditMode] {
        guard let session = sessionToEdit, session.recurrenceRuleData != nil else {
            return [.thisOnly]
        }
        // Deleting from master context should delete the full series.
        if originalInstanceDate == nil {
            return [.all]
        }
        return [.thisOnly, .thisAndFuture, .all]
    }

    func saveScopeTitle(for mode: RecurringEditMode) -> String {
        mode.title
    }

    func deleteScopeTitle(for mode: RecurringEditMode) -> String {
        "Delete \(mode.title)"
    }

    var recommendedSaveMode: RecurringEditMode? {
        if availableSaveModes.contains(.thisAndFuture) { return .thisAndFuture }
        return availableSaveModes.first
    }

    var recommendedDeleteMode: RecurringEditMode? {
        if availableDeleteModes.contains(.thisOnly) { return .thisOnly }
        return availableDeleteModes.first
    }

    @Published var formIsValid: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    private func setupValidation() {
        $formModel
            .map { $0.hasBasicRequiredFields && $0.validateForm().isEmpty }
            .assign(to: \.formIsValid, on: self)
            .store(in: &cancellables)
    }

    init(
        unitOfWork: UnitOfWorkService,
        session: Session?,
        instanceDate: Date?,
        instanceEndDate: Date?
    ) {
        self.unitOfWork = unitOfWork
        self.sessionModificationService = SessionModificationService(
            unitOfWork: unitOfWork,
            eventKitService: EventKitSyncService.shared,
            recurrenceRuleBuilder: RecurrenceRuleBuilder()
        )
        self.sessionToEdit = session
        self.originalInstanceDate = instanceDate
        
        if let session = session {
            self.formModel = SessionFormModel(from: session)
            self.lastSelectedClientID = self.formModel.selectedClientID
            
            // Fetch address if addressId is present
            if let addressId = session.addressId {
                Task {
                    if let address = try? await unitOfWork.addresses.fetch(by: addressId) {
                        await MainActor.run {
                            populateFormFromAddress(address)
                        }
                    }
                }
            }
            
            // Keep `originalInstanceDate` nil when editing from the master context.
            // A non-nil value should only represent a concrete tapped occurrence.

            if let clickedStart = instanceDate {
                var updated = self.formModel
                updated.startTime = clickedStart
                if let clickedEnd = instanceEndDate {
                    updated.endTime = clickedEnd
                } else if let sessionStart = session.startTime, let sessionEnd = session.endTime {
                    updated.endTime = clickedStart.addingTimeInterval(max(0, sessionEnd.timeIntervalSince(sessionStart)))
                }
                self.formModel = updated
            }
            
            // Fetch client and service asynchronously
            Task {
                await self.preloadExistingSelections(from: session)
                await self.preloadExistingSupportLog(from: session)
            }
        } else {
            self.formModel = SessionFormModel()
            let start = instanceDate ?? Date()
            self.formModel.startTime = start
            self.formModel.endTime = instanceEndDate ?? start.addingTimeInterval(3600)
            self.lastSelectedClientID = self.formModel.selectedClientID
        }
        
        setupValidation()
        
        // Setup subscribers
        setupSubscribers()
        
        // Initial fetch of clients for picker
        Task {
            do {
                self.availableClients = try await unitOfWork.clients.fetchAll()
                self.reconcilePickerSelections()
            } catch {
                // Clients list remains empty; user can retry by reopening the form
            }
        }
    }
    
    // Simplified init for creating from an EKEvent
    init(
        unitOfWork: UnitOfWorkService,
        from event: EKEvent
    ) {
        self.unitOfWork = unitOfWork
        self.sessionModificationService = SessionModificationService(
            unitOfWork: unitOfWork,
            eventKitService: EventKitSyncService.shared,
            recurrenceRuleBuilder: RecurrenceRuleBuilder()
        )
        self.formModel = SessionFormModel(from: event)
        self.lastSelectedClientID = self.formModel.selectedClientID
        
        setupValidation()
        setupSubscribers()
        
        Task {
            do {
                self.availableClients = try await unitOfWork.clients.fetchAll()
                self.reconcilePickerSelections()
            } catch {
                // Clients list remains empty; user can retry by reopening the form
            }
        }
    }
    
    private func setupSubscribers() {
        // Listen to changes in formModel.selectedClientID
        $formModel
            .map { $0.selectedClientID }
            .removeDuplicates()
            .sink { [weak self] newID in
                guard let self = self else { return }
                let previousID = self.lastSelectedClientID
                self.lastSelectedClientID = newID
                self.clientLookupTask?.cancel()
                self.serviceLookupTask?.cancel()

                guard let newID = newID else {
                    self.selectedClient = nil
                    self.selectedClientService = nil
                    self.availableServices = []
                    self.servicesLoadedForClientID = nil
                    return
                }

                if let previousID, previousID != newID {
                    self.selectedClientService = nil
                }
                // Prevent stale services from the previously selected client being reused.
                self.availableServices = []
                self.servicesLoadedForClientID = nil

                let requestedClientID = newID
                self.clientLookupTask = Task { [weak self] in
                    guard let self = self else { return }

                    let fetchedClient = try? await self.unitOfWork.clients.fetch(by: requestedClientID)
                    let fetchedServices = (try? await self.unitOfWork.clientServices.fetch(for: requestedClientID)) ?? []

                    guard !Task.isCancelled else { return }
                    guard self.formModel.selectedClientID == requestedClientID else { return }

                    self.selectedClient = fetchedClient ?? self.availableClients.first(where: { $0.id == requestedClientID })
                    self.availableServices = fetchedServices
                    self.servicesLoadedForClientID = requestedClientID

                    if let selectedServiceID = self.formModel.selectedClientServiceID {
                        if let matchedService = fetchedServices.first(where: { $0.id == selectedServiceID }) {
                            self.selectedClientService = matchedService
                        } else {
                            self.selectedClientService = nil
                        }
                    } else {
                        self.selectedClientService = nil
                    }

                    self.reconcilePickerSelections()
                }
            }
            .store(in: &cancellables)
        
        // Listen to changes in formModel.selectedClientServiceID
        $formModel
            .map { $0.selectedClientServiceID }
            .removeDuplicates()
            .sink { [weak self] newID in
                guard let self = self else { return }
                self.serviceLookupTask?.cancel()
                guard let newID = newID else {
                    self.selectedClientService = nil
                    return
                }

                if let localMatch = self.availableServices.first(where: { $0.id == newID }) {
                    self.selectedClientService = localMatch
                    return
                }

                guard let clientId = self.formModel.selectedClientID else {
                    self.selectedClientService = nil
                    return
                }

                let requestedClientID = clientId
                let requestedServiceID = newID
                self.serviceLookupTask = Task { [weak self] in
                    guard let self = self else { return }
                    let services = (try? await self.unitOfWork.clientServices.fetch(for: requestedClientID)) ?? []

                    guard !Task.isCancelled else { return }
                    guard self.formModel.selectedClientID == requestedClientID,
                          self.formModel.selectedClientServiceID == requestedServiceID else { return }

                    self.availableServices = services
                    self.servicesLoadedForClientID = requestedClientID
                    self.selectedClientService = services.first(where: { $0.id == requestedServiceID })
                    self.reconcilePickerSelections()
                }
            }
            .store(in: &cancellables)
    }

    func updateSelectedClientID(_ newID: UUID?) {
        var updated = formModel
        let previousID = updated.selectedClientID
        updated.selectedClientID = newID
        if previousID != newID {
            updated.selectedClientServiceID = nil
            servicesLoadedForClientID = nil
        }
        formModel = updated
    }

    func updateSelectedClientServiceID(_ newID: UUID?) {
        var updated = formModel
        updated.selectedClientServiceID = newID
        formModel = updated
    }
    
    /// Returns a two-way binding for a form field that correctly updates the stored struct (read-modify-write).
    func formBinding<T>(_ keyPath: WritableKeyPath<SessionFormModel, T>) -> Binding<T> {
        Binding(
            get: { self.formModel[keyPath: keyPath] },
            set: { [self] newValue in
                var updated = self.formModel
                updated[keyPath: keyPath] = newValue
                self.formModel = updated
            }
        )
    }

    func hasGoogleColor() -> Bool {
        return formModel.googleCalendarColorId != nil
    }

    func getGoogleColor() -> Color? {
        guard formModel.useGoogleColor, let colorId = formModel.googleCalendarColorId else { return nil }
        return GoogleCalendarColors.googleColorMap[colorId]
    }

    func handleSaveButtonTapped() {
        guard !isPerformingPersistence else { return }

        let normalizedSnapshot = normalizedFormSnapshotForPersistence(from: formModel)
        formModel = normalizedSnapshot

        let validationErrors = normalizedSnapshot.validateForm()
        if !validationErrors.isEmpty {
            self.persistenceError = validationErrors.map { $0.localizedDescription }.joined(separator: "\n")
            pendingSaveSnapshot = nil
            return
        } else {
            self.persistenceError = nil
        }
        
        let availableModes = availableSaveModes
        if availableModes.count > 1 {
            pendingSaveSnapshot = normalizedSnapshot
            presentSaveScopePicker()
        } else {
            executeSave(with: availableModes.first ?? .thisOnly, using: normalizedSnapshot)
        }
    }
    
    func executeSave(with span: RecurringEditMode, using providedSnapshot: SessionFormModel? = nil) {
        guard !isPerformingPersistence else { return }

        let formSnapshot = providedSnapshot
            ?? pendingSaveSnapshot
            ?? normalizedFormSnapshotForPersistence(from: formModel)
        formModel = formSnapshot

        let validationErrors = formSnapshot.validateForm()
        if !validationErrors.isEmpty {
            persistenceError = validationErrors.map { $0.localizedDescription }.joined(separator: "\n")
            pendingSaveSnapshot = nil
            showingEditModeDialog = false
            return
        }

        isSaving = true
        persistenceError = nil
        showingEditModeDialog = false
        pendingSaveSnapshot = nil
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            await persistFormSnapshot(formSnapshot, with: span)
        }
    }
    
    private func persistFormSnapshot(_ formSnapshot: SessionFormModel, with span: RecurringEditMode) async {
        defer {
            isSaving = false
            saveTask = nil
        }
        
        if isEditing, let session = sessionToEdit {
            let instanceDate = session.recurrenceRuleData != nil ? originalInstanceDate : nil
            let effectiveSpan = normalizedEditMode(span, session: session, instanceDate: instanceDate)
            let modelToSave = adjustedFormModelForSave(formSnapshot, span: effectiveSpan, session: session)
            do {
                let savedSession = try await sessionModificationService.modifySession(
                    session,
                    with: modelToSave,
                    mode: effectiveSpan,
                    originalInstanceDate: instanceDate
                )
                try await persistSupportLogIfNeeded(for: savedSession, using: modelToSave)
                notifySuccessfulSave(using: effectiveSpan)
            } catch is CancellationError {
                return
            } catch {
                self.persistenceError = userFacingErrorMessage(for: error)
            }
        } else {
            let effectiveSpan = normalizedCreateMode(span, formSnapshot: formSnapshot)
            let modelToSave = adjustedCreateFormModelForSave(formSnapshot, span: effectiveSpan)
            do {
                let savedSession = try await sessionModificationService.createSession(from: modelToSave)
                try await persistSupportLogIfNeeded(for: savedSession, using: modelToSave)
                notifySuccessfulSave(using: effectiveSpan)
            } catch is CancellationError {
                return
            } catch {
                self.persistenceError = userFacingErrorMessage(for: error)
            }
        }
    }

    private func notifySuccessfulSave(using span: RecurringEditMode) {
        onSave?(span)
        onSaveCompleted?()
    }
    
    func cleanup() {
        clientLookupTask?.cancel()
        clientLookupTask = nil
        serviceLookupTask?.cancel()
        serviceLookupTask = nil
        saveTask?.cancel()
        saveTask = nil
        deleteTask?.cancel()
        deleteTask = nil
        pendingSaveSnapshot = nil
        isSaving = false
        isDeleting = false
        persistenceError = nil
        showingRecurringDeleteOptions = false
        showingEditModeDialog = false
    }
    
    func delete() {
        guard !isPerformingPersistence,
              sessionToEdit != nil else { return }
        let availableModes = availableDeleteModes
        if availableModes.count > 1 {
            presentDeleteScopePicker()
        } else {
            executeDelete(with: availableModes.first ?? .thisOnly)
        }
    }
    
    func executeDelete(with span: RecurringEditMode) {
        guard !isPerformingPersistence,
              let sessionSnapshot = sessionToEdit else { return }
        showingRecurringDeleteOptions = false
        persistenceError = nil
        pendingSaveSnapshot = nil
        isDeleting = true
        let instanceDateSnapshot = sessionSnapshot.recurrenceRuleData != nil ? originalInstanceDate : nil
        deleteTask?.cancel()
        deleteTask = Task { @MainActor in
            await persistDeleteSession(
                sessionSnapshot,
                span: span,
                instanceDate: instanceDateSnapshot
            )
        }
    }

    private func persistDeleteSession(
        _ sessionToDelete: Session,
        span: RecurringEditMode,
        instanceDate: Date?
    ) async {
        defer {
            isDeleting = false
            deleteTask = nil
        }

        do {
            let effectiveSpan = normalizedDeleteMode(span, session: sessionToDelete, instanceDate: instanceDate)
            try await sessionModificationService.deleteSession(sessionToDelete, mode: effectiveSpan, originalInstanceDate: instanceDate)
            onDelete?(effectiveSpan)
            onSaveCompleted?()
        } catch is CancellationError {
            return
        } catch {
            self.persistenceError = userFacingErrorMessage(for: error)
        }
    }

    private func adjustedFormModelForSave(_ model: SessionFormModel, span: RecurringEditMode, session: Session?) -> SessionFormModel {
        guard span == .all,
              let session,
              session.recurrenceRuleData != nil,
              let masterStart = session.startTime,
              let clickedStart = originalInstanceDate else {
            return model
        }

        let calendar = Calendar.current
        guard !calendar.isDate(masterStart, inSameDayAs: clickedStart),
              calendar.isDate(model.startTime, inSameDayAs: clickedStart) else {
            return model
        }

        var adjusted = model
        let duration = max(0, model.endTime.timeIntervalSince(model.startTime))
        let adjustedStart: Date
        if model.isAllDay {
            adjustedStart = calendar.startOfDay(for: masterStart)
        } else {
            adjustedStart = dateByCombining(dayFrom: masterStart, timeFrom: model.startTime, calendar: calendar)
        }

        adjusted.startTime = adjustedStart
        adjusted.endTime = adjustedStart.addingTimeInterval(duration)
        return adjusted
    }

    private func adjustedCreateFormModelForSave(_ model: SessionFormModel, span: RecurringEditMode) -> SessionFormModel {
        guard span == .thisOnly else {
            return model
        }

        // "This Event Only" during conversion should create a single non-recurring session.
        var adjusted = model
        adjusted.recurrenceFrequency = .none
        return adjusted
    }

    private func normalizedEditMode(_ requested: RecurringEditMode, session: Session, instanceDate: Date?) -> RecurringEditMode {
        guard session.recurrenceRuleData != nil else {
            return .thisOnly
        }
        // Without a concrete occurrence context, only full-series edits are valid.
        guard instanceDate != nil else {
            return .all
        }
        return requested
    }

    private func normalizedDeleteMode(_ requested: RecurringEditMode, session: Session, instanceDate: Date?) -> RecurringEditMode {
        guard session.recurrenceRuleData != nil else {
            return .thisOnly
        }
        // Without a concrete occurrence context, only full-series deletes are valid.
        guard instanceDate != nil else {
            return .all
        }
        return requested
    }

    private func normalizedCreateMode(_ requested: RecurringEditMode, formSnapshot: SessionFormModel) -> RecurringEditMode {
        // Only recurring event conversions should accept scope choices while creating.
        guard formSnapshot.sourceEventIdentifier != nil, formSnapshot.hasRecurrence else {
            return .thisOnly
        }
        // For a newly-created series, "this and future" is equivalent to "all".
        if requested == .thisAndFuture {
            return .all
        }
        return requested
    }

    private func dateByCombining(dayFrom date: Date, timeFrom timeSource: Date, calendar: Calendar) -> Date {
        let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: timeSource)
        var dayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dayComponents.hour = timeComponents.hour
        dayComponents.minute = timeComponents.minute
        dayComponents.second = timeComponents.second
        dayComponents.nanosecond = timeComponents.nanosecond
        return calendar.date(from: dayComponents) ?? date
    }

    private func userFacingErrorMessage(for error: Error) -> String {
        if let repositoryError = error as? RepositoryError {
            return repositoryError.localizedDescription
        }
        let nsError = error as NSError
        if nsError.domain.contains("RepositoryError") {
            switch nsError.code {
            case 0:
                return "The selected record could not be found."
            case 1:
                return "A duplicate record prevented saving."
            case 2:
                return "A persistence error occurred while saving."
            case 3:
                return "The selected service does not match the selected client."
            case 4:
                return "A concurrent change was detected. Please try saving again."
            case 5:
                return "The selected record no longer exists."
            case 6:
                return "Saving failed. Please try again."
            default:
                break
            }
        }
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }
        return error.localizedDescription
    }

    private func normalizedFormSnapshotForPersistence(from model: SessionFormModel) -> SessionFormModel {
        var normalized = model

        if normalized.selectedClientID == nil, let selectedClient {
            normalized.selectedClientID = selectedClient.id
        }

        if normalized.selectedClientServiceID == nil, let selectedClientService {
            normalized.selectedClientServiceID = selectedClientService.id
        }

        if let selectedServiceID = normalized.selectedClientServiceID,
           let resolvedService = resolveClientService(for: selectedServiceID) {
            if normalized.selectedClientID == nil || normalized.selectedClientID != resolvedService.clientId {
                normalized.selectedClientID = resolvedService.clientId
            }
        }

        if normalized.supportLogDraft.isEnabled {
            if normalized.supportLogDraft.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                normalized.supportLogDraft.location = normalized.location
            }
            if normalized.supportLogDraft.serviceDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                normalized.supportLogDraft.serviceDescription = normalized.title
            }
            if normalized.supportLogDraft.deliveredFrom > normalized.supportLogDraft.deliveredTo {
                normalized.supportLogDraft.deliveredTo = normalized.supportLogDraft.deliveredFrom.addingTimeInterval(3600)
            }
        }

        return normalized
    }

    private func persistSupportLogIfNeeded(for session: Session, using model: SessionFormModel) async throws {
        guard model.supportLogDraft.isEnabled else { return }
        guard let clientId = session.clientId else {
            throw RepositoryError.validationFailed(message: "A client is required to save support log details.")
        }

        let draft = model.supportLogDraft
        let existing = try await unitOfWork.supportLogs.fetchBySession(session.id).first
        let quantityHours = max(draft.deliveredTo.timeIntervalSince(draft.deliveredFrom), 0) / 3600.0

        let log = SupportLog(
            id: existing?.id ?? UUID(),
            clientId: clientId,
            sessionId: session.id,
            participantName: draft.participantName,
            participantNdisNumber: draft.participantNdisNumber,
            supportItemNumber: draft.supportItemNumber,
            serviceDescription: draft.serviceDescription,
            location: draft.location,
            deliveredFrom: draft.deliveredFrom,
            deliveredTo: draft.deliveredTo,
            quantityHours: quantityHours > 0 ? quantityHours : 1.0,
            deliveredBy: draft.deliveredBy,
            attestedBy: draft.attestedBy,
            attestedAt: draft.attestedAt,
            signatureMethod: draft.signatureMethod,
            signedBy: draft.signedBy,
            signedAt: draft.signedAt,
            cancellationReasonCode: draft.cancellationReasonCode,
            notes: draft.notes
        )

        if existing != nil {
            _ = try await unitOfWork.supportLogs.update(log)
        } else {
            _ = try await unitOfWork.supportLogs.create(log)
        }
    }

    private func resolveClientService(for serviceID: UUID) -> ClientService? {
        if selectedClientService?.id == serviceID {
            return selectedClientService
        }
        return availableServices.first(where: { $0.id == serviceID })
    }

    private func preloadExistingSelections(from session: Session) async {
        var loadedService: ClientService? = nil
        if let serviceId = session.clientServiceId {
            loadedService = try? await unitOfWork.clientServices.fetch(by: serviceId)
        }

        let resolvedClientID = session.clientId ?? loadedService?.clientId
        if let resolvedClientID {
            selectedClient = try? await unitOfWork.clients.fetch(by: resolvedClientID)

            var updated = formModel
            if updated.selectedClientID != resolvedClientID {
                updated.selectedClientID = resolvedClientID
            }
            if let loadedService, updated.selectedClientServiceID != loadedService.id {
                updated.selectedClientServiceID = loadedService.id
            }
            formModel = updated

            let services = (try? await unitOfWork.clientServices.fetch(for: resolvedClientID)) ?? []
            availableServices = services
            servicesLoadedForClientID = resolvedClientID
        }

        if let loadedService {
            selectedClientService = loadedService
            if !availableServices.contains(where: { $0.id == loadedService.id }) {
                availableServices.insert(loadedService, at: 0)
            }
        }

        reconcilePickerSelections()
    }

    private func preloadExistingSupportLog(from session: Session) async {
        guard let log = try? await unitOfWork.supportLogs.fetchBySession(session.id).first else { return }
        var updated = formModel
        updated.supportLogDraft = SessionSupportLogDraft(
            isEnabled: true,
            participantName: log.participantName,
            participantNdisNumber: log.participantNdisNumber,
            supportItemNumber: log.supportItemNumber,
            serviceDescription: log.serviceDescription,
            location: log.location,
            deliveredFrom: log.deliveredFrom,
            deliveredTo: log.deliveredTo,
            deliveredBy: log.deliveredBy,
            attestedBy: log.attestedBy,
            attestedAt: log.attestedAt,
            signatureMethod: log.signatureMethod,
            signedBy: log.signedBy,
            signedAt: log.signedAt,
            cancellationReasonCode: log.cancellationReasonCode,
            notes: log.notes
        )
        formModel = updated
    }

    private func presentSaveScopePicker() {
        showingRecurringDeleteOptions = false
        showingEditModeDialog = true
    }

    private func presentDeleteScopePicker() {
        showingEditModeDialog = false
        showingRecurringDeleteOptions = true
    }

    private func reconcilePickerSelections() {
        let validServiceIDs = Set(availableServices.map(\.id) + (selectedClientService.map { [$0.id] } ?? []))

        var updated = formModel
        var changed = false

        if updated.selectedClientID == nil, updated.selectedClientServiceID != nil {
            updated.selectedClientServiceID = nil
            selectedClientService = nil
            changed = true
        }

        if let selectedServiceID = updated.selectedClientServiceID,
           let selectedClientID = updated.selectedClientID,
           servicesLoadedForClientID == selectedClientID,
           !validServiceIDs.contains(selectedServiceID) {
            updated.selectedClientServiceID = nil
            selectedClientService = nil
            changed = true
        }

        if changed {
            formModel = updated
        }
    }
    
    // MARK: - Address Handling
    
    func updateAddressFromSearchResult(_ address: AddressData) {
        var updated = formModel
        updated.unitNumber = address.unitNumber
        updated.streetNumber = address.streetNumber
        updated.streetName = address.streetName
        updated.suburb = address.suburb
        updated.city = address.city
        updated.state = address.state
        updated.postcode = address.postcode
        updated.country = address.country
        updated.poBox = address.poBox
        formModel = updated
    }

    func clearFormAddress() {
        var updated = formModel
        updated.unitNumber = ""
        updated.streetNumber = ""
        updated.streetName = ""
        updated.suburb = ""
        updated.city = ""
        updated.state = ""
        updated.postcode = ""
        updated.country = ""
        updated.poBox = ""
        updated.sessionLatitude = 0.0
        updated.sessionLongitude = 0.0
        updated.addressSearchText = ""
        updated.selectedAddress = nil
        formModel = updated
    }
    
    private func populateFormFromAddress(_ address: Address) {
        var updated = formModel
        updated.unitNumber = address.unitNumber
        updated.streetNumber = address.streetNumber
        updated.streetName = address.streetName
        updated.suburb = address.suburb
        updated.city = address.city
        updated.state = address.state
        updated.postcode = address.postcode
        updated.country = address.country
        updated.poBox = address.poBox
        updated.sessionLatitude = address.latitude
        updated.sessionLongitude = address.longitude
        formModel = updated
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
        case .none: unit = "day"
        }
        return unit
    }
}
