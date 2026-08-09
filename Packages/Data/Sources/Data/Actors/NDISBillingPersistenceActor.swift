import Foundation
import SwiftData

/// Background `@ModelActor` for NDIS billing fetch/save work previously on `@MainActor`.
@ModelActor
public actor NDISBillingPersistenceActor {
    /// Loads persisted travel totals for a session without blocking the main actor.
    func resolvePersistedTravelTotals(forSessionId sessionId: UUID) throws -> NDISBillingIntegrationService.PersistedTravelTotals? {
        NDISBillingIntegrationService.resolvePersistedTravelTotals(forSessionId: sessionId, in: modelContext)
    }
}
