import Core
import Data
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
    private let draftBuilder: BillingDraftBuilderService
    private let modelContext: ModelContext

    public init(
        modelContext: ModelContext,
        draftBuilder: BillingDraftBuilderService
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

    /// Builds billable drafts for the given session models (e.g. rows from `sessionsWithoutDraft`). Uses relationship navigation first; falls back to a single-row fetch only when a fault is missing.
    public func generateDrafts(for sessions: [Session]) async throws -> Int {
        var requests: [BillingDraftBuildRequest] = []
        requests.reserveCapacity(sessions.count)

        for sessionModel in sessions {
            guard let clientId = sessionModel.clientId,
                  let serviceId = sessionModel.clientServiceId
            else { continue }

            let clientModel: Client?
            if let client = sessionModel.client {
                clientModel = client
            } else {
                clientModel = try persistence.fetchClient(id: clientId)
            }

            let serviceModel: ClientService?
            if let service = sessionModel.clientService {
                serviceModel = service
            } else {
                serviceModel = try persistence.fetchClientService(id: serviceId)
            }

            guard let clientModel,
                  let serviceModel
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
        ctx.travelTolls = session.travelTollsAmount ?? travelCharges.reduce(0) { $0 + ($1.tollCost ?? 0) }
        ctx.travelParking = travelCharges.reduce(0) { $0 + ($1.parkingCost ?? 0) }
        ctx.isProviderTravel = (session.travelDistanceKM ?? 0) > 0 || (session.travelTimeMinutes ?? 0) > 0
        return ctx
    }
}
