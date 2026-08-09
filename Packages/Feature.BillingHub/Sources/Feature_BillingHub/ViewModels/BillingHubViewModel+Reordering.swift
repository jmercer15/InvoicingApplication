import Core
import Foundation
import SharedUI
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
        return CurrencyFormatting.display(total)
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

    public func canAddSessionToGroup(sourceID: UUID, groupID: UUID) -> Bool {
        guard case .session(let sourceCard) = boardProjection.card(for: sourceID) else { return false }
        guard let targetGroup = boardProjection.groupedSessions.first(where: { $0.groupID == groupID }) else { return false }

        if targetGroup.sessions.contains(where: { $0.id == sourceID }) { return true }

        guard let firstMember = targetGroup.sessions.first, case .session(let firstCard) = firstMember else { return true }
        guard let sourceClientID = sourceCard.clientID, let targetClientID = firstCard.clientID else { return false }
        return sourceClientID == targetClientID
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
    
    /// Forward "next step" only — must be a legal `BillingTransitionRules` transition.
    /// Grouped does not jump to Add Travel; draft creation is a separate action.
    public func nextColumn(for card: KanbanCardData) -> KanbanCardData.BillingColumnType? {
        switch card.columnType {
        case .completed: return .grouped
        case .grouped, .addTravel: return nil
        case .reviewDrafts: return .readyToSend
        case .readyToSend: return .pending
        case .pending: return .received
        case .received: return nil
        }
    }

    /// - Returns: `true` only when the move succeeded. Failures set `bulkActionFeedback`.
    @discardableResult
    public func advanceCard(_ card: KanbanCardData) async -> Bool {
        guard let target = nextColumn(for: card) else { return false }
        switch card {
        case .session(let data):
            let result = await moveSession(data.sessionId, to: target)
            return result?.isSuccess == true
        case .invoice(let data):
            let result = await moveInvoice(data.invoiceId, to: target)
            return result?.isSuccess == true
        }
    }
}
