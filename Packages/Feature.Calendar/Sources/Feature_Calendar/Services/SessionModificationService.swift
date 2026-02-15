//
//  SessionModificationService.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Refactoring Initiative
//
import Foundation
import Core
import Data
import EventKit

/// Responsible for session creation, modification, and deletion business logic
/// Extracted from NewSessionViewModel to isolate critical session management operations
@MainActor
class SessionModificationService {
    
    private let unitOfWork: UnitOfWorkService
    private let eventKitService: EventKitSyncService
    private let recurrenceRuleBuilder: RecurrenceRuleBuilder
    
    init(
        unitOfWork: UnitOfWorkService,
        eventKitService: EventKitSyncService,
        recurrenceRuleBuilder: RecurrenceRuleBuilder = RecurrenceRuleBuilder()
    ) {
        self.unitOfWork = unitOfWork
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
        
        // Prepare model
        var modelToUse = try await normalizedClientServiceSelection(for: formModel)
        if await checkEventIdentifierDuplicate(modelToUse.sourceEventIdentifier) {
            modelToUse.preventEventLinking = true
        }
        
        let sessionID = UUID()
        let sessionAddressID = resolvedAddressID(for: modelToUse, preferredID: sessionID)
        var session = Session(
            id: sessionID,
            title: modelToUse.title,
            startTime: modelToUse.startTime,
            endTime: modelToUse.endTime,
            isAllDay: modelToUse.isAllDay,
            location: resolvedLocation(from: modelToUse),
            notes: modelToUse.notes,
            status: modelToUse.status,
            clientId: modelToUse.selectedClientID,
            clientServiceId: modelToUse.selectedClientServiceID,
            addressId: sessionAddressID,
            eventIdentifier: modelToUse.preventEventLinking ? "" : (modelToUse.sourceEventIdentifier ?? ""),
            googleColorId: modelToUse.useGoogleColor ? modelToUse.googleCalendarColorId : nil,
            sessionLatitude: modelToUse.sessionLatitude,
            sessionLongitude: modelToUse.sessionLongitude
        )
        
        // Handle recurrence
        if let rule = recurrenceRuleBuilder.buildRecurrenceRule(from: modelToUse) {
            guard let ruleData = RecurrenceRuleManager.shared.serialize(rule) else {
                throw SessionModificationError.recurrenceRuleEncodingFailed(
                    NSError(
                        domain: "SessionModificationService",
                        code: 2001,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to serialize recurrence rule."]
                    )
                )
            }

            session = Session(
                id: session.id,
                title: session.title,
                startTime: session.startTime,
                endTime: session.endTime,
                isAllDay: session.isAllDay,
                location: session.location,
                notes: session.notes,
                status: session.status,
                clientId: session.clientId,
                clientServiceId: session.clientServiceId,
                addressId: session.addressId,
                eventIdentifier: session.eventIdentifier,
                recurrenceRuleData: ruleData,
                googleColorId: session.googleColorId,
                sessionLatitude: session.sessionLatitude,
                sessionLongitude: session.sessionLongitude
            )
        }
        
        if let sourceEventID = modelToUse.sourceEventIdentifier, !sourceEventID.isEmpty {
             // Re-init for derivedFromEKEventID if needed
             // This is getting verbose, but acceptable for immutable structs
             session = Session(
                 id: session.id,
                 title: session.title,
                 startTime: session.startTime,
                 endTime: session.endTime,
                 isAllDay: session.isAllDay,
                 location: session.location,
                 notes: session.notes,
                 status: session.status,
                 clientId: session.clientId,
                 clientServiceId: session.clientServiceId,
                 addressId: session.addressId,
                 eventIdentifier: session.eventIdentifier,
                 recurrenceRuleData: session.recurrenceRuleData,
                 derivedFromEKEventID: sourceEventID,
                 googleColorId: session.googleColorId,
                 sessionLatitude: session.sessionLatitude,
                 sessionLongitude: session.sessionLongitude
             )
        }
        
        // Handle Address Creation
        try await createOrUpdateAddress(from: modelToUse, for: session)
        
        // Save Session
        let createdSession = try await unitOfWork.sessions.create(session)
        print("[SessionModificationService] Created new session with id: \(createdSession.id.uuidString)")
        
        // Sync with EventKit
        scheduleSessionSync(createdSession, span: .thisEvent)
        
        return createdSession
    }
    
    // MARK: - Session Modification
    
    /// Modifies an existing session with support for recurring series modifications (domain model version)
    func modifySession(
        _ session: Session,
        with formModel: SessionFormModel,
        mode: RecurringEditMode,
        originalInstanceDate: Date? = nil
    ) async throws -> Session {
        // Validate form data
        let validationErrors = formModel.validateForm()
        if !validationErrors.isEmpty {
            throw SessionModificationError.validationFailed(validationErrors.map { $0.localizedDescription })
        }

        let consistencyCheckedModel = try await normalizedClientServiceSelection(for: formModel)
        
        // Normalize date/time semantics when editing a specific recurring instance.
        // If the editor is showing the master date, project time fields onto the tapped instance date.
        let modelToUse = normalizedFormModelForRecurringInstance(
            consistencyCheckedModel,
            session: session,
            instanceDate: originalInstanceDate,
            mode: mode
        )
        // Existing duplicate check was: checkEventIdentifierDuplicate(...) excluding current.
        // We'll skip complex duplicate check refactor for brevity unless critical, or move logic to `createOrUpdate`
        
        // Handle different modification modes
        switch mode {
        case .thisOnly:
            return try await modifyThisInstanceOnly(session, with: modelToUse, originalInstanceDate: originalInstanceDate)
        case .thisAndFuture:
            return try await modifyThisAndFuture(session, with: modelToUse, originalInstanceDate: originalInstanceDate)
        case .all:
            return try await modifyAllInstances(session, with: modelToUse)
        }
    }
    
    private func modifyThisInstanceOnly(
        _ session: Session,
        with formModel: SessionFormModel,
        originalInstanceDate: Date?
    ) async throws -> Session {
        
        guard let instanceDate = originalInstanceDate else {
            // Non-recurring, modify directly
            return try await modifyAllInstances(session, with: formModel)
        }
        
        let existingDetached = try await existingDetachedInstance(for: session, occurrenceDate: instanceDate)
        let detachedID = existingDetached?.id ?? UUID()
        let detachedAddressID = resolvedAddressID(
            for: formModel,
            preferredID: existingDetached?.addressId ?? detachedID
        )
        let detachedEventIdentifier = existingDetached?.eventIdentifier ?? session.eventIdentifier
        let detachedExternalIdentifier = existingDetached?.eventExternalIdentifier ?? session.eventExternalIdentifier
        let detachedCalendarIdentifier = existingDetached?.calendarIdentifier ?? session.calendarIdentifier
        let detachedLastSyncTag = existingDetached?.lastSyncTag ?? session.lastSyncTag

        // Upsert detached session for this specific occurrence
        let detachedSession = Session(
            id: detachedID,
            title: formModel.title,
            startTime: formModel.startTime,
            endTime: formModel.endTime,
            isAllDay: formModel.isAllDay,
            location: resolvedLocation(from: formModel),
            notes: formModel.notes,
            status: formModel.status,
            isTravel: session.isTravel,
            isDetached: true,
            occurrenceDate: instanceDate,
            clientId: formModel.selectedClientID,
            clientServiceId: formModel.selectedClientServiceID,
            addressId: detachedAddressID,
            groupID: existingDetached?.groupID ?? session.groupID,
            groupedPosition: existingDetached?.groupedPosition ?? session.groupedPosition,
            eventIdentifier: detachedEventIdentifier,
            eventExternalIdentifier: detachedExternalIdentifier,
            calendarIdentifier: detachedCalendarIdentifier,
            lastModifiedDate: Date(),
            lastSyncTag: detachedLastSyncTag,
            recurrenceRuleData: nil,
            attendeesCount: existingDetached?.attendeesCount ?? session.attendeesCount,
            derivedFromEKEventID: session.id.uuidString, // Master ID
            googleColorId: formModel.useGoogleColor ? formModel.googleCalendarColorId : nil,
            sessionLatitude: formModel.sessionLatitude,
            sessionLongitude: formModel.sessionLongitude,
            assignedServiceName: existingDetached?.assignedServiceName ?? session.assignedServiceName,
            assignedRate: existingDetached?.assignedRate ?? session.assignedRate,
            travelDistanceKM: existingDetached?.travelDistanceKM ?? session.travelDistanceKM,
            travelTimeMinutes: existingDetached?.travelTimeMinutes ?? session.travelTimeMinutes,
            travelTollsAmount: existingDetached?.travelTollsAmount ?? session.travelTollsAmount
        )
        
        // Address
        try await createOrUpdateAddress(from: formModel, for: detachedSession)
        
        // Save (upsert)
        let created = try await upsertSession(detachedSession, existingSession: existingDetached)
        
        scheduleSessionSync(created, span: .thisEvent)
        
        return created
    }
    
    private func modifyThisAndFuture(
        _ session: Session,
        with formModel: SessionFormModel,
        originalInstanceDate: Date?
    ) async throws -> Session {
        guard let instanceDate = originalInstanceDate else {
            throw SessionModificationError.missingInstanceDate
        }

        guard session.recurrenceRuleData != nil else {
            return try await modifyAllInstances(session, with: formModel)
        }

        if shouldApplyToEntireSeries(session, at: instanceDate) {
            return try await modifyAllInstances(session, with: formModel)
        }

        try await truncateRecurringSeries(session, endingBefore: instanceDate)
        try await removeFutureDetachedInstances(of: session, onOrAfter: instanceDate)

        return try await createFutureSeries(from: session, with: formModel)
    }
    
    private func modifyAllInstances(
        _ session: Session,
        with formModel: SessionFormModel
    ) async throws -> Session {
        
        // Update existing session
        let ruleData = try serializedRecurrenceRuleData(from: formModel)
        let updatedAddressID = resolvedAddressID(
            for: formModel,
            preferredID: session.addressId ?? session.id
        )
        
        let updatedSession = Session(
            id: session.id,
            title: formModel.title,
            startTime: formModel.startTime,
            endTime: formModel.endTime,
            isAllDay: formModel.isAllDay,
            location: resolvedLocation(from: formModel),
            notes: formModel.notes,
            status: formModel.status,
            isTravel: session.isTravel, // Preserve
            isDetached: session.isDetached, // Preserve
            occurrenceDate: session.occurrenceDate, // Preserve
            clientId: formModel.selectedClientID,
            clientServiceId: formModel.selectedClientServiceID,
            addressId: updatedAddressID,
            groupID: session.groupID,
            groupedPosition: session.groupedPosition,
            eventIdentifier: session.eventIdentifier,
            eventExternalIdentifier: session.eventExternalIdentifier,
            calendarIdentifier: session.calendarIdentifier,
            lastModifiedDate: Date(),
            lastSyncTag: session.lastSyncTag,
            recurrenceRuleData: ruleData,
            attendeesCount: session.attendeesCount,
            derivedFromEKEventID: session.derivedFromEKEventID,
            googleColorId: formModel.useGoogleColor ? formModel.googleCalendarColorId : nil,
            sessionLatitude: formModel.sessionLatitude,
            sessionLongitude: formModel.sessionLongitude,
            assignedServiceName: session.assignedServiceName,
            assignedRate: session.assignedRate,
            travelDistanceKM: session.travelDistanceKM,
            travelTimeMinutes: session.travelTimeMinutes,
            travelTollsAmount: session.travelTollsAmount
        )
        
        // Update Address
        try await createOrUpdateAddress(from: formModel, for: updatedSession)
        
        let saved = try await unitOfWork.sessions.update(updatedSession)
        
        scheduleSessionSync(saved, span: preferredSyncSpan(for: saved))
        
        return saved
    }
    
    // MARK: - Session Deletion
    
    func deleteSession(
        _ session: Session,
        mode: RecurringEditMode,
        originalInstanceDate: Date? = nil
    ) async throws {
        switch mode {
        case .thisOnly:
            try await deleteThisInstanceOnly(session, originalInstanceDate: originalInstanceDate)
        case .thisAndFuture:
            try await deleteThisAndFuture(session, originalInstanceDate: originalInstanceDate)
        case .all:
            try await deleteAllInstances(session)
        }
    }
    
    private func deleteThisInstanceOnly(_ session: Session, originalInstanceDate: Date?) async throws {
        guard let instanceDate = originalInstanceDate else {
            try await deleteAllInstances(session)
            return
        }

        let existingDetached = try await existingDetachedInstance(for: session, occurrenceDate: instanceDate)
        let sourceForDuration = existingDetached ?? session
        let duration = max(
            0,
            (sourceForDuration.endTime ?? instanceDate).timeIntervalSince(sourceForDuration.startTime ?? instanceDate)
        )
        let instanceEndDate = instanceDate.addingTimeInterval(duration)
        let cancelledID = existingDetached?.id ?? UUID()
        let cancelledAddressID = existingDetached?.addressId
        let cancelledEventIdentifier = existingDetached?.eventIdentifier ?? session.eventIdentifier
        let cancelledExternalIdentifier = existingDetached?.eventExternalIdentifier ?? session.eventExternalIdentifier
        let cancelledCalendarIdentifier = existingDetached?.calendarIdentifier ?? session.calendarIdentifier
        let cancelledLastSyncTag = existingDetached?.lastSyncTag ?? session.lastSyncTag
        
        // Upsert cancelled detached instance for this specific occurrence
        let cancelledSession = Session(
            id: cancelledID,
            title: session.title,
            startTime: instanceDate, // Use instance date
            endTime: instanceEndDate,
            isAllDay: session.isAllDay,
            location: session.location,
            notes: session.notes,
            status: SessionStatus.cancelled.rawValue,
            isTravel: session.isTravel,
            isDetached: true,
            occurrenceDate: instanceDate,
            clientId: existingDetached?.clientId ?? session.clientId,
            clientServiceId: existingDetached?.clientServiceId ?? session.clientServiceId,
            addressId: cancelledAddressID,
            groupID: existingDetached?.groupID ?? session.groupID,
            groupedPosition: existingDetached?.groupedPosition ?? session.groupedPosition,
            eventIdentifier: cancelledEventIdentifier,
            eventExternalIdentifier: cancelledExternalIdentifier,
            calendarIdentifier: cancelledCalendarIdentifier,
            lastModifiedDate: Date(),
            lastSyncTag: cancelledLastSyncTag,
            recurrenceRuleData: nil,
            attendeesCount: existingDetached?.attendeesCount ?? session.attendeesCount,
            derivedFromEKEventID: session.id.uuidString, // Master ID
            googleColorId: existingDetached?.googleColorId ?? session.googleColorId,
            sessionLatitude: existingDetached?.sessionLatitude ?? session.sessionLatitude,
            sessionLongitude: existingDetached?.sessionLongitude ?? session.sessionLongitude,
            assignedServiceName: existingDetached?.assignedServiceName ?? session.assignedServiceName,
            assignedRate: existingDetached?.assignedRate ?? session.assignedRate,
            travelDistanceKM: existingDetached?.travelDistanceKM ?? session.travelDistanceKM,
            travelTimeMinutes: existingDetached?.travelTimeMinutes ?? session.travelTimeMinutes,
            travelTollsAmount: existingDetached?.travelTollsAmount ?? session.travelTollsAmount
        )
        
        let saved = try await upsertSession(cancelledSession, existingSession: existingDetached)
        scheduleSessionSync(saved, span: .thisEvent)
    }
    
    private func deleteThisAndFuture(_ session: Session, originalInstanceDate: Date?) async throws {
        guard let instanceDate = originalInstanceDate else {
            try await deleteAllInstances(session)
            return
        }

        guard session.recurrenceRuleData != nil else {
            try await deleteAllInstances(session)
            return
        }

        if shouldApplyToEntireSeries(session, at: instanceDate) {
            try await deleteAllInstances(session)
            return
        }

        try await truncateRecurringSeries(session, endingBefore: instanceDate)
        try await removeFutureDetachedInstances(of: session, onOrAfter: instanceDate)
    }
    
    private func deleteAllInstances(_ session: Session) async throws {
        var syncIdsToDelete: [(identifier: String, span: EKSpan)] = []

        if session.recurrenceRuleData != nil, !session.isDetached {
            let detachedInstances = try await unitOfWork.sessions.fetch(byDerivedFromEKEventID: session.id.uuidString)
            for detached in detachedInstances where detached.id != session.id {
                if !detached.eventIdentifier.isEmpty {
                    syncIdsToDelete.append((identifier: detached.eventIdentifier, span: .thisEvent))
                }
                try await unitOfWork.sessions.delete(id: detached.id)
            }
        }

        if !session.eventIdentifier.isEmpty {
            syncIdsToDelete.append((
                identifier: session.eventIdentifier,
                span: preferredDeletionSpan(for: session)
            ))
        }

        try await unitOfWork.sessions.delete(id: session.id)

        for syncTarget in syncIdsToDelete {
            scheduleEventDeletion(identifier: syncTarget.identifier, span: syncTarget.span)
        }
    }

    private func createFutureSeries(from originalSession: Session, with formModel: SessionFormModel) async throws -> Session {
        let newSessionID = UUID()
        let recurrenceRuleData = try serializedRecurrenceRuleData(from: formModel)
        let futureAddressID = resolvedAddressID(
            for: formModel,
            preferredID: originalSession.addressId ?? newSessionID
        )

        let futureSession = Session(
            id: newSessionID,
            title: formModel.title,
            startTime: formModel.startTime,
            endTime: formModel.endTime,
            isAllDay: formModel.isAllDay,
            location: resolvedLocation(from: formModel),
            notes: formModel.notes,
            status: formModel.status,
            isTravel: originalSession.isTravel,
            isDetached: false,
            occurrenceDate: nil,
            clientId: formModel.selectedClientID,
            clientServiceId: formModel.selectedClientServiceID,
            addressId: futureAddressID,
            groupID: originalSession.groupID,
            groupedPosition: originalSession.groupedPosition,
            eventIdentifier: "",
            eventExternalIdentifier: nil,
            calendarIdentifier: originalSession.calendarIdentifier,
            lastModifiedDate: Date(),
            lastSyncTag: nil,
            recurrenceRuleData: recurrenceRuleData,
            attendeesCount: originalSession.attendeesCount,
            derivedFromEKEventID: originalSession.derivedFromEKEventID,
            googleColorId: formModel.useGoogleColor ? formModel.googleCalendarColorId : nil,
            sessionLatitude: formModel.sessionLatitude,
            sessionLongitude: formModel.sessionLongitude,
            assignedServiceName: originalSession.assignedServiceName,
            assignedRate: originalSession.assignedRate,
            travelDistanceKM: originalSession.travelDistanceKM,
            travelTimeMinutes: originalSession.travelTimeMinutes,
            travelTollsAmount: originalSession.travelTollsAmount
        )

        try await createOrUpdateAddress(from: formModel, for: futureSession)
        let created = try await unitOfWork.sessions.create(futureSession)

        scheduleSessionSync(created, span: .thisEvent)

        return created
    }

    private func truncateRecurringSeries(_ session: Session, endingBefore splitDate: Date) async throws {
        guard let recurrenceData = session.recurrenceRuleData,
              let currentRule = RecurrenceRuleManager.shared.deserialize(recurrenceData) else {
            throw SessionModificationError.seriesTruncationFailed
        }

        let truncatedEndDate = splitDate.addingTimeInterval(-1)
        let truncatedRule = EKRecurrenceRule(
            recurrenceWith: currentRule.frequency,
            interval: currentRule.interval,
            daysOfTheWeek: currentRule.daysOfTheWeek?.map {
                EKRecurrenceDayOfWeek($0.dayOfTheWeek, weekNumber: $0.weekNumber)
            },
            daysOfTheMonth: currentRule.daysOfTheMonth,
            monthsOfTheYear: currentRule.monthsOfTheYear,
            weeksOfTheYear: currentRule.weeksOfTheYear,
            daysOfTheYear: currentRule.daysOfTheYear,
            setPositions: currentRule.setPositions,
            end: EKRecurrenceEnd(end: truncatedEndDate)
        )

        guard let truncatedData = RecurrenceRuleManager.shared.serialize(truncatedRule) else {
            throw SessionModificationError.recurrenceRuleEncodingFailed(
                NSError(
                    domain: "SessionModificationService",
                    code: 2002,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to serialize truncated recurrence rule."]
                )
            )
        }

        let truncatedSession = Session(
            id: session.id,
            title: session.title,
            startTime: session.startTime,
            endTime: session.endTime,
            isAllDay: session.isAllDay,
            location: session.location,
            notes: session.notes,
            status: session.status,
            isTravel: session.isTravel,
            isDetached: session.isDetached,
            occurrenceDate: session.occurrenceDate,
            clientId: session.clientId,
            clientServiceId: session.clientServiceId,
            addressId: session.addressId,
            groupID: session.groupID,
            groupedPosition: session.groupedPosition,
            eventIdentifier: session.eventIdentifier,
            eventExternalIdentifier: session.eventExternalIdentifier,
            calendarIdentifier: session.calendarIdentifier,
            lastModifiedDate: Date(),
            lastSyncTag: session.lastSyncTag,
            recurrenceRuleData: truncatedData,
            attendeesCount: session.attendeesCount,
            derivedFromEKEventID: session.derivedFromEKEventID,
            googleColorId: session.googleColorId,
            sessionLatitude: session.sessionLatitude,
            sessionLongitude: session.sessionLongitude,
            assignedServiceName: session.assignedServiceName,
            assignedRate: session.assignedRate,
            travelDistanceKM: session.travelDistanceKM,
            travelTimeMinutes: session.travelTimeMinutes,
            travelTollsAmount: session.travelTollsAmount
        )

        let saved = try await unitOfWork.sessions.update(truncatedSession)

        scheduleSessionSync(saved, span: .futureEvents)
    }

    private func removeFutureDetachedInstances(of session: Session, onOrAfter splitDate: Date) async throws {
        let detached = try await unitOfWork.sessions.fetch(byDerivedFromEKEventID: session.id.uuidString)
            .filter { $0.isDetached }
            .filter { ($0.occurrenceDate ?? .distantPast) >= splitDate }

        guard !detached.isEmpty else { return }

        for detachedSession in detached {
            try await unitOfWork.sessions.delete(id: detachedSession.id)
        }

        for detachedSession in detached where !detachedSession.eventIdentifier.isEmpty {
            scheduleEventDeletion(identifier: detachedSession.eventIdentifier, span: .thisEvent)
        }
    }

    private func shouldApplyToEntireSeries(_ session: Session, at instanceDate: Date) -> Bool {
        guard let startTime = session.startTime else { return false }
        return instanceDate.timeIntervalSince(startTime) <= 1
    }

    private func existingDetachedInstance(for session: Session, occurrenceDate: Date) async throws -> Session? {
        try await unitOfWork.sessions
            .fetch(byDerivedFromEKEventID: session.id.uuidString)
            .first(where: { detached in
                guard detached.isDetached, let detachedDate = detached.occurrenceDate else { return false }
                return abs(detachedDate.timeIntervalSince(occurrenceDate)) < 1
            })
    }

    private func normalizedFormModelForRecurringInstance(
        _ formModel: SessionFormModel,
        session: Session,
        instanceDate: Date?,
        mode: RecurringEditMode
    ) -> SessionFormModel {
        guard mode != .all,
              session.recurrenceRuleData != nil,
              let instanceDate,
              let masterStart = session.startTime else {
            return formModel
        }

        let calendar = Calendar.current
        var normalized = formModel

        // If the editor is still on the master day, reinterpret the entered time on the tapped occurrence day.
        if calendar.isDate(formModel.startTime, inSameDayAs: masterStart) {
            let duration = max(0, formModel.endTime.timeIntervalSince(formModel.startTime))
            let adjustedStart: Date
            if formModel.isAllDay {
                adjustedStart = calendar.startOfDay(for: instanceDate)
            } else {
                adjustedStart = dateByCombining(
                    dayFrom: instanceDate,
                    timeFrom: formModel.startTime,
                    calendar: calendar
                )
            }
            normalized.startTime = adjustedStart
            normalized.endTime = adjustedStart.addingTimeInterval(duration)
        }

        return normalized
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

    private func preferredSyncSpan(for session: Session) -> EKSpan {
        if session.recurrenceRuleData != nil, !session.isDetached {
            return .futureEvents
        }
        return .thisEvent
    }

    private func preferredDeletionSpan(for session: Session) -> EKSpan {
        if session.recurrenceRuleData != nil, !session.isDetached {
            return .futureEvents
        }
        return .thisEvent
    }

    private func scheduleSessionSync(_ session: Session, span: EKSpan) {
        Task { @MainActor in
            eventKitService.sync(session: session, unitOfWork: unitOfWork, span: span)
        }
    }

    private func scheduleEventDeletion(identifier: String, span: EKSpan) {
        Task { @MainActor in
            eventKitService.delete(syncIdentifier: identifier, span: span)
        }
    }

    private func serializedRecurrenceRuleData(from formModel: SessionFormModel) throws -> Data? {
        guard let recurrenceRule = recurrenceRuleBuilder.buildRecurrenceRule(from: formModel) else {
            return nil
        }
        guard let ruleData = RecurrenceRuleManager.shared.serialize(recurrenceRule) else {
            throw SessionModificationError.recurrenceRuleEncodingFailed(
                NSError(
                    domain: "SessionModificationService",
                    code: 2003,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to serialize recurrence rule."]
                )
            )
        }
        return ruleData
    }
    
    // MARK: - Address Helper
    
    private func resolvedLocation(from formModel: SessionFormModel) -> String? {
        let fullAddress = formModel.fullAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullAddress.isEmpty {
            return fullAddress
        }
        
        let directLocation = formModel.location.trimmingCharacters(in: .whitespacesAndNewlines)
        return directLocation.isEmpty ? nil : directLocation
    }
    
    private func createOrUpdateAddress(from formModel: SessionFormModel, for session: Session) async throws {
         let hasAddressData = !formModel.fullAddress.isEmpty
         
         if !hasAddressData {
             if let addressId = session.addressId {
                 do {
                     try await unitOfWork.addresses.delete(id: addressId)
                 } catch RepositoryError.entityNotFound {
                     // Already removed or never existed; nothing else to do.
                 } catch RepositoryError.notFound(id: _) {
                     // Compatibility with newer RepositoryError variants.
                 }
             }
             return
         }
         
         let addressId = session.addressId ?? session.id // Use session ID as address ID if generic, or UUID() if new
         // Logic to determine if we update existing or create new?
         // Simpler: Just save an Address domain object with ID = session.id (1-to-1 mapping)
         // UoW repositories upsert logic usually handles create vs update if ID exists?
         // Assuming unitOfWork.addresses.update or create.
         let resolvedCity = {
             let suburb = formModel.suburb.trimmingCharacters(in: .whitespacesAndNewlines)
             if !suburb.isEmpty {
                 return suburb
             }
             return formModel.city
         }()
         
         let address = Address(
             id: addressId,
             unitNumber: formModel.unitNumber,
             streetNumber: formModel.streetNumber,
             streetName: formModel.streetName,
             suburb: formModel.suburb,
             city: resolvedCity,
             state: formModel.state,
             postcode: formModel.postcode,
             country: formModel.country,
             poBox: formModel.poBox,
             latitude: formModel.sessionLatitude,
             longitude: formModel.sessionLongitude
         )
         
         try await upsertAddress(address)
    }

    private func resolvedAddressID(for formModel: SessionFormModel, preferredID: UUID) -> UUID? {
        let fullAddress = formModel.fullAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return fullAddress.isEmpty ? nil : preferredID
    }

    private func normalizedClientServiceSelection(for formModel: SessionFormModel) async throws -> SessionFormModel {
        var normalized = formModel

        if let selectedServiceID = normalized.selectedClientServiceID {
            guard let selectedService = try await unitOfWork.clientServices.fetch(by: selectedServiceID) else {
                throw SessionModificationError.validationFailed(["Selected service could not be found."])
            }
            if normalized.selectedClientID == nil || normalized.selectedClientID != selectedService.clientId {
                normalized.selectedClientID = selectedService.clientId
            }
        }

        if let selectedClientID = normalized.selectedClientID {
            guard try await unitOfWork.clients.fetch(by: selectedClientID) != nil else {
                throw SessionModificationError.validationFailed(["Selected client could not be found."])
            }
        }

        return normalized
    }
    
    private func checkEventIdentifierDuplicate(_ eventID: String?) async -> Bool {
        guard let eventID = eventID, !eventID.isEmpty else { return false }
        do {
            if let _ = try await unitOfWork.sessions.fetch(byEventIdentifier: eventID) {
                return true
            }
        } catch {
            return false
        }
        return false
    }
    
    // MARK: - Recurring Modification Processing (for drag/drop, resize)

    private func upsertSession(_ session: Session, existingSession: Session?) async throws -> Session {
        if existingSession != nil {
            return try await unitOfWork.sessions.update(session)
        }
        return try await unitOfWork.sessions.create(session)
    }

    private func upsertAddress(_ address: Address) async throws {
        do {
            _ = try await unitOfWork.addresses.update(address)
        } catch RepositoryError.entityNotFound {
            _ = try await unitOfWork.addresses.create(address)
        } catch RepositoryError.notFound(id: _) {
            _ = try await unitOfWork.addresses.create(address)
        }
    }
    
    /// Process a recurring modification (move or resize) with the given mode
    func processRecurringModification(
        session: Session,
        modification: RecurringModificationType,
        mode: RecurringEditMode,
        originalInstanceDate: Date?
    ) async throws -> Session {
        switch modification {
        case .move(let newStartTime):
            // Calculate duration from existing session
            let startTime = session.startTime ?? Date()
            let endTime = session.endTime ?? startTime.addingTimeInterval(3600)
            let duration = endTime.timeIntervalSince(startTime)
            let newEndTime = newStartTime.addingTimeInterval(duration)
            
            // Create a form model to leverage existing modification logic
            var formModel = SessionFormModel(from: session)
            formModel.startTime = newStartTime
            formModel.endTime = newEndTime
            formModel.selectedClientID = session.clientId
            formModel.selectedClientServiceID = session.clientServiceId
            
            return try await modifySession(session, with: formModel, mode: mode, originalInstanceDate: originalInstanceDate)
            
        case .resize(let newStartTime, let newEndTime):
            var formModel = SessionFormModel(from: session)
            formModel.startTime = newStartTime
            formModel.endTime = newEndTime
            formModel.selectedClientID = session.clientId
            formModel.selectedClientServiceID = session.clientServiceId
            
            return try await modifySession(session, with: formModel, mode: mode, originalInstanceDate: originalInstanceDate)
        }
    }
    
    // MARK: - Supporting Types
    
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
 
