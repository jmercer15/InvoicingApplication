import Core
import PersistenceModels
import DataInterfaces
import Foundation
import SharedUI
import SwiftData
import SwiftUI
import Observation

@Observable
@MainActor
public final class BillableDraftsViewModel {
    public private(set) var selectedStatus: DraftStatus?
    public var dateRange: ClosedRange<Date>?
    public var filterClientId: UUID?
    public var filterPlanType: String?
    public private(set) var sessionsWithoutDraft: [Session] = []
    public var errorMessage: String?

    private let persistence: any BillableDraftMainContextPersisting
    private let draftBuilder: any BillingDraftBuilding
    private let modelContext: ModelContext

    public init(
        modelContext: ModelContext,
        draftBuilder: any BillingDraftBuilding
    ) {
        self.modelContext = modelContext
        self.draftBuilder = draftBuilder
        self.persistence = SwiftDataBillableDraftMainContextPersistence(modelContext: modelContext)
    }

    public func setStatusFilter(_ status: DraftStatus?) {
        selectedStatus = status
    }

    /// Applies sessions materialized by a view-scoped `@Query` window (no VM-owned range fetch).
    public func applySessionsWithoutDraft(_ sessions: [Session]) {
        sessionsWithoutDraft = sessions
    }

    /// Drops live Session refs after CloudKit HistoryExpired / store revision bumps.
    public func clearSessionsWithoutDraft() {
        sessionsWithoutDraft = []
    }

    public func buildDraft(
        session: Session,
        client: Client,
        service: ClientService,
        billingContext: NDISBillingContext
    ) async throws -> BillableDraftSnapshot {
        try await draftBuilder.buildDraft(
            sessionId: session.id,
            clientId: client.id,
            serviceId: service.id,
            billingContext: billingContext
        )
    }

    public func markReady(draft: BillableDraft) throws {
        try persistence.updateDraftStatus(draft, status: .ready)
    }

    public func lockDraft(draft: BillableDraft) throws {
        try persistence.updateDraftStatus(draft, status: .locked)
    }

    /// Builds billable drafts for sessions identified by the given models.
    /// Uses session IDs only — never faults relationships on possibly-invalidated live models.
    public func generateDrafts(for sessions: [Session]) async throws -> Int {
        let sessionIDs = sessions.map(\.id)
        return try await generateDrafts(forSessionIDs: sessionIDs)
    }

    public func generateDrafts(forSessionIDs sessionIDs: [UUID]) async throws -> Int {
        var requests: [BillingDraftBuildRequest] = []
        requests.reserveCapacity(sessionIDs.count)

        for sessionID in sessionIDs {
            guard let sessionModel = try persistence.fetchSession(id: sessionID) else { continue }
            guard let clientId = sessionModel.clientId,
                  let serviceId = sessionModel.clientServiceId
            else { continue }

            guard let clientModel = try persistence.fetchClient(id: clientId),
                  let serviceModel = try persistence.fetchClientService(id: serviceId)
            else { continue }

            let context = billingContext(from: sessionModel, service: serviceModel)
            requests.append(
                BillingDraftBuildRequest(
                    sessionId: sessionModel.id,
                    clientId: clientModel.id,
                    serviceId: serviceModel.id,
                    billingContext: context
                )
            )
        }

        let createdDraftIDs = try await draftBuilder.buildDrafts(requests)
        return createdDraftIDs.count
    }

    private func billingContext(from session: Session, service: ClientService) -> NDISBillingContext {
        var ctx = NDISBillingContext()
        ctx.supportItemNumber = service.ndisCode ?? ""
        ctx.travelDistance = session.travelDistanceKM ?? 0
        ctx.travelTime = session.travelTimeMinutes ?? 0
        let travelCharges = session.travelCharges ?? []
        ctx.travelTolls = session.travelTollsAmount ?? travelCharges.reduce(0) { $0 + NSDecimalNumber(decimal: $1.tollCost ?? 0).doubleValue }
        ctx.travelParking = travelCharges.reduce(0) { $0 + NSDecimalNumber(decimal: $1.parkingCost ?? 0).doubleValue }
        ctx.isProviderTravel = (session.travelDistanceKM ?? 0) > 0 || (session.travelTimeMinutes ?? 0) > 0
        return ctx
    }
}
