//
//  SessionModificationService.swift
//  InvoicingApplication
//
import Foundation
import SwiftData
import Core
import EventKit

/// SwiftData-native session create/edit/delete and recurrence operations.
///
/// - Important: This service works with SwiftData `@Model` entities directly.
///   It uses snapshots only at OS/service boundaries (e.g. `SyncService`).
@MainActor
final class SessionModificationService {
    private let modelContext: ModelContext
    private let syncService: SyncService
    private let eventKitService: any CalendarEventService
    private let recurrenceRuleBuilder: RecurrenceRuleBuilder
    private let recurrenceRuleManager: Core.RecurrenceRuleManager

    init(
        modelContext: ModelContext,
        syncService: SyncService,
        eventKitService: any CalendarEventService,
        recurrenceRuleManager: Core.RecurrenceRuleManager,
        recurrenceRuleBuilder: RecurrenceRuleBuilder = RecurrenceRuleBuilder()
    ) {
        self.modelContext = modelContext
        self.syncService = syncService
        self.eventKitService = eventKitService
        self.recurrenceRuleManager = recurrenceRuleManager
        self.recurrenceRuleBuilder = recurrenceRuleBuilder
    }
    
    // MARK: - Public API (used by `NewSessionViewModel` / `CalendarViewModel`)
    
    func createSession(from formModel: SessionFormModel) async throws -> Session {
        let validationErrors = formModel.validateForm()
        if !validationErrors.isEmpty {
            throw SessionModificationError.validationFailed(validationErrors.map(\.localizedDescription))
        }

        let session = Session(
            id: UUID(),
            title: formModel.title,
            startTime: formModel.startTime,
            endTime: formModel.endTime,
            isAllDay: formModel.isAllDay,
            location: resolvedLocation(from: formModel),
            notes: formModel.notes,
            status: Core.SessionStatus(normalized: formModel.status)?.asEntityStatus,
            isTravel: false,
            groupID: nil,
            groupedPosition: 0,
            travelDistanceKM: nil,
            travelTimeMinutes: nil,
            recurrenceRuleData: nil,
            assignedServiceName: nil,
            assignedRate: nil
        )

        applyEventKitFields(to: session, formModel: formModel, forDetachedOccurrence: nil)
        try applyRecurrenceIfNeeded(to: session, formModel: formModel)
        try await resolveRelationships(for: session, formModel: formModel)
        applyAddressIfNeeded(to: session, formModel: formModel, preferredID: session.id)

        modelContext.insert(session)
        try saveChanges()

        scheduleSessionSync(session, span: .thisEvent)
        return session
    }

    func modifySession(
        _ session: Session,
        with formModel: SessionFormModel,
        mode: RecurringEditMode,
        originalInstanceDate: Date?
    ) async throws -> Session {
        let validationErrors = formModel.validateForm()
        if !validationErrors.isEmpty {
            throw SessionModificationError.validationFailed(validationErrors.map(\.localizedDescription))
        }

        if session.recurrenceRuleData == nil {
            applyEdits(to: session, formModel: formModel)
            try await resolveRelationships(for: session, formModel: formModel)
            applyAddressIfNeeded(to: session, formModel: formModel, preferredID: session.address?.id ?? session.id)
            try saveChanges()
            scheduleSessionSync(session, span: .thisEvent)
            return session
        }

        // Recurring session edits.
        switch mode {
        case .all:
            applyEdits(to: session, formModel: formModel)
            try applyRecurrenceIfNeeded(to: session, formModel: formModel)
            try await resolveRelationships(for: session, formModel: formModel)
            applyAddressIfNeeded(to: session, formModel: formModel, preferredID: session.address?.id ?? session.id)
            try saveChanges()
            scheduleSessionSync(session, span: .futureEvents)
            return session

        case .thisOnly:
            guard let instanceDate = originalInstanceDate else {
                // Without an occurrence context, fall back to full-series edit.
                return try await modifySession(session, with: formModel, mode: .all, originalInstanceDate: nil)
            }

            if let detached = try fetchDetachedInstance(master: session, occurrenceDate: instanceDate) {
                applyEdits(to: detached, formModel: formModel)
                try await resolveRelationships(for: detached, formModel: formModel)
                applyAddressIfNeeded(to: detached, formModel: formModel, preferredID: detached.address?.id ?? detached.id)
                try saveChanges()
                scheduleSessionSync(detached, span: .thisEvent)
                return detached
            }

            let detached = makeDetachedInstance(master: session, occurrenceDate: instanceDate)
            applyEdits(to: detached, formModel: formModel)
            try await resolveRelationships(for: detached, formModel: formModel)
            applyAddressIfNeeded(to: detached, formModel: formModel, preferredID: detached.id)
            modelContext.insert(detached)
            try saveChanges()
            scheduleSessionSync(detached, span: .thisEvent)
            return detached

        case .thisAndFuture:
            guard let instanceDate = originalInstanceDate else {
                // Without an occurrence context, treat as full series edit.
                return try await modifySession(session, with: formModel, mode: .all, originalInstanceDate: nil)
            }

            // 1) Truncate current series before instanceDate
            try truncateSeries(session, endingBefore: instanceDate)

            // 2) Create a new series master starting at instanceDate using the edited form model.
            let newMaster = makeFutureSeriesMaster(from: session, instanceDate: instanceDate, formModel: formModel)
            try await resolveRelationships(for: newMaster, formModel: formModel)
            applyAddressIfNeeded(to: newMaster, formModel: formModel, preferredID: newMaster.id)
            modelContext.insert(newMaster)

            // 3) Delete detached instances on/after instanceDate (they belong to the new series now).
            try removeFutureDetachedInstances(of: session, onOrAfter: instanceDate)

            try saveChanges()
            scheduleSessionSync(newMaster, span: .futureEvents)
            return newMaster
        }
    }

    func deleteSession(_ session: Session, mode: RecurringEditMode, originalInstanceDate: Date?) async throws {
        if session.recurrenceRuleData == nil {
            deleteEntity(session)
            try saveChanges()
            scheduleEventDeletion(identifier: session.eventIdentifier, span: preferredDeletionSpan(for: session))
            return
        }

        switch mode {
        case .all:
            let detached = try fetchDetachedInstances(master: session)
            for d in detached where d.id != session.id {
                deleteEntity(d)
                if !d.eventIdentifier.isEmpty {
                    scheduleEventDeletion(identifier: d.eventIdentifier, span: .thisEvent)
                }
            }
            deleteEntity(session)
            try saveChanges()
            scheduleEventDeletion(identifier: session.eventIdentifier, span: preferredDeletionSpan(for: session))

        case .thisOnly:
            guard let instanceDate = originalInstanceDate else {
                // No occurrence context -> delete series.
                try await deleteSession(session, mode: .all, originalInstanceDate: nil)
                return
            }

            if let detached = try fetchDetachedInstance(master: session, occurrenceDate: instanceDate) {
                deleteEntity(detached)
                try saveChanges()
                if !detached.eventIdentifier.isEmpty {
                    scheduleEventDeletion(identifier: detached.eventIdentifier, span: .thisEvent)
                }
                return
            }

            // Create a detached cancellation marker so the user-visible occurrence disappears
            // and EventKit can be reconciled via the sync layer.
            let cancelled = makeDetachedInstance(master: session, occurrenceDate: instanceDate)
            cancelled.status = .cancelled
            modelContext.insert(cancelled)
            try saveChanges()
            scheduleSessionSync(cancelled, span: .thisEvent)

        case .thisAndFuture:
            guard let instanceDate = originalInstanceDate else {
                try await deleteSession(session, mode: .all, originalInstanceDate: nil)
                return
            }

            try truncateSeries(session, endingBefore: instanceDate)
            try removeFutureDetachedInstances(of: session, onOrAfter: instanceDate)
            try saveChanges()
            scheduleSessionSync(session, span: .futureEvents)
        }
    }

    func processRecurringModification(
        session: Session,
        modification: RecurringModificationType,
        mode: RecurringEditMode,
        originalInstanceDate: Date?
    ) async throws -> Session {
        var formModel = SessionFormModel(from: session, recurrenceRuleManager: recurrenceRuleManager)
        switch modification {
        case .move(let newStartTime):
            let duration = max(0, formModel.endTime.timeIntervalSince(formModel.startTime))
            formModel.startTime = newStartTime
            formModel.endTime = newStartTime.addingTimeInterval(duration)
        case .resize(let newStartTime, let newEndTime):
            formModel.startTime = newStartTime
            formModel.endTime = newEndTime
        }
        return try await modifySession(session, with: formModel, mode: mode, originalInstanceDate: originalInstanceDate)
    }

    // MARK: - Core edits

    private func applyEdits(to session: Session, formModel: SessionFormModel) {
        session.title = formModel.title
        session.startTime = formModel.startTime
        session.endTime = formModel.endTime
        session.isAllDay = formModel.isAllDay
        session.location = resolvedLocation(from: formModel)
        session.notes = formModel.notes
        session.status = Core.SessionStatus(normalized: formModel.status)?.asEntityStatus
        session.googleColorId = formModel.useGoogleColor ? formModel.googleCalendarColorId : nil
        session.sessionLatitude = formModel.sessionLatitude
        session.sessionLongitude = formModel.sessionLongitude
        session.lastModifiedDate = Date()
    }

    private func applyEventKitFields(to session: Session, formModel: SessionFormModel, forDetachedOccurrence: Date?) {
        // When we block linking due to duplicates, we store an empty identifier.
        let eventIdentifier = formModel.preventEventLinking ? "" : (formModel.sourceEventIdentifier ?? "")
        session.eventIdentifier = eventIdentifier
        if let masterId = formModel.sourceEventIdentifier, !masterId.isEmpty {
            session.derivedFromEKEventID = masterId
        }
        session.isDetached = forDetachedOccurrence != nil
        session.occurrenceDate = forDetachedOccurrence
    }

    private func applyAddressIfNeeded(to session: Session, formModel: SessionFormModel, preferredID: UUID) {
        let hasAddressData =
            !formModel.unitNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !formModel.streetNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !formModel.streetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !formModel.suburb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !formModel.postcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !formModel.state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !formModel.country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !formModel.poBox.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if !hasAddressData {
            // Clear relationship if it exists.
            if let existing = session.address {
                session.address = nil
                deleteEntity(existing)
            }
            return
        }

        let address = session.address ?? Address()
        address.id = address.id == UUID() ? preferredID : address.id
        address.unitNumber = formModel.unitNumber
        address.streetNumber = formModel.streetNumber
        address.streetName = formModel.streetName
        address.suburb = formModel.suburb
        address.postcode = formModel.postcode
        address.state = formModel.state
        address.country = formModel.country
        address.poBox = formModel.poBox
        address.city = formModel.city
        address.fullAddressText = address.fullFormattedAddress
        address.latitude = formModel.sessionLatitude
        address.longitude = formModel.sessionLongitude

        if session.address == nil {
            modelContext.insert(address)
            session.address = address
        }
    }

    private func resolvedLocation(from formModel: SessionFormModel) -> String? {
        let trimmed = formModel.location.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func applyRecurrenceIfNeeded(to session: Session, formModel: SessionFormModel) throws {
        if let rule = recurrenceRuleBuilder.buildRecurrenceRule(from: formModel) {
            guard let ruleData = recurrenceRuleManager.serialize(rule) else {
                throw SessionModificationError.recurrenceRuleEncodingFailed(
                    NSError(
                        domain: "SessionModificationService",
                        code: 2001,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to serialize recurrence rule."]
                    )
                )
            }
            session.recurrenceRuleData = ruleData
        } else {
            session.recurrenceRuleData = nil
        }
    }

    // MARK: - Relationships

    private func resolveRelationships(for session: Session, formModel: SessionFormModel) async throws {
        if let clientId = formModel.selectedClientID {
            session.client = try fetchClient(id: clientId)
        } else {
            session.client = nil
        }

        if let clientServiceId = formModel.selectedClientServiceID {
            session.clientService = try fetchClientService(id: clientServiceId)
        } else {
            session.clientService = nil
        }
    }

    private func fetchClient(id: UUID) throws -> Client? {
        var descriptor = FetchDescriptor<Client>(
            predicate: #Predicate<Client> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchClientService(id: UUID) throws -> ClientService? {
        var descriptor = FetchDescriptor<ClientService>(
            predicate: #Predicate<ClientService> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Recurrence helpers

    private func makeDetachedInstance(master: Session, occurrenceDate: Date) -> Session {
        let detached = Session(
            id: UUID(),
            title: master.title,
            startTime: master.startTime,
            endTime: master.endTime,
            isAllDay: master.isAllDay,
            location: master.location,
            notes: master.notes,
            status: master.status,
            isTravel: master.isTravel,
            groupID: master.groupID,
            groupedPosition: master.groupedPosition,
            travelDistanceKM: master.travelDistanceKM,
            travelTimeMinutes: master.travelTimeMinutes,
            recurrenceRuleData: nil,
            assignedServiceName: master.assignedServiceName,
            assignedRate: master.assignedRate
        )
        detached.client = master.client
        detached.clientService = master.clientService
        detached.derivedFromEKEventID = master.id.uuidString
        detached.isDetached = true
        detached.occurrenceDate = occurrenceDate
        detached.calendarIdentifier = master.calendarIdentifier
        detached.eventIdentifier = ""
        detached.lastModifiedDate = Date()
        detached.travelTollsAmount = master.travelTollsAmount
        return detached
    }

    private func makeFutureSeriesMaster(from master: Session, instanceDate: Date, formModel: SessionFormModel) -> Session {
        let newMaster = Session(
            id: UUID(),
            title: formModel.title,
            startTime: formModel.startTime,
            endTime: formModel.endTime,
            isAllDay: formModel.isAllDay,
            location: resolvedLocation(from: formModel),
            notes: formModel.notes,
            status: Core.SessionStatus(normalized: formModel.status)?.asEntityStatus,
            isTravel: master.isTravel,
            groupID: master.groupID,
            groupedPosition: master.groupedPosition,
            travelDistanceKM: master.travelDistanceKM,
            travelTimeMinutes: master.travelTimeMinutes,
            recurrenceRuleData: master.recurrenceRuleData,
            assignedServiceName: master.assignedServiceName,
            assignedRate: master.assignedRate
        )
        newMaster.derivedFromEKEventID = master.derivedFromEKEventID
        newMaster.isDetached = false
        newMaster.occurrenceDate = nil
        newMaster.calendarIdentifier = master.calendarIdentifier
        newMaster.eventIdentifier = ""
        newMaster.lastModifiedDate = Date()
        newMaster.travelTollsAmount = master.travelTollsAmount

        // Ensure the new master logically starts on/after the split date.
        if let start = newMaster.startTime, start < instanceDate {
            newMaster.startTime = instanceDate
        }
        return newMaster
    }

    private func fetchDetachedInstances(master: Session) throws -> [Session] {
        let masterId = master.id.uuidString
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> {
                $0.derivedFromEKEventID == masterId && $0.isDetached
            }
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchDetachedInstance(master: Session, occurrenceDate: Date) throws -> Session? {
        let masterId = master.id.uuidString
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> {
                $0.derivedFromEKEventID == masterId &&
                $0.isDetached &&
                $0.occurrenceDate == occurrenceDate
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }


    private func removeFutureDetachedInstances(of master: Session, onOrAfter date: Date) throws {
        for detached in try fetchDetachedInstances(master: master) {
            guard let occ = detached.occurrenceDate else { continue }
            if occ >= date {
                deleteEntity(detached)
            }
        }
    }

    private func truncateSeries(_ master: Session, endingBefore splitDate: Date) throws {
        guard let recurrenceData = master.recurrenceRuleData,
              let currentRule = recurrenceRuleManager.deserialize(recurrenceData) else {
            throw SessionModificationError.seriesTruncationFailed
        }

        let truncatedEndDate = splitDate.addingTimeInterval(-1)
        let truncatedRule = EKRecurrenceRule(
            recurrenceWith: currentRule.frequency,
            interval: currentRule.interval,
            daysOfTheWeek: currentRule.daysOfTheWeek?.map { EKRecurrenceDayOfWeek($0.dayOfTheWeek, weekNumber: $0.weekNumber) },
            daysOfTheMonth: currentRule.daysOfTheMonth,
            monthsOfTheYear: currentRule.monthsOfTheYear,
            weeksOfTheYear: currentRule.weeksOfTheYear,
            daysOfTheYear: currentRule.daysOfTheYear,
            setPositions: currentRule.setPositions,
            end: EKRecurrenceEnd(end: truncatedEndDate)
        )

        guard let truncatedData = recurrenceRuleManager.serialize(truncatedRule) else {
            throw SessionModificationError.recurrenceRuleEncodingFailed(
                NSError(
                    domain: "SessionModificationService",
                    code: 2002,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to serialize truncated recurrence rule."]
                )
            )
        }

        master.recurrenceRuleData = truncatedData
        master.lastModifiedDate = Date()
    }

    // MARK: - Sync & EventKit

    private func scheduleSessionSync(_ session: Session, span _: EKSpan) {
        Task { @MainActor in
            try? await syncService.sync(session: session.snapshot())
        }
    }

    private func scheduleEventDeletion(identifier: String, span: EKSpan) {
        guard !identifier.isEmpty else { return }
        Task { @MainActor in
            eventKitService.delete(syncIdentifier: identifier, span: span)
        }
    }

    private func preferredDeletionSpan(for session: Session) -> EKSpan {
        session.recurrenceRuleData == nil ? .thisEvent : .futureEvents
    }

    // MARK: - ModelContext utilities

    private func deleteEntity<T: PersistentModel>(_ model: T) {
        modelContext.delete(model)
    }

    private func saveChanges() throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }
}

enum SessionModificationError: Error {
    case validationFailed([String])
    case recurrenceRuleEncodingFailed(Error)
    case seriesTruncationFailed
}

private extension Core.SessionStatus {
    var asEntityStatus: SessionStatus? { SessionStatus(normalized: token) }
}
 
