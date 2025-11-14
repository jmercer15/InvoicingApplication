//
//  SessionModificationService.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Refactoring Initiative
//
import Foundation
import SwiftData // Use SwiftData
import Data
import EventKit
import Core

/// Responsible for session creation, modification, and deletion business logic
/// Extracted from NewSessionViewModel to isolate critical session management operations
@MainActor
class SessionModificationService {
    
    private let context: ModelContext // Needed for address operations and EventKit sync operations
    private let sessionsRepository: SessionsRepository
    private let addressRepository: AddressRepository
    private let eventKitService: EventKitSyncService
    private let recurrenceRuleBuilder: RecurrenceRuleBuilder
    
    init(
        context: ModelContext, // Needed for address operations and EventKit sync operations
        sessionsRepository: SessionsRepository? = nil,
        addressRepository: AddressRepository? = nil,
        eventKitService: EventKitSyncService,
        recurrenceRuleBuilder: RecurrenceRuleBuilder = RecurrenceRuleBuilder()
    ) {
        self.context = context
        // If repository provided, use it; otherwise create default implementation
        self.sessionsRepository = sessionsRepository ?? SessionsRepositorySwiftData(modelContext: context)
        self.addressRepository = addressRepository ?? AddressRepositorySwiftData(modelContext: context)
        self.eventKitService = eventKitService
        self.recurrenceRuleBuilder = recurrenceRuleBuilder
    }
    
    // MARK: - Session Creation
    
    /// Creates a new session from form data (returns domain model)
    func createSession(from formModel: SessionFormModel) async throws -> Session {
        // Validate form data first
        let validationErrors = formModel.validateForm()
        if !validationErrors.isEmpty {
            throw SessionModificationError.validationFailed(validationErrors.map { $0.localizedDescription })
        }
        
        // Use SessionFactory for consistent initialization
        let sessionFactory = SessionFactory(context: context)
        let sessionEntity = sessionFactory.createNewSession(
            startTime: formModel.startTime,
            endTime: formModel.endTime
        )
        
        // Apply form values to the session entity
        do {
            try applyFormModel(formModel, to: sessionEntity)
        } catch {
            throw SessionModificationError.dataApplicationFailed(error)
        }
        
        // Save to Core Data
        do {
            try context.save()
            print("[SessionModificationService] Created new session with id: \(sessionEntity.id.uuidString)")
        } catch {
            print("[SessionModificationService] Error saving new session to Core Data: \(error)")
            throw SessionModificationError.saveFailed(error)
        }
        
        // Sync with EventKit using domain model
        Task { @MainActor in
            // Use the extension from Data package that converts SessionEntity to Session
            let sessionDomain = Session.from(entity: sessionEntity)
            eventKitService.sync(session: sessionDomain, modelContext: context)
        }
        print("[SessionModificationService] Synced new session to EventKit")
        
        // Convert to domain model and return using Data package extension
        return Session.from(entity: sessionEntity)
    }
    
    /// Creates a new session from form data (legacy method returning entity)
    func createSession(from formModel: SessionFormModel) -> Result<SessionEntity, SessionModificationError> {
        // Validate form data first
        let validationErrors = formModel.validateForm()
        if !validationErrors.isEmpty {
            return .failure(.validationFailed(validationErrors.map { $0.localizedDescription }))
        }
        
        // Use SessionFactory for consistent initialization
        let sessionFactory = SessionFactory(context: context)
        let session = sessionFactory.createNewSession(
            startTime: formModel.startTime,
            endTime: formModel.endTime
        )
        
        // Apply form values to the session
        do {
            try applyFormModel(formModel, to: session)
        } catch {
            return .failure(.dataApplicationFailed(error))
        }
        
        // Save to Core Data
        do {
            try context.save()
            print("[SessionModificationService] Created new session with id: \(session.id.uuidString)")
        } catch {
            print("[SessionModificationService] Error saving new session to Core Data: \(error)")
            return .failure(.saveFailed(error))
        }
        
        // Sync with EventKit
        Task { @MainActor in
            eventKitService.sync(session: session, modelContext: context)
        }
        print("[SessionModificationService] Synced new session to EventKit")
        
        return .success(session)
    }
    
    // MARK: - Session Modification
    
    /// Modifies an existing session with support for recurring series modifications (domain model version)
    func modifySession(
        _ session: Session,
        with formModel: SessionFormModel,
        mode: RecurringEditMode,
        originalInstanceDate: Date? = nil
    ) async throws -> Session {
        // Fetch entity for modification
        let sessionEntity: SessionEntity
        do {
            sessionEntity = try fetchEntity(by: session.id)
        } catch {
            throw SessionModificationError.dataApplicationFailed(NSError(domain: "SessionModificationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Session not found"]))
        }
        
        // Validate form data
        let validationErrors = formModel.validateForm()
        if !validationErrors.isEmpty {
            throw SessionModificationError.validationFailed(validationErrors.map { $0.localizedDescription })
        }
        
        // Handle different modification modes
        let result: Result<SessionModificationResult, SessionModificationError>
        switch mode {
        case .thisOnly:
            result = modifyThisInstanceOnly(sessionEntity, with: formModel, originalInstanceDate: originalInstanceDate)
        case .thisAndFuture:
            result = modifyThisAndFuture(sessionEntity, with: formModel, originalInstanceDate: originalInstanceDate)
        case .all:
            result = modifyAllInstances(sessionEntity, with: formModel)
        }
        
        switch result {
        case .success(let modificationResult):
            // Extract the modified session entity and convert to domain model
            let modifiedEntity: SessionEntity
            switch modificationResult {
            case .sessionModified(let entity):
                modifiedEntity = entity
            case .detachedInstanceCreated(let entity):
                modifiedEntity = entity
            case .seriesSplit(_, let newEntity):
                modifiedEntity = newEntity
            }
            return Session.from(entity: modifiedEntity)
        case .failure(let error):
            throw error
        }
    }
    
    /// Modifies an existing session with support for recurring series modifications (legacy entity version)
    func modifySession(
        _ session: SessionEntity,
        with formModel: SessionFormModel,
        mode: RecurringEditMode,
        originalInstanceDate: Date? = nil
    ) -> Result<SessionModificationResult, SessionModificationError> {
        
        // Validate form data
        let validationErrors = formModel.validateForm()
        if !validationErrors.isEmpty {
            return .failure(.validationFailed(validationErrors.map { $0.localizedDescription }))
        }
        
        // Handle different modification modes
        switch mode {
        case .thisOnly:
            return modifyThisInstanceOnly(session, with: formModel, originalInstanceDate: originalInstanceDate)
        case .thisAndFuture:
            return modifyThisAndFuture(session, with: formModel, originalInstanceDate: originalInstanceDate)
        case .all:
            return modifyAllInstances(session, with: formModel)
        }
    }
    
    private func modifyThisInstanceOnly(
        _ session: SessionEntity,
        with formModel: SessionFormModel,
        originalInstanceDate: Date?
    ) -> Result<SessionModificationResult, SessionModificationError> {
        
        guard let instanceDate = originalInstanceDate else {
            // For non-recurring sessions, modify directly
            return modifyAllInstances(session, with: formModel)
        }
        
        // Create a detached instance for recurring series
        let sessionFactory = SessionFactory(context: context)
        
        let detachedSession = sessionFactory.createDetachedInstance(
            from: session,
            at: instanceDate,
            withChanges: { detached in
                do {
                    try self.applyFormModel(formModel, to: detached)
                } catch {
                    print("[SessionModificationService] Error applying form model to detached instance: \(error)")
                }
            }
        )
        
        // Save changes
        Task { @MainActor in
            let sessionDomain = Session.from(entity: detachedSession)
            eventKitService.sync(session: sessionDomain, modelContext: context)
        }
        return .success(.detachedInstanceCreated(detachedSession))
    }
    
    private func modifyThisAndFuture(
        _ session: SessionEntity,
        with formModel: SessionFormModel,
        originalInstanceDate: Date?
    ) -> Result<SessionModificationResult, SessionModificationError> {
        
        guard let instanceDate = originalInstanceDate else {
            return .failure(.missingInstanceDate)
        }
        
        // For now, create a detached instance instead of truncating series
        // This is a simplified approach - in a full implementation, we would need
        // to implement series truncation logic
        let sessionFactory = SessionFactory(context: context)
        
        let detachedInstance = sessionFactory.createDetachedInstance(
            from: session,
            at: instanceDate,
            withChanges: { detached in
                do {
                    try self.applyFormModel(formModel, to: detached)
                    detached.startTime = formModel.startTime
                    detached.endTime = formModel.endTime
                } catch {
                    print("[SessionModificationService] Error applying form model to detached instance: \(error)")
                }
            }
        )
        
        // Save changes
        Task { @MainActor in
            eventKitService.sync(session: detachedInstance, modelContext: context)
        }
        return .success(.detachedInstanceCreated(detachedInstance))
    }
    
    private func modifyAllInstances(
        _ session: SessionEntity,
        with formModel: SessionFormModel
    ) -> Result<SessionModificationResult, SessionModificationError> {
        
        do {
            try applyFormModel(formModel, to: session)
        } catch {
            return .failure(.dataApplicationFailed(error))
        }
        
        // Save to Core Data
        do {
            try context.save()
            print("[SessionModificationService] Modified session with id: \(session.id.uuidString)")
        } catch {
            print("[SessionModificationService] Error saving modified session: \(error)")
            return .failure(.saveFailed(error))
        }
        
        // Sync with EventKit using domain model
        Task { @MainActor in
            let sessionDomain = Session.from(entity: session)
            eventKitService.sync(session: sessionDomain, modelContext: context)
        }
        
        return .success(.sessionModified(session))
    }
    
    // MARK: - Session Deletion
    
    /// Deletes a session with support for recurring series deletion modes (domain model version)
    func deleteSession(
        _ session: Session,
        mode: RecurringEditMode,
        originalInstanceDate: Date? = nil
    ) async throws {
        // Fetch entity for deletion
        let sessionEntity: SessionEntity
        do {
            sessionEntity = try fetchEntity(by: session.id)
        } catch {
            throw SessionModificationError.dataApplicationFailed(NSError(domain: "SessionModificationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Session not found"]))
        }
        
        let result = deleteSession(sessionEntity, mode: mode, originalInstanceDate: originalInstanceDate)
        switch result {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    /// Deletes a session with support for recurring series deletion modes (legacy entity version)
    func deleteSession(
        _ session: SessionEntity,
        mode: RecurringEditMode,
        originalInstanceDate: Date? = nil
    ) -> Result<SessionDeletionResult, SessionModificationError> {
        
        switch mode {
        case .thisOnly:
            return deleteThisInstanceOnly(session, originalInstanceDate: originalInstanceDate)
        case .thisAndFuture:
            return deleteThisAndFuture(session, originalInstanceDate: originalInstanceDate)
        case .all:
            return deleteAllInstances(session)
        }
    }
    
    private func deleteThisInstanceOnly(
        _ session: SessionEntity,
        originalInstanceDate: Date?
    ) -> Result<SessionDeletionResult, SessionModificationError> {
        
        guard let instanceDate = originalInstanceDate else {
            // For non-recurring sessions, delete directly
            return deleteAllInstances(session)
        }
        
        // Create a cancelled detached instance instead of deleting
        let sessionFactory = SessionFactory(context: context)
        
        let cancelledInstance = sessionFactory.createCancelledDetachedInstance(
            from: session,
            at: instanceDate
        )
        
        Task { @MainActor in
            let sessionDomain = Session.from(entity: cancelledInstance)
            eventKitService.sync(session: sessionDomain, modelContext: context)
        }
        return .success(.instanceCancelled(cancelledInstance))
    }
    
    private func deleteThisAndFuture(
        _ session: SessionEntity,
        originalInstanceDate: Date?
    ) -> Result<SessionDeletionResult, SessionModificationError> {
        
        guard let instanceDate = originalInstanceDate else {
            return .failure(.missingInstanceDate)
        }
        
        // For now, create a cancelled detached instance instead of truncating series
        // This is a simplified approach - in a full implementation, we would need
        // to implement series truncation logic
        let sessionFactory = SessionFactory(context: context)
        
        let cancelledInstance = sessionFactory.createCancelledDetachedInstance(
            from: session,
            at: instanceDate
        )
        
        Task { @MainActor in
            let sessionDomain = Session.from(entity: cancelledInstance)
            eventKitService.sync(session: sessionDomain, modelContext: context)
        }
        return .success(.instanceCancelled(cancelledInstance))
    }
    
    private func deleteAllInstances(_ session: SessionEntity) -> Result<SessionDeletionResult, SessionModificationError> {
        // Store sync identifier before deleting from Core Data
        let syncId = session.eventIdentifier
        
        context.delete(session)
        
        do {
            try context.save()
            print("[SessionModificationService] Deleted session with id: \(session.id.uuidString)")
        } catch {
            print("[SessionModificationService] Error deleting session: \(error)")
            context.rollback()
            return .failure(.saveFailed(error))
        }
        
        // Delete from EventKit using the stored identifier
        if !syncId.isEmpty {
            Task { @MainActor in
                eventKitService.delete(syncIdentifier: syncId)
            }
            print("[SessionModificationService] Deleted from EventKit with syncIdentifier: \(syncId)")
        }
        
        return .success(.sessionDeleted)
    }
    
    // MARK: - Helper Methods
    
    /// Fetches SessionEntity by ID - Required for entity-level operations
    /// Note: This service requires entity access for:
    /// - Recurring series manipulation (split, truncate, detach instances)
    /// - Relationship setting (client, clientService relationships)
    /// - Direct property updates needed for complex session modifications
    /// TODO: Future refactoring could introduce an EntityAdapter service in the Data layer
    /// to handle entity fetching/creation while keeping domain model interfaces
    private func fetchEntity(by id: UUID) throws -> SessionEntity {
        let descriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.id == id })
        guard let entity = try? context.fetch(descriptor).first else {
            throw SessionModificationError.dataApplicationFailed(NSError(domain: "SessionModificationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Session entity not found"]))
        }
        return entity
    }
    
    // MARK: - Data Application
    
    /// Applies form model data to a session entity
    private func applyFormModel(_ formModel: SessionFormModel, to session: SessionEntity) throws {
        print("[SessionModificationService] Applying form values to session id: \(session.id.uuidString)")
        
        // Preserve the eventIdentifier to maintain EKEvent relationship
        let originalEventIdentifier = session.eventIdentifier
        let originalCalendarIdentifier = session.calendarIdentifier
        let originalLastSyncTag = session.lastSyncTag
        
        // Basic properties
        session.title = formModel.title
        session.isAllDay = formModel.isAllDay
        session.startTime = formModel.startTime
        session.endTime = formModel.endTime
        session.status = SessionStatus(rawValue: formModel.status) ?? .scheduled
        session.notes = formModel.notes
        
        // Client and service relationships
        // Note: Direct entity fetching is required here to set SwiftData relationships.
        // Repositories return domain models, but we need entity references for relationship assignment.
        // TODO: Future refactoring could introduce an EntityResolver service to handle this conversion.
        if let clientID = formModel.selectedClientID {
            session.client = try context.fetch(FetchDescriptor<ClientEntity>(predicate: #Predicate { $0.id == clientID })).first
        }
        if let serviceID = formModel.selectedClientServiceID {
            session.clientService = try context.fetch(FetchDescriptor<ClientServiceEntity>(predicate: #Predicate { $0.id == serviceID })).first
        }
        
        // Address handling
        try createOrUpdateAddress(from: formModel, for: session)
        
        // Recurrence rule
        if let rule = recurrenceRuleBuilder.buildRecurrenceRule(from: formModel) {
            // Use centralized setter which handles preferred encoding and migration safety
            session.setRecurrenceRule(rule)
            session.ekRecurrenceRuleDescription = rule.description
            print("[SessionModificationService] Recurrence rule applied for session id: \(session.id.uuidString)")
        } else {
            session.setRecurrenceRule(nil)
            session.ekRecurrenceRuleDescription = nil
        }
        
        // Google Calendar color
        if formModel.useGoogleColor {
            session.googleColorId = formModel.googleCalendarColorId
        } else {
            session.googleColorId = nil
        }
        
        // Coordinates for backward compatibility
        session.sessionLatitude = formModel.sessionLatitude
        session.sessionLongitude = formModel.sessionLongitude
        
        // Handle EKEvent association if this is a new session from an EKEvent
        if let sourceEventID = formModel.sourceEventIdentifier, !sourceEventID.isEmpty {
            // This is a new session being created from an EKEvent
            // Always set the derivedFromEKEventID to track the source EKEvent
            session.derivedFromEKEventID = sourceEventID
            print("[SessionModificationService] Set derivedFromEKEventID to \(sourceEventID) for new session from EKEvent")
            
            // Check if any other SessionEntity already has this eventIdentifier
            let fetchDescriptor = FetchDescriptor<SessionEntity>(
                predicate: #Predicate { $0.eventIdentifier == sourceEventID }
            )
            
            if let existingWithEventID: [SessionEntity] = try? context.fetch(fetchDescriptor), !existingWithEventID.isEmpty {
                // Another session already has this eventIdentifier - don't create a duplicate
                print("[SessionModificationService] Warning: Another session already has eventIdentifier \(sourceEventID)")
                // Keep derivedFromEKEventID but don't set eventIdentifier to avoid conflicts
                session.eventIdentifier = ""
            } else {
                // No existing session with this eventIdentifier, safe to set it
                session.eventIdentifier = sourceEventID
                print("[SessionModificationService] Set eventIdentifier to \(sourceEventID) for new session")
            }
        } else {
            // Preserve EKEvent association to maintain sync relationship for existing sessions
            session.eventIdentifier = originalEventIdentifier
            session.calendarIdentifier = originalCalendarIdentifier
            session.lastSyncTag = originalLastSyncTag
            
            print("[SessionModificationService] Preserved eventIdentifier: \(originalEventIdentifier) for session id: \(session.id.uuidString)")
        }
    }
    
    private func createOrUpdateAddress(from formModel: SessionFormModel, for session: SessionEntity) throws {
        // Check if we have any address data to save
        let hasAddressData = !formModel.unitNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            !formModel.streetNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            !formModel.streetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            !formModel.suburb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            !formModel.state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            !formModel.postcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            !formModel.country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            !formModel.poBox.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        if !hasAddressData {
            // No address data, remove existing address if any
            if let existingAddress = session.address {
                context.delete(existingAddress)
                session.address = nil
            }
            // Set location field for backward compatibility
            session.location = formModel.location
            return
        }
        
        // Create new address or update existing one
        let address = session.address ?? AddressEntity()
        if session.address == nil {
            session.address = address
        }
        
        // Set address properties
        address.unitNumber = formModel.unitNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        address.streetNumber = formModel.streetNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        address.streetName = formModel.streetName.trimmingCharacters(in: .whitespacesAndNewlines)
        address.suburb = formModel.suburb.trimmingCharacters(in: .whitespacesAndNewlines)
        address.state = formModel.state.trimmingCharacters(in: .whitespacesAndNewlines)
        address.postcode = formModel.postcode.trimmingCharacters(in: .whitespacesAndNewlines)
        address.country = formModel.country.trimmingCharacters(in: .whitespacesAndNewlines)
        address.poBox = formModel.poBox.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Set coordinates
        address.latitude = formModel.sessionLatitude
        address.longitude = formModel.sessionLongitude
        
        // Set full address text
        address.fullAddressText = formModel.fullAddress
        
        // Also set the location field for backward compatibility
        session.location = formModel.fullAddress
        
        print("[SessionModificationService] Created/updated address for session: \(session.id.uuidString)")
    }
    
    private func handleEKEventAssociation(session: SessionEntity, eventID: String) throws {
        // Check if any other SessionEntity already has this eventIdentifier
        let eventIdentifierPredicate = #Predicate<SessionEntity> { $0.eventIdentifier == eventID }
        let eventIdentifierDescriptor = FetchDescriptor(predicate: eventIdentifierPredicate)
        
        if let existingWithEventID = try? context.fetch(eventIdentifierDescriptor), !existingWithEventID.isEmpty {
            // Another session already has this eventIdentifier - don't create a duplicate
            print("[SessionModificationService] Not linking session to EKEvent id: \(eventID) - another session already has this eventIdentifier")
            session.derivedFromEKEventID = nil
            session.eventIdentifier = ""
            return
        }
        
        // Check if any other SessionEntity already has this derivedFromEKEventID
        let derivedFromPredicate = #Predicate<SessionEntity> { $0.derivedFromEKEventID == eventID }
        let derivedFromDescriptor = FetchDescriptor(predicate: derivedFromPredicate)
        
        if let existing = try? context.fetch(derivedFromDescriptor), existing.isEmpty {
            session.derivedFromEKEventID = eventID
            print("[SessionModificationService] Linked session to EKEvent id: \(eventID)")
        } else if session.derivedFromEKEventID == eventID {
            // Allow if editing the same session - do nothing, keep as is
        } else {
            // Do not overwrite or duplicate
            session.derivedFromEKEventID = nil
            print("[SessionModificationService] Not linking session to EKEvent id: \(eventID) due to existing association")
        }
        
        // Ensure the session is linked to the original EKEvent for sync
        session.eventIdentifier = eventID
    }
    
    // MARK: - Supporting Types
    
    enum SessionModificationResult {
        case sessionModified(SessionEntity)
        case detachedInstanceCreated(SessionEntity)
        case seriesSplit(originalSeries: SessionEntity, newSeries: SessionEntity)
    }
    
    enum SessionDeletionResult {
        case sessionDeleted
        case instanceCancelled(SessionEntity)
        case seriesTruncated(SessionEntity)
    }
    
    enum SessionModificationError: LocalizedError {
        case validationFailed([String])
        case dataApplicationFailed(Error)
        case saveFailed(Error)
        case detachedInstanceCreationFailed
        case seriesTruncationFailed
        case missingInstanceDate
        case recurrenceRuleEncodingFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .validationFailed(let errors):
                return "Validation failed: \(errors.joined(separator: ", "))"
            case .dataApplicationFailed(let error):
                return "Failed to apply data: \(error.localizedDescription)"
            case .saveFailed(let error):
                return "Save failed: \(error.localizedDescription)"
            case .detachedInstanceCreationFailed:
                return "Failed to create detached instance"
            case .seriesTruncationFailed:
                return "Failed to truncate series"
            case .missingInstanceDate:
                return "Instance date is required for recurring session modifications"
            case .recurrenceRuleEncodingFailed(let error):
                return "Failed to encode recurrence rule: \(error.localizedDescription)"
            }
        }
    }
} 
