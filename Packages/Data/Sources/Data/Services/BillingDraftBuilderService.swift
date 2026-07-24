import Core
import Foundation
import SwiftData
import os

private struct BillingContextSnapshot: Codable {
    let sessionId: UUID
    let clientId: UUID
    let serviceId: UUID
    let computedAt: Date
}

public struct BillingDraftBuildRequest: Sendable {
    public let sessionId: UUID
    public let clientId: UUID
    public let serviceId: UUID
    public let billingContext: NDISBillingContext

    public init(
        sessionId: UUID,
        clientId: UUID,
        serviceId: UUID,
        billingContext: NDISBillingContext
    ) {
        self.sessionId = sessionId
        self.clientId = clientId
        self.serviceId = serviceId
        self.billingContext = billingContext
    }
}

/// Builds a billable draft from a session: computes claimable lines via NDIS billing, runs validation rules, persists draft + issues + lines.
public actor BillingDraftBuilderService: ModelActor {
    private static let serviceSignpostLog = OSLog(subsystem: "com.invoicingapplication.app", category: "billing-draft-builder")
    nonisolated public let modelContainer: ModelContainer
    nonisolated public let modelExecutor: any ModelExecutor

    public init(
        ndisBillingIntegration: NDISBillingIntegrationService,
        modelContainer: ModelContainer,
        mmmZoneLookup: Core.MMMZoneLookup
    ) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(
            modelContext: ModelContext(modelContainer)
        )
        self.ndisBillingIntegration = ndisBillingIntegration
        self.mmmZoneLookup = mmmZoneLookup
    }
    private let ndisBillingIntegration: NDISBillingIntegrationService
    private let mmmZoneLookup: Core.MMMZoneLookup

    /// Builds and persists a billable draft for the given session.
    public func buildDraft(
        sessionId: UUID,
        clientId: UUID,
        serviceId: UUID,
        billingContext: NDISBillingContext
    ) async throws -> BillableDraftSnapshot {
        #if DEBUG
        let signpostID = OSSignpostID(log: Self.serviceSignpostLog)
        os_signpost(.begin, log: Self.serviceSignpostLog, name: "buildDraft", signpostID: signpostID, "%{public}s", sessionId.uuidString)
        defer {
            os_signpost(.end, log: Self.serviceSignpostLog, name: "buildDraft", signpostID: signpostID)
        }
        #endif
        var sessionDescriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == sessionId })
        sessionDescriptor.fetchLimit = 1
        var clientDescriptor = FetchDescriptor<Client>(predicate: #Predicate { $0.id == clientId })
        clientDescriptor.fetchLimit = 1
        var serviceDescriptor = FetchDescriptor<ClientService>(predicate: #Predicate { $0.id == serviceId })
        serviceDescriptor.fetchLimit = 1

        guard let sessionModel = try modelContext.fetch(sessionDescriptor).first else {
            throw PersistenceError.notFound(id: sessionId)
        }
        guard let clientModel = try modelContext.fetch(clientDescriptor).first else {
            throw PersistenceError.notFound(id: clientId)
        }
        guard let serviceModel = try modelContext.fetch(serviceDescriptor).first else {
            throw PersistenceError.notFound(id: serviceId)
        }

        let session = sessionModel.snapshot()
        let client = clientModel.snapshot()
        let service = serviceModel.snapshot()

        let claimableItems = try await ndisBillingIntegration.calculateBillableAmounts(
            for: session,
            client: client,
            service: service,
            billingContext: billingContext
        )
    
        let supportStart = session.startTime ?? session.endTime ?? Date()
        let draftId = UUID()
        let now = Date()
        let defaultGST = GSTCode.p2.rawValue

        var issues: [DraftIssue] = []
        let timeLimitRule = ClaimTimeLimitRule(referenceDate: now)
        if let issue = timeLimitRule.evaluate(supportStartDate: supportStart, draftId: draftId) {
            issues.append(issue)
        }
        let validationContext = DraftValidationContext(
            session: session,
            client: client,
            billingContext: billingContext,
            supportStartDate: supportStart,
            draftId: draftId,
            referenceDate: now
        )
        issues += TravelEligibilityAndCapsRule(mmmLookup: mmmZoneLookup).evaluate(context: validationContext)
        issues += NonLabourTravelCapRule().evaluate(context: validationContext)
        issues += CancellationRegimeRule().evaluate(context: validationContext)
        issues += EvidenceCompletenessGate().evaluate(context: validationContext)

        let draftStatus = resolveDraftStatus(issues: issues)
        let snapshotData = try JSONEncoder().encode(BillingContextSnapshot(
            sessionId: sessionId,
            clientId: clientId,
            serviceId: serviceId,
            computedAt: now
        ))

        let draft = BillableDraftSnapshot(
            id: draftId,
            sessionId: sessionId,
            clientId: clientId,
            serviceId: serviceId,
            computedAt: now,
            billingContextSnapshot: snapshotData,
            draftStatus: draftStatus.rawValue,
            createdAt: now,
            updatedAt: nil
        )
        let savedDraft = try persistDraft(draft)

        let claimableLines: [ClaimableLineSnapshot] = claimableItems.enumerated().map { index, item in
            let (quantityDecimal, hoursHHHMM) = quantityOrHours(for: item)
            let serviceFrom = session.startTime ?? now
            let serviceTo = session.endTime ?? now
            let claimReference = "DRAFT-\(savedDraft.id.uuidString)-\(index)"
            return ClaimableLineSnapshot(
                id: UUID(),
                claimType: item.claimType,
                supportItemNumber: item.supportItemNumber,
                serviceFrom: serviceFrom,
                serviceTo: serviceTo,
                quantityDecimal: quantityDecimal.map { NSDecimalNumber(decimal: $0).doubleValue },
                hoursHHHMM: hoursHHHMM,
                unitPrice: item.unitPrice,
                gstCode: defaultGST,
                cancellationReason: nil,
                travelKM: nil,
                travelMinutes: nil,
                metadata: nil,
                claimReference: claimReference,
                draftId: savedDraft.id
            )
        }
        if !issues.isEmpty { try persistIssues(issues, draftId: savedDraft.id) }
        if !claimableLines.isEmpty { try persistClaimableLines(claimableLines, draftId: savedDraft.id) }
        return try fetchDraftSnapshot(id: savedDraft.id) ?? savedDraft
    }

    public func buildDrafts(_ requests: [BillingDraftBuildRequest]) async throws -> [UUID] {
        var createdDraftIDs: [UUID] = []
        createdDraftIDs.reserveCapacity(requests.count)
        for request in requests {
            let draft = try await buildDraft(
                sessionId: request.sessionId,
                clientId: request.clientId,
                serviceId: request.serviceId,
                billingContext: request.billingContext
            )
            createdDraftIDs.append(draft.id)
        }
        return createdDraftIDs
    }

    private func resolveDraftStatus(issues: [DraftIssue]) -> DraftStatus {
        let hasBlocking = issues.contains { $0.severity == .blocking }
        let hasWarning = issues.contains { $0.severity == .warning }
        if hasBlocking { return .needsInfo }
        if hasWarning { return .needsReview }
        return .ready
    }

    private func quantityOrHours(for item: NDISClaimableLineItem) -> (Decimal?, String?) {
        let unit = unitForClaimType(item.claimType)
        if unit == "hour" {
            return (nil, formatHours(quantity: item.quantity))
        }
        return (Decimal(item.quantity), nil)
    }

    private func unitForClaimType(_ claimType: String) -> String {
        if claimType.contains("NonLabour") || claimType == "ActivityTransport" { return "km" }
        if claimType.contains("OtherCosts") { return "each" }
        if claimType == "CentreCapitalCost" || claimType == "EstablishmentFee" { return "unit" }
        return "hour"
    }

    private func formatHours(quantity: Double) -> String {
        let totalMinutes = max(Int((quantity * 60).rounded()), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%03d:%02d", hours, minutes)
    }
}

// MARK: - SwiftData persistence helpers

private extension BillingDraftBuilderService {
    func fetchDraftSnapshot(id: UUID) throws -> BillableDraftSnapshot? {
        let descriptor = FetchDescriptor<BillableDraft>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first?.snapshot()
    }

    func persistDraft(_ snapshot: BillableDraftSnapshot) throws -> BillableDraftSnapshot {
        let model = BillableDraft(
            id: snapshot.id,
            sessionId: snapshot.sessionId,
            clientId: snapshot.clientId,
            serviceId: snapshot.serviceId,
            computedAt: snapshot.computedAt,
            billingContextSnapshot: snapshot.billingContextSnapshot,
            draftStatus: snapshot.draftStatus,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt
        )

        let sessionId = snapshot.sessionId
        let clientId = snapshot.clientId
        let serviceId = snapshot.serviceId

        model.session = try modelContext.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == sessionId })).first
        model.client = try modelContext.fetch(FetchDescriptor<Client>(predicate: #Predicate { $0.id == clientId })).first
        model.service = try modelContext.fetch(FetchDescriptor<ClientService>(predicate: #Predicate { $0.id == serviceId })).first

        modelContext.insert(model)
        if modelContext.hasChanges { try modelContext.save() }
        return model.snapshot()
    }

    func persistIssues(_ issues: [DraftIssue], draftId: UUID) throws {
        let draftDescriptor = FetchDescriptor<BillableDraft>(predicate: #Predicate { $0.id == draftId })
        let draftModel = try modelContext.fetch(draftDescriptor).first

        for issue in issues {
            let model = DraftIssue(
                id: issue.id,
                draftId: draftId,
                severity: issue.severity,
                code: issue.code,
                message: issue.message,
                resolutionKind: issue.resolutionKind,
                resolutionData: issue.resolutionData,
                createdAt: issue.createdAt
            )
            model.draft = draftModel
            modelContext.insert(model)
        }
        if modelContext.hasChanges { try modelContext.save() }
    }

    func persistClaimableLines(_ lines: [ClaimableLineSnapshot], draftId: UUID) throws {
        let draftDescriptor = FetchDescriptor<BillableDraft>(predicate: #Predicate { $0.id == draftId })
        let draftModel = try modelContext.fetch(draftDescriptor).first

        for line in lines {
            let model = ClaimableLine(
                id: line.id,
                draftId: draftId,
                claimType: line.claimType,
                supportItemNumber: line.supportItemNumber,
                serviceFrom: line.serviceFrom,
                serviceTo: line.serviceTo,
                quantityDecimal: line.quantityDecimal,
                hoursHHHMM: line.hoursHHHMM,
                unitPrice: line.unitPrice,
                gstCode: line.gstCode,
                cancellationReason: line.cancellationReason,
                travelKM: line.travelKM,
                travelMinutes: line.travelMinutes,
                metadata: line.metadata,
                claimReference: line.claimReference
            )
            model.draft = draftModel
            modelContext.insert(model)
        }
        if modelContext.hasChanges { try modelContext.save() }
    }
}
