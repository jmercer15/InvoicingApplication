import Core
import Data
import Foundation
import SwiftData

extension BillingHubViewModel {
    
    public func formattedTotal(for column: KanbanCardData.BillingColumnType, in projection: BillingHubBoardProjection) -> String? {
        guard column.isInvoiceLane else { return nil }
        let cards = projection.invoicesByStatus[column] ?? []
        let total: Decimal = cards.reduce(0) { sum, card in
            if case .invoice(let data) = card {
                return sum + (Decimal(string: data.amount.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) ?? 0)
            }
            return sum
        }
        return NumberFormatter.currency.string(from: total as NSDecimalNumber)
    }

    public func reorderInvoices(
        in column: KanbanCardData.BillingColumnType,
        sourceID: UUID,
        beforeTargetID: UUID?,
        projection: BillingHubBoardProjection
    ) {
        Task {
            var ids = projection.invoicesByStatus[column]?.map(\.id) ?? []
            guard let index = ids.firstIndex(of: sourceID) else { return }
            ids.remove(at: index)
            if let targetID = beforeTargetID, let targetIndex = ids.firstIndex(of: targetID) {
                ids.insert(sourceID, at: targetIndex)
            } else {
                ids.append(sourceID)
            }
            try? await workflow.reorderInvoices(ids: ids)
        }
    }

    public func sortOption(for column: KanbanCardData.BillingColumnType) -> ColumnSortOption {
        return columnSortOptions[column] ?? .manual
    }

    public func setSortOption(_ option: ColumnSortOption, for column: KanbanCardData.BillingColumnType) {
        columnSortOptions[column] = option
    }

    public func reorderSessionInGroupedColumn(sourceID _: UUID, beforeClusterID _: UUID?) {}

    public func reorderInGrouped(sourceID: UUID, beforeTargetID _: UUID?, scopeGroupID: UUID?) {
        Task {
            guard let sourceModelID = await sessionModelID(for: sourceID) else { return }
            try? await workflow.reorderSessions(modelIDs: [sourceModelID], scopeGroupID: scopeGroupID)
        }
    }

    public func canAddSessionToGroup(sourceID _: UUID, groupID _: UUID) -> Bool {
        return true
    }

    public func reorderInCompleted(sourceID: UUID, beforeTargetID _: UUID?) {
        Task {
            guard let sourceModelID = await sessionModelID(for: sourceID) else { return }
            try? await workflow.reorderSessions(modelIDs: [sourceModelID], scopeGroupID: nil)
        }
    }

    public func reorderInAddTravel(sourceID: UUID, beforeTargetID _: UUID?) {
        Task {
            guard let sourceModelID = await sessionModelID(for: sourceID) else { return }
            try? await workflow.reorderSessions(modelIDs: [sourceModelID], scopeGroupID: nil)
        }
    }

    public func reorderGroupInGroupedColumn(sourceGroupID _: UUID, beforeTargetID _: UUID?) {}
    
    public func nextColumn(for card: KanbanCardData) -> KanbanCardData.BillingColumnType? {
        switch card.columnType {
        case .completed: return .grouped
        case .grouped: return .addTravel
        case .addTravel: return .reviewDrafts
        case .reviewDrafts: return .readyToSend
        case .readyToSend: return .pending
        case .pending: return .received
        case .received: return nil
        }
    }

    public func advanceCard(_ card: KanbanCardData) async -> Bool {
        guard let target = nextColumn(for: card) else { return false }
        switch card {
        case .session(let data):
            await moveSession(data.sessionId, to: target)
        case .invoice(let data):
            await moveInvoice(data.invoiceId, to: target)
        }
        return true
    }
}
