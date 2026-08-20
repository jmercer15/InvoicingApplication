import Foundation
import SwiftData
import PersistenceModels

/// Background `@ModelActor` for NDIS billing fetch/save work previously on `@MainActor`.
@ModelActor
public actor NDISBillingPersistenceActor {
    /// Loads persisted travel totals for a session without blocking the main actor.
    func resolvePersistedTravelTotals(forSessionId sessionId: UUID) throws -> NDISBillingIntegrationService.PersistedTravelTotals? {
        NDISBillingIntegrationService.resolvePersistedTravelTotals(forSessionId: sessionId, in: modelContext)
    }

    /// Batch deletes billable drafts for a specific client.
    public func clearBillableDrafts(forClientId clientId: UUID) throws {
        try modelContext.delete(model: BillableDraft.self, where: #Predicate { $0.clientId == clientId })
        try modelContext.save()
    }
}
