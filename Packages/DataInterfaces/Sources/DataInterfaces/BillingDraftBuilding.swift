import Core
import Foundation

/// Request payload for building a billable draft from a session billing context.
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

/// Builds and persists billable drafts from session billing contexts.
public protocol BillingDraftBuilding: Sendable {
    func buildDraft(
        sessionId: UUID,
        clientId: UUID,
        serviceId: UUID,
        billingContext: NDISBillingContext
    ) async throws -> BillableDraftSnapshot

    func buildDrafts(_ requests: [BillingDraftBuildRequest]) async throws -> [UUID]
}
