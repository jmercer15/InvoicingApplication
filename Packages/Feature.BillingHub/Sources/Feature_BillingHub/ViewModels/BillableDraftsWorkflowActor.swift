import Foundation
import SwiftData
import Core
import Data

@ModelActor
public actor BillableDraftsWorkflowActor {
    
    public func fetchDraftIDs(
        dateRange: ClosedRange<Date>?,
        filterClientId: UUID?,
        filterPlanType: String?
    ) throws -> [PersistentIdentifier] {
        let draftDescriptor = FetchDescriptor<BillableDraft>(
            sortBy: [SortDescriptor(\.computedAt, order: .reverse)]
        )
        
        let allDrafts = try modelContext.fetch(draftDescriptor)
        
        var allowedClientIdsByPlan: Set<UUID>? = nil
        if let planType = filterPlanType, !planType.isEmpty {
            let clientDescriptor = FetchDescriptor<Client>()
            let clients = try modelContext.fetch(clientDescriptor)
            allowedClientIdsByPlan = Set(clients.lazy.filter { $0.planManagementType == planType }.map(\.id))
        }
        
        return allDrafts.filter { draft in
            if let range = dateRange, !range.contains(draft.computedAt) {
                return false
            }
            if let cid = filterClientId, draft.clientId != cid {
                return false
            }
            if let allowedClientIdsByPlan, !allowedClientIdsByPlan.contains(draft.clientId) {
                return false
            }
            return true
        }.map(\.persistentModelID)
    }
}
