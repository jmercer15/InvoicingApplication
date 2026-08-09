#if DEBUG
import Foundation

/// Shared test double for `NDISBillingIntegrationServiceProtocol`.
/// Replaces per-target copies in BillingHub and integration tests.
public struct StubNDISBillingIntegrationService: NDISBillingIntegrationServiceProtocol, Sendable {
    public let response: NDISBillingReport

    public init(response: NDISBillingReport = .empty) {
        self.response = response
    }

    public func generateNDISInvoice(for sessionIds: [UUID], clientId: UUID) async throws -> NDISBillingReport {
        response
    }
}
#endif
