import Foundation
import SwiftData
import PersistenceModels

@ModelActor
public actor BillableDraftsWorkflowActor {
    
    public func fetchDraftIDs(
        dateRange: ClosedRange<Date>?,
        filterClientId: UUID?,
        filterPlanType: String?
    ) throws -> [PersistentIdentifier] {
        if let planType = filterPlanType, !planType.isEmpty {
            var descriptor = FetchDescriptor<BillableDraft>(
                predicate: EntityPredicateBuilders.billableDrafts(planType: planType),
                sortBy: [SortDescriptor(\.computedAt, order: .reverse)]
            )
            let planFiltered = try modelContext.fetch(descriptor)

            return planFiltered.filter { draft in
                if let range = dateRange, !range.contains(draft.computedAt) {
                    return false
                }
                if let cid = filterClientId, draft.clientId != cid {
                    return false
                }
                return true
            }.map(\.persistentModelID)
        }

        let draftDescriptor = FetchDescriptor<BillableDraft>(
            sortBy: [SortDescriptor(\.computedAt, order: .reverse)]
        )

        let allDrafts = try modelContext.fetch(draftDescriptor)

        return allDrafts.filter { draft in
            if let range = dateRange, !range.contains(draft.computedAt) {
                return false
            }
            if let cid = filterClientId, draft.clientId != cid {
                return false
            }
            return true
        }.map(\.persistentModelID)
    }
}
