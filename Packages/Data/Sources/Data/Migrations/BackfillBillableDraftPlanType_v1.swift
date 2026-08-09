import Foundation
import PersistenceModels
import SwiftData

/// Backfills denormalized plan-management type on existing billable drafts (SD-P3-11).
public enum BackfillBillableDraftPlanType_v1 {
    public static let migrationID = "backfill_billable_draft_plan_type_v1"

    public static func execute(modelContext: ModelContext) throws {
        let drafts = try modelContext.fetch(FetchDescriptor<BillableDraft>())
        guard !drafts.isEmpty else { return }

        let clientIDs = Set(drafts.map(\.clientId))
        var planByClientID: [UUID: String] = [:]
        planByClientID.reserveCapacity(clientIDs.count)

        for clientID in clientIDs {
            var descriptor = FetchDescriptor<Client>(
                predicate: EntityPredicateBuilders.client(id: clientID)
            )
            descriptor.fetchLimit = 1
            if let client = try modelContext.fetch(descriptor).first {
                planByClientID[clientID] = client.planManagementType ?? ""
            }
        }

        var didChange = false
        for draft in drafts where draft.clientPlanManagementType.isEmpty {
            draft.clientPlanManagementType = planByClientID[draft.clientId] ?? ""
            didChange = true
        }

        if didChange, modelContext.hasChanges {
            try modelContext.save()
        }
    }

    public static func rollback(modelContext: ModelContext) throws {
        _ = modelContext
    }
}
