import Foundation
import SwiftData
import Core
import Data

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
        let clientDescriptor = FetchDescriptor<Client>(sortBy: [SortDescriptor(\.fullName)])
        let serviceDescriptor = FetchDescriptor<ClientService>(sortBy: [SortDescriptor(\.serviceName)])

        let sessions = try modelContext.fetch(sessionDescriptor)
        let invoices = try modelContext.fetch(invoiceDescriptor)
        let clients = try modelContext.fetch(clientDescriptor)
        let clientServices = try modelContext.fetch(serviceDescriptor)

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
        complianceValidator: NDISComplianceValidator? = nil
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

    public func createDraftInvoices(
        sessions: [SessionWorkflowReference],
        clientID: UUID,
        ndisService: NDISBillingIntegrationServiceProtocol
    ) async throws -> Core.NDISBillingReport {
        let sessionIDs = sessions.map(\.sessionID)
        let report = try await ndisService.generateNDISInvoice(for: sessionIDs, clientId: clientID)
        
        if report.invoice != nil {
            let failedIDs = Set(report.failedSessions.map { $0.sessionId })
            let successfulSessions = sessions.filter { !failedIDs.contains($0.sessionID) }

            for session in successfulSessions {
                if let entity = try resolveSession(modelID: session.modelID) {
                    entity.status = SessionStatus(normalized: BillingStatus.reviewDrafts.rawValue)
                    entity.groupID = nil
                }
            }
            try modelContext.save()
        }
        return report
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
        for modelID in modelIDs {
            if let sessionModel = try resolveSession(modelID: modelID) {
                sessionModel.groupID = nil
            }
        }
        try modelContext.save()
    }

    public func updateSessionDetails(modelID: PersistentIdentifier, durationString: String) async throws {
        guard let sessionModel = try resolveSession(modelID: modelID) else { return }
        // Simple duration parsing for now - in real app would be more robust
        let hours = Double(durationString.replacingOccurrences(of: "h", with: "")) ?? 1.0
        if let start = sessionModel.startTime {
            sessionModel.endTime = Calendar.current.date(byAdding: .minute, value: Int(hours * 60), to: start)
        }
        try modelContext.save()
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

        let supportLog = SupportLog(id: UUID())
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

        modelContext.insert(supportLog)
        try modelContext.save()
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
        guard let sessionModel = try resolveSession(modelID: sessionModelID) else { return }

        let travelCharge = TravelCharge(
            id: UUID(),
            chargeAmount: distance * 0.85,
            distanceKM: distance,
            durationMinutes: time,
            location: nil,
            status: .pending,
            chargeType: TravelChargeType(rawValue: chargeType),
            travelDirection: TravelChargeDirection(rawValue: travelDirection),
            vehicleType: VehicleType(rawValue: vehicleType),
            participantCount: Int16(participantCount),
            splitCosts: splitCosts,
            parkingCost: parking,
            tollCost: tolls,
            notes: nil,
            startTime: sessionModel.startTime,
            endTime: sessionModel.endTime
        )
        travelCharge.client = sessionModel.client
        travelCharge.linkedSession = sessionModel
        travelCharge.service = sessionModel.clientService

        modelContext.insert(travelCharge)

        sessionModel.status = SessionStatus(rawValue: BillingStatus.completed.rawValue)
        try modelContext.save()
    }

    // MARK: - Identity resolution (SwiftData executor; avoids duplicate main-context fetches for workflow handoff)

    public func persistentModelIDForSession(id: UUID) throws -> PersistentIdentifier? {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.persistentModelID
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
