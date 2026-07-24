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
import Data
import SharedUI
import Observation

// MARK: - New Session ViewModel

struct PreloadedSessionData: Sendable {
    let clientID: UUID?
    let clientServiceID: UUID?
    let supportLog: SessionSupportLogDraft?
}

/// Coordinates session create/edit form state, validation, save/delete, and recurring-edit dialogs.
@Observable
@MainActor
class NewSessionViewModel {
    // MARK: - Dependencies
    let modelContext: ModelContext
    let sessionModificationService: SessionModificationService
    let recurrenceRuleManager: Core.RecurrenceRuleManager
    let sessionPrefetcher: CalendarSessionPrefetchActor
    
    // MARK: - State
    var sessionToEdit: Session?
    
    // MARK: - Save State Management
    var isSaving = false
    var isDeleting = false
    var persistenceError: String? = nil
    var saveTask: Task<Void, Never>? = nil
    var deleteTask: Task<Void, Never>? = nil
    var pendingSaveSnapshot: SessionFormModel? = nil
    
    // MARK: - Callback Management
    var onSave: ((RecurringEditMode) -> Void)?
    var onSaveCompleted: (() -> Void)?
    var onDelete: ((RecurringEditMode) -> Void)?
    
    // MARK: - Form State
    var formModel: SessionFormModel {
        didSet {
            formIsValid = formModel.hasBasicRequiredFields && formModel.validateForm().isEmpty
            if oldValue.selectedClientID != formModel.selectedClientID {
                handleClientSelectionChange(from: oldValue.selectedClientID, to: formModel.selectedClientID)
            }
            if oldValue.selectedClientServiceID != formModel.selectedClientServiceID {
                handleServiceSelectionChange(to: formModel.selectedClientServiceID)
            }
        }
    }
    
    // MARK: - Client & Service Domain Models
    var selectedClient: Client?
    var selectedClientService: ClientService?
    var availableClients: [Client] = [] {
        didSet {
            reconcilePickerSelections()
        }
    }
    var availableServices: [ClientService] = []
    var clientLookupTask: Task<Void, Never>?
    var serviceLookupTask: Task<Void, Never>?
    var servicesLoadedForClientID: UUID?
    
    // MARK: - Instance Date Tracking
    var originalInstanceDate: Date?
    var lastSelectedClientID: UUID?
    
    // MARK: - Dialog State Management
    var showingRecurringDeleteOptions = false
    var showingEditModeDialog = false

    var isEditing: Bool { sessionToEdit != nil }

    /// True when editing an existing session that has recurrence (series).
    var isEditingRecurringSession: Bool { sessionToEdit?.recurrenceRuleData != nil }
    
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

    var formIsValid: Bool = false

    init(
        modelContext: ModelContext,
        sessionModificationService: SessionModificationService,
        recurrenceRuleManager: Core.RecurrenceRuleManager,
        session: Session?,
        instanceDate: Date?,
        instanceEndDate: Date?
    ) {
        self.modelContext = modelContext
        self.sessionModificationService = sessionModificationService
        self.recurrenceRuleManager = recurrenceRuleManager
        self.sessionPrefetcher = CalendarSessionPrefetchActor(modelContainer: modelContext.container)
        self.sessionToEdit = session
        self.originalInstanceDate = instanceDate
        
        if let session = session {
            self.formModel = SessionFormModel(from: session, recurrenceRuleManager: recurrenceRuleManager)
            self.lastSelectedClientID = self.formModel.selectedClientID
            
            if let address = session.address {
                populateFormFromAddress(address)
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
                await self.loadAvailableClients()
                let preloaded = await self.preloadSessionRelationships(sessionID: session.id)
                self.applyPreloadedSessionData(preloaded)
            }
        } else {
            self.formModel = SessionFormModel()
            let start = instanceDate ?? Date()
            self.formModel.startTime = start
            self.formModel.endTime = instanceEndDate ?? start.addingTimeInterval(3600)
            self.lastSelectedClientID = self.formModel.selectedClientID
            Task {
                await self.loadAvailableClients()
            }
        }

        formIsValid = formModel.hasBasicRequiredFields && formModel.validateForm().isEmpty
        // availableClients supplied by @Query in SessionEditorSheetContainer / EventConversionSheetContainer
    }
    
    init(
        modelContext: ModelContext,
        sessionModificationService: SessionModificationService,
        recurrenceRuleManager: Core.RecurrenceRuleManager,
        from event: EKEvent
    ) {
        self.modelContext = modelContext
        self.sessionModificationService = sessionModificationService
        self.recurrenceRuleManager = recurrenceRuleManager
        self.sessionPrefetcher = CalendarSessionPrefetchActor(modelContainer: modelContext.container)
        self.formModel = SessionFormModel(from: event)
        self.lastSelectedClientID = self.formModel.selectedClientID
        
        formIsValid = formModel.hasBasicRequiredFields && formModel.validateForm().isEmpty
        Task {
            await self.loadAvailableClients()
        }
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
}
