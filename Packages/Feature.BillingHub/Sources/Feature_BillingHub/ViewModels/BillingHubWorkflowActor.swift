import Foundation
import SwiftData
import Core
import PersistenceModels

public struct SessionWorkflowReference: Sendable, Hashable {
    public let sessionID: UUID
    public let modelID: PersistentIdentifier

    public init(sessionID: UUID, modelID: PersistentIdentifier) {
        self.sessionID = sessionID
        self.modelID = modelID
    }
}

/// A background actor responsible for handling all Billing Hub state mutations and business transitions.
@ModelActor
public actor BillingHubWorkflowActor {
    
    // MARK: - Dependencies (Injectable or reachable via ModelContext)
    
    public func fetchProjection(
        searchText: String,
        selectedClientID: UUID?,
        sortOptions: [KanbanCardData.BillingColumnType: ColumnSortOption]
    ) throws -> BillingHubBoardProjection {
        let sessionDescriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { session in
                session.startTime != nil &&
                    (session.isTravel == true ||
                        session.statusToken == "completed" ||
                        session.statusToken == "grouped" ||
                        session.statusToken == "needs_travel")
            },
            sortBy: [SortDescriptor(\.startTime)]
        )
        let invoiceDescriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { invoice in
                invoice.statusToken == "review_draft" ||
                    invoice.statusToken == "ready_to_send" ||
                    invoice.statusToken == "pending" ||
                    invoice.statusToken == "received" ||
                    invoice.statusToken == "overdue"
            },
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        let sessions = try modelContext.fetch(sessionDescriptor)
        let invoices = try modelContext.fetch(invoiceDescriptor)
        let clientIDs = Set(sessions.compactMap(\.clientId) + invoices.compactMap(\.clientId))
        let serviceIDs = Set(sessions.compactMap(\.clientServiceId))
        let clients = try fetchClients(withIDs: clientIDs)
        let clientServices = try fetchClientServices(withIDs: serviceIDs)

        return BillingHubProjectionBuilder.project(
            sessions: sessions,
            invoices: invoices,
            clients: clients,
            clientServices: clientServices,
            searchText: searchText,
            selectedClientID: selectedClientID,
            sortOptions: sortOptions
        )
    }

    private func fetchClients(withIDs ids: Set<UUID>) throws -> [Client] {
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<Client>(
            predicate: #Predicate { ids.contains($0.id) },
            sortBy: [SortDescriptor(\.fullName), SortDescriptor(\.id)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchClientServices(withIDs ids: Set<UUID>) throws -> [ClientService] {
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<ClientService>(
            predicate: #Predicate { ids.contains($0.id) },
            sortBy: [SortDescriptor(\.serviceName), SortDescriptor(\.id)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Updates the billing status of a session
    public func updateSessionStatus(modelID: PersistentIdentifier, to column: KanbanCardData.BillingColumnType) async throws {
        guard let session = try resolveSession(modelID: modelID) else { return }
        session.status = SessionStatus(rawValue: column.statusToken)
        session.lastModifiedDate = Date()
        try modelContext.save()
    }

    /// Moves a session to a new column with validation and group handling
    public func moveSession(
        modelID: PersistentIdentifier,
        to column: KanbanCardData.BillingColumnType,
        handleGrouping: Bool = true
    ) async throws -> MoveResult {
        guard let session = try resolveSession(modelID: modelID) else { return .notFound }
        
        let currentStatusToken = session.status?.rawValue
        guard let currentStatus = (currentStatusToken != nil ? BillingStatus(rawValue: currentStatusToken!) : nil) else {
            return .invalidTransition(from: currentStatusToken ?? "unknown", to: column.rawValue)
        }
        
        let targetStatus = column.billingStatus
        guard BillingTransitionRules.isValidSessionTransition(from: currentStatus, to: targetStatus) else {
            return .invalidTransition(from: currentStatus.rawValue, to: targetStatus.rawValue)
        }
        
        let previousGroup = session.groupID
        let sourceWasInGroupedColumn = currentStatus == .grouped
        
        session.status = SessionStatus(rawValue: column.statusToken)
        session.lastModifiedDate = Date()
        
        if handleGrouping {
            if let previousGroup {
                session.groupID = nil
                try await dissolveGroupIfSingleton(groupID: previousGroup)
                if column == .grouped {
                    try await reindexGroupedScope(previousGroup)
                }
            }
            
            if column == .grouped {
                try await reindexGroupedScope(nil)
            } else if sourceWasInGroupedColumn || previousGroup != nil {
                try await reindexGroupedScope(previousGroup)
                try await reindexGroupedScope(nil)
            }
        }
        
        try modelContext.save()
        return .success
    }

    /// Moves an invoice to a new column with validation and compliance checks
    public func moveInvoice(
        modelID: PersistentIdentifier,
        to column: KanbanCardData.BillingColumnType,
        complianceValidator: (any ComplianceValidating)? = nil
    ) async throws -> MoveResult {
        guard let entity = try resolveInvoice(modelID: modelID) else { return .notFound }
        
        let currentStatusRaw = entity.status?.rawValue ?? ""
        let currentStatusConverted: BillingStatus? = (currentStatusRaw == "overdue") ? .pending : BillingStatus(rawValue: currentStatusRaw)
        guard let currentStatus = currentStatusConverted else {
            return .invalidTransition(from: currentStatusRaw, to: column.rawValue)
        }
        
        let targetStatus = column.billingStatus
        guard BillingTransitionRules.isValidInvoiceTransition(from: currentStatus, to: targetStatus) else {
            return .invalidTransition(from: currentStatus.rawValue, to: targetStatus.rawValue)
        }

        var complianceHadWarnings = false
        let invoiceID = entity.id
        if let validator = complianceValidator, BillingTransitionRules.isForwardInvoiceTransition(from: currentStatusRaw, to: targetStatus.rawValue) {
            let validation = try await validator.validateInvoiceTransition(
                invoiceId: invoiceID,
                action: .statusChange,
                targetStatus: targetStatus.rawValue
            )
            if validation.isBlocked {
                let detail = validation.blockers.map(\.message).joined(separator: " ")
                return .blocked(detail.isEmpty ? "Blocked by compliance." : "Blocked: \(detail)")
            }
            complianceHadWarnings = !validation.warnings.isEmpty
        }

        let dateClearing = BillingTransitionRules.requiresDateClearing(to: targetStatus)
        if dateClearing.clearSentDate { entity.sentDate = nil }
        if dateClearing.clearPaidDate { entity.paidDate = nil }
        entity.status = InvoiceStatus(rawValue: targetStatus.rawValue)
        entity.markContentChanged()

        try modelContext.save()
        return complianceHadWarnings ? .successWithComplianceWarnings : .success
    }

    /// Approves a draft in one persistence operation. Keeping the due-date write with the
    /// validated status transition prevents a blocked approval from silently changing payment
    /// terms while the invoice remains in Review Drafts.
    public func approveDraftInvoice(
        modelID: PersistentIdentifier,
        dueDate: Date,
        complianceValidator: (any ComplianceValidating)? = nil
    ) async throws -> MoveResult {
        guard let entity = try resolveInvoice(modelID: modelID) else { return .notFound }

        let currentStatusRaw = entity.status?.rawValue ?? ""
        guard let currentStatus = BillingStatus(rawValue: currentStatusRaw) else {
            return .invalidTransition(from: currentStatusRaw, to: BillingStatus.readyToSend.rawValue)
        }
        guard BillingTransitionRules.isValidInvoiceTransition(
            from: currentStatus,
            to: .readyToSend
        ) else {
            return .invalidTransition(from: currentStatus.rawValue, to: BillingStatus.readyToSend.rawValue)
        }

        var complianceHadWarnings = false
        if let validator = complianceValidator {
            let validation = try await validator.validateInvoiceTransition(
                invoiceId: entity.id,
                action: .statusChange,
                targetStatus: BillingStatus.readyToSend.rawValue
            )
            if validation.isBlocked {
                let detail = validation.blockers.map(\.message).joined(separator: " ")
                return .blocked(detail.isEmpty ? "Blocked by compliance." : "Blocked: \(detail)")
            }
            complianceHadWarnings = !validation.warnings.isEmpty
        }

        entity.dueDate = dueDate
        entity.status = InvoiceStatus(rawValue: BillingStatus.readyToSend.rawValue)
        entity.markContentChanged()
        try modelContext.save()
        return complianceHadWarnings ? .successWithComplianceWarnings : .success
    }

    // MARK: - Private Helpers

    private func resolveSession(modelID: PersistentIdentifier) throws -> Session? {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.persistentModelID == modelID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func resolveInvoice(modelID: PersistentIdentifier) throws -> Invoice? {
        var descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate { $0.persistentModelID == modelID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func resolveSessionByID(_ id: UUID) throws -> Session? {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func dissolveGroupIfSingleton(groupID: UUID) async throws {
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.groupID == groupID })
        let members = try modelContext.fetch(descriptor)
        if members.count == 1, let singleton = members.first {
            singleton.groupID = nil
            singleton.groupedPosition = 0
            try modelContext.save()
        }
    }

    private func reindexGroupedScope(_ groupID: UUID?) async throws {
        let predicate = #Predicate<Session> { $0.groupID == groupID }
        let descriptor = FetchDescriptor<Session>(predicate: predicate, sortBy: [SortDescriptor(\.groupedPosition)])
        let members = try modelContext.fetch(descriptor)
        for (index, member) in members.enumerated() {
            member.groupedPosition = Int32(index)
        }
        try modelContext.save()
    }

    // MARK: - Bulk Actions

    /// Creates draft invoices from the given sessions.
    ///
    /// Idempotency: any session that already has `session.invoice` set is refused up front and
    /// reported back as a failed session rather than silently re-billed. Sessions are refetched by
    /// UUID (not by the caller-provided `PersistentIdentifier`) after the NDIS service call
    /// completes, since that call runs its own `ModelContext` and may have registered fresh model
    /// instances for this container. On partial success, groups left with leftover (failed)
    /// members are reindexed/dissolved so the Grouped column never shows stale positions.
    public func createDraftInvoices(
        sessions: [SessionWorkflowReference],
        clientID: UUID,
        ndisService: NDISBillingIntegrationServiceProtocol
    ) async throws -> Core.NDISBillingReport {
        var alreadyInvoiced: [Core.NDISBillingIssue] = []
        var eligibleSessions: [SessionWorkflowReference] = []
        var originalGroupIDs: Set<UUID> = []

        for session in sessions {
            guard let entity = try resolveSession(modelID: session.modelID) else {
                alreadyInvoiced.append(Core.NDISBillingIssue(sessionId: session.sessionID, sessionTitle: "Unknown", reason: "Session not found"))
                continue
            }
            if let groupID = entity.groupID {
                originalGroupIDs.insert(groupID)
            }
            if entity.invoice != nil {
                alreadyInvoiced.append(Core.NDISBillingIssue(sessionId: session.sessionID, sessionTitle: entity.title, reason: "Session already has an invoice"))
                continue
            }
            if let sessionClientID = entity.client?.id, sessionClientID != clientID {
                alreadyInvoiced.append(Core.NDISBillingIssue(
                    sessionId: session.sessionID,
                    sessionTitle: entity.title,
                    reason: "Session belongs to a different client"
                ))
                continue
            }
            if entity.client?.id == nil {
                alreadyInvoiced.append(Core.NDISBillingIssue(
                    sessionId: session.sessionID,
                    sessionTitle: entity.title,
                    reason: "Session has no client"
                ))
                continue
            }
            eligibleSessions.append(session)
        }

        guard !eligibleSessions.isEmpty else {
        return Core.NDISBillingReport(
            invoice: nil,
            processedSessionsCount: sessions.count,
            successfulSessionsCount: 0,
            failedSessions: alreadyInvoiced,
            warnings: []
        )
    }

        let eligibleSessionIDs = eligibleSessions.map(\.sessionID)
        let report = try await ndisService.generateNDISInvoice(for: eligibleSessionIDs, clientId: clientID)
        var combinedFailedSessions = alreadyInvoiced + report.failedSessions

        if report.invoice != nil {
            let failedIDs = Set(report.failedSessions.map { $0.sessionId })
            let successfulSessionIDs = eligibleSessionIDs.filter { !failedIDs.contains($0) }

            // Refetch by UUID: the NDIS service mutated sessions through its own ModelContext, so
            // resolving fresh instances here (rather than reusing the caller's modelID) avoids
            // acting on stale registrations before the status/groupID update.
            var refetchMisses: [Core.NDISBillingIssue] = []
            for sessionID in successfulSessionIDs {
                if let entity = try resolveSessionByID(sessionID) {
                    entity.status = SessionStatus(normalized: BillingStatus.reviewDrafts.rawValue)
                    entity.groupID = nil
                } else {
                    // Retry once after save/context refresh signal.
                    try modelContext.save()
                    if let retry = try resolveSessionByID(sessionID) {
                        retry.status = SessionStatus(normalized: BillingStatus.reviewDrafts.rawValue)
                        retry.groupID = nil
                    } else {
                        refetchMisses.append(Core.NDISBillingIssue(
                            sessionId: sessionID,
                            sessionTitle: "Unknown",
                            reason: "Session linked to invoice but could not be refreshed — reopen Billing Hub to sync"
                        ))
                    }
                }
            }
            try modelContext.save()
            combinedFailedSessions += refetchMisses

            for groupID in originalGroupIDs {
                try await dissolveGroupIfSingleton(groupID: groupID)
                try await reindexGroupedScope(groupID)
            }
        }

        return Core.NDISBillingReport(
            invoice: report.invoice,
            processedSessionsCount: sessions.count,
            successfulSessionsCount: report.successfulSessionsCount,
            failedSessions: combinedFailedSessions,
            warnings: report.warnings
        )
    }

    public func bulkUpdateInvoices(
        modelIDs: [PersistentIdentifier],
        targetStatus: BillingStatus,
        mutate: @Sendable (inout Invoice) -> Void
    ) async throws -> Int {
        var count = 0
        for modelID in modelIDs {
            guard let entity = try resolveInvoice(modelID: modelID) else { continue }
            var invoice = entity
            mutate(&invoice)
            entity.status = InvoiceStatus(normalized: targetStatus.rawValue)
            entity.markContentChanged()
            count += 1
        }
        try modelContext.save()
        return count
    }

    /// Mutates an invoice without forcing a `BillingStatus` column transition (e.g. persisting a
    /// note-only payment draft, or approving a due date). Still bumps `markContentChanged()` so any
    /// open editor draft is invalidated.
    @discardableResult
    public func updateInvoice(
        modelID: PersistentIdentifier,
        mutate: @Sendable (Invoice) -> Void
    ) async throws -> Bool {
        guard let entity = try resolveInvoice(modelID: modelID) else { return false }
        mutate(entity)
        entity.markContentChanged()
        try modelContext.save()
        return true
    }

    /// Marks an invoice overdue. `overdue` isn't part of the kanban `BillingStatus` enum (it stays
    /// visually in the Payment/Pending lane), so this writes `InvoiceStatus.overdue` directly
    /// instead of going through `moveInvoice`.
    @discardableResult
    public func markInvoiceOverdue(modelID: PersistentIdentifier) async throws -> Bool {
        guard let entity = try resolveInvoice(modelID: modelID) else { return false }
        entity.status = .overdue
        entity.markContentChanged()
        try modelContext.save()
        return true
    }

    // MARK: - Reordering

    public func reorderSessions(modelIDs: [PersistentIdentifier], scopeGroupID _: UUID?) async throws {
        for (index, modelID) in modelIDs.enumerated() {
            if let entity = try resolveSession(modelID: modelID) {
                entity.groupedPosition = Int32(index)
            }
        }
        try modelContext.save()
    }

    public func reorderInvoices(ids _: [UUID]) async throws {
        // Invoice currently does not have a 'position' property.
        // If reordering is needed, it must be added to the model.
        // For now, we omit this to unblock compilation.
    }

    // MARK: - Grouping

    public func groupSessions(modelIDs: [PersistentIdentifier], groupID: UUID) async throws {
        for modelID in modelIDs {
            if let entity = try resolveSession(modelID: modelID) {
                entity.groupID = groupID
                entity.status = SessionStatus(normalized: BillingStatus.grouped.rawValue)
            }
        }
        try modelContext.save()
    }

    public func ungroupSessions(modelIDs: [PersistentIdentifier]) async throws {
        var previousGroups: Set<UUID> = []
        for modelID in modelIDs {
            if let sessionModel = try resolveSession(modelID: modelID) {
                if let groupID = sessionModel.groupID {
                    previousGroups.insert(groupID)
                }
                sessionModel.groupID = nil
            }
        }
        try modelContext.save()
        for groupID in previousGroups {
            try await dissolveGroupIfSingleton(groupID: groupID)
        }
    }

    public func updateSessionDetails(modelID: PersistentIdentifier, durationString: String) async throws {
        guard let sessionModel = try resolveSession(modelID: modelID) else { return }
        guard let minutes = BillingHubDurationParser.totalMinutes(from: durationString) else {
            throw BillingHubDurationError.unrecognizedFormat(durationString)
        }
        if let start = sessionModel.startTime {
            sessionModel.endTime = Calendar.current.date(byAdding: .minute, value: minutes, to: start)
        }
        try modelContext.save()
    }

    public enum BillingHubDurationError: LocalizedError {
        case unrecognizedFormat(String)

        public var errorDescription: String? {
            switch self {
            case .unrecognizedFormat(let value):
                return "Could not parse duration \"\(value)\". Try formats like 1h 30m or 90m."
            }
        }
    }

    public func updateInvoiceDetails(modelID: PersistentIdentifier, clientName: String) async throws {
        guard let invoiceModel = try resolveInvoice(modelID: modelID) else { return }
        let normalizedName = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard invoiceModel.clientName != normalizedName else { return }
        invoiceModel.clientName = normalizedName
        invoiceModel.markContentChanged()
        try modelContext.save()
    }

    public func upsertSupportLog(sessionModelID: PersistentIdentifier, draft: SupportLogDraft) async throws {
        guard let sessionModel = try resolveSession(modelID: sessionModelID) else { return }

        // True upsert: update the newest existing log when present (parity with Calendar editor).
        let existing = sessionModel.supportLogs?.max { lhs, rhs in
            lhs.attestedAt < rhs.attestedAt
        }
        let supportLog = existing ?? SupportLog(id: UUID())
        supportLog.participantName = draft.participantName
        supportLog.participantNdisNumber = draft.participantNdisNumber
        supportLog.supportItemNumber = draft.supportItemNumber
        supportLog.serviceDescription = draft.serviceDescription
        supportLog.location = draft.location
        supportLog.deliveredFrom = draft.deliveredFrom
        supportLog.deliveredTo = draft.deliveredTo
        supportLog.quantityHours = draft.quantityHours
        supportLog.deliveredBy = draft.deliveredBy
        supportLog.attestedBy = draft.attestedBy
        supportLog.attestedAt = draft.attestedAt
        supportLog.signatureMethod = draft.signatureMethod
        supportLog.signedBy = draft.signedBy
        supportLog.signedAt = draft.signedAt
        supportLog.cancellationReasonCode = draft.cancellationReasonCode
        supportLog.notes = draft.notes
        supportLog.client = sessionModel.client
        supportLog.session = sessionModel
        supportLog.sessionId = sessionModel.id

        if existing == nil {
            modelContext.insert(supportLog)
        }
        try modelContext.save()
    }

    public func calculateTravelBreakdown(
        sessionModelID: PersistentIdentifier,
        distance: Double,
        time: Double,
        tolls: Double,
        parking: Double,
        chargeType: String,
        vehicleType: String,
        participantCount: Int,
        splitCosts: Bool
    ) throws -> TravelCalculationBreakdown? {
        guard let sessionModel = try resolveSession(modelID: sessionModelID) else { return nil }
        return Self.travelBreakdown(
            for: sessionModel,
            distance: distance,
            time: time,
            tolls: tolls,
            parking: parking,
            participantCount: participantCount,
            splitCosts: splitCosts,
            chargeType: chargeType,
            vehicleType: vehicleType
        )
    }

    public func addTravelCharge(
        sessionModelID: PersistentIdentifier,
        distance: Double,
        time: Double,
        tolls: Double,
        parking: Double,
        chargeType: String,
        vehicleType: String,
        travelDirection: String,
        participantCount: Int,
        splitCosts: Bool
    ) async throws {
        guard let sessionModel = try resolveSession(modelID: sessionModelID) else {
            throw BillingHubTravelError.sessionNotFound
        }

        let mmmZone = sessionModel.travelCharges?
            .compactMap(\.mmmZoneName)
            .first
        let direction = TravelChargeDirection(rawValue: travelDirection)
        // Replace same-direction charge (Calendar before/after semantics) — never stack.
        if let direction, let existing = sessionModel.travelCharges {
            for charge in existing where charge.travelDirection == direction {
                modelContext.delete(charge)
            }
        }

        let breakdown = Self.travelBreakdown(
            for: sessionModel,
            mmmZoneDescriptor: mmmZone,
            distance: distance,
            time: time,
            tolls: tolls,
            parking: parking,
            participantCount: participantCount,
            splitCosts: splitCosts,
            chargeType: chargeType,
            vehicleType: vehicleType
        )

        let travelCharge = TravelCharge(
            id: UUID(),
            chargeAmount: Decimal(breakdown.chargeAmount),
            distanceKM: distance,
            durationMinutes: breakdown.billableMinutes,
            location: nil,
            status: .pending,
            chargeType: Self.persistedTravelChargeType(chargeType),
            travelDirection: direction,
            vehicleType: VehicleType(rawValue: vehicleType),
            participantCount: Int16(participantCount),
            splitCosts: splitCosts,
            parkingCost: Decimal(parking),
            tollCost: Decimal(tolls),
            notes: nil,
            startTime: sessionModel.startTime,
            endTime: sessionModel.endTime
        )
        travelCharge.mmmZoneName = mmmZone
        travelCharge.client = sessionModel.client
        travelCharge.linkedSession = sessionModel
        travelCharge.service = sessionModel.clientService

        modelContext.insert(travelCharge)

        sessionModel.status = SessionStatus(rawValue: BillingStatus.completed.rawValue)
        try modelContext.save()
    }

    /// Maps Hub UI charge-type tags onto `TravelChargeType` raw values (`Standard`, `labour`, …).
    static func persistedTravelChargeType(_ raw: String) -> TravelChargeType? {
        if let exact = TravelChargeType(rawValue: raw) { return exact }
        switch raw.lowercased() {
        case "standard": return .standard
        case "labour": return .labour
        case "non-labour": return .nonLabour
        case "activity-based": return .activityBased
        default: return nil
        }
    }

    private static func travelBreakdown(
        for sessionModel: Session,
        mmmZoneDescriptor: String? = nil,
        distance: Double,
        time: Double,
        tolls: Double,
        parking: Double,
        participantCount: Int,
        splitCosts: Bool,
        chargeType: String,
        vehicleType: String
    ) -> TravelCalculationBreakdown {
        let service = sessionModel.clientService
        let providerType = BillingHubTravelChargeCalculator.inferredProviderType(
            itemName: service?.serviceName,
            itemDescription: nil,
            ndisCode: service?.ndisCode
        )
        let hourlyRate = NSDecimalNumber(decimal: sessionModel.assignedRate ?? service?.rate ?? 0).doubleValue
        let mmmZone = mmmZoneDescriptor
            ?? sessionModel.travelCharges?.compactMap(\.mmmZoneName).first
        return BillingHubTravelChargeCalculator.breakdown(
            providerType: providerType,
            hourlyRate: hourlyRate,
            mmmZoneDescriptor: mmmZone,
            distance: distance,
            time: time,
            tolls: tolls,
            parking: parking,
            participantCount: participantCount,
            splitCosts: splitCosts,
            chargeType: chargeType,
            vehicleType: vehicleType
        )
    }

    // MARK: - Bulk undo restore

    public func restoreInvoices(from snapshots: [InvoiceWorkflowSnapshot]) async throws {
        for snapshot in snapshots {
            guard let entity = try resolveInvoiceByID(snapshot.id) else { continue }
            entity.status = InvoiceStatus(normalized: snapshot.status)
            entity.sentDate = snapshot.sentDate
            entity.paidDate = snapshot.paidDate
            if let notes = snapshot.notes {
                entity.notes = notes
            }
            entity.markContentChanged()
        }
        try modelContext.save()
    }

    public func restoreSessions(from snapshots: [SessionWorkflowSnapshot]) async throws {
        for snapshot in snapshots {
            guard let entity = try resolveSessionByID(snapshot.id) else { continue }
            entity.status = SessionStatus(normalized: snapshot.status)
            entity.groupID = snapshot.groupID
            entity.lastModifiedDate = Date()
        }
        try modelContext.save()
    }

    private func resolveInvoiceByID(_ id: UUID) throws -> Invoice? {
        var descriptor = FetchDescriptor<Invoice>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Identity resolution (SwiftData executor; avoids duplicate main-context fetches for workflow handoff)

    public func persistentModelIDForSession(id: UUID) throws -> PersistentIdentifier? {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.persistentModelID
    }

    public func persistentModelIDsForSessions(ids: [UUID]) throws -> [UUID: PersistentIdentifier] {
        guard !ids.isEmpty else { return [:] }
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { ids.contains($0.id) })
        let sessions = try modelContext.fetch(descriptor)
        return Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.persistentModelID) })
    }

    public func persistentModelIDForInvoice(id: UUID) throws -> PersistentIdentifier? {
        var descriptor = FetchDescriptor<Invoice>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.persistentModelID
    }

    public func sessionWorkflowReferencesForGroup(groupID: UUID) throws -> [SessionWorkflowReference] {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.groupID == groupID },
            sortBy: [SortDescriptor(\.startTime)]
        )
        return try modelContext.fetch(descriptor).map {
            SessionWorkflowReference(sessionID: $0.id, modelID: $0.persistentModelID)
        }
    }

    public func clientIdForSession(id: UUID) throws -> UUID? {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.clientId
    }

    public func sessionExists(id: UUID) throws -> Bool {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first != nil
    }
}
