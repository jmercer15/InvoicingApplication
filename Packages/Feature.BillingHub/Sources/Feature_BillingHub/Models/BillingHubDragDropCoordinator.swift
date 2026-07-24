import Foundation
import Core
import Data

/// Centralizes drag-and-drop validation logic for the Billing Hub Kanban board.
public struct BillingHubDragDropCoordinator {
    
    private let projection: BillingHubBoardProjection
    
    public init(projection: BillingHubBoardProjection) {
        self.projection = projection
    }
    
    public func canAcceptCardDrop(
        _ dragKind: BillingHubBoardDragKind,
        into column: KanbanCardData.BillingColumnType,
        before targetID: UUID?
    ) -> Bool {
        if let targetID {
            guard let targetCard = projection.card(for: targetID), targetCard.columnType == column else {
                return false
            }
        }

        switch dragKind {
        case .session(let sourceID):
            guard let source = sessionCard(for: sourceID) else { return false }
            guard targetID != sourceID else { return false }
            return canMoveSession(from: source.columnType, to: column)

        case .invoice(let sourceID):
            guard let source = invoiceCard(for: sourceID) else { return false }
            guard targetID != sourceID else { return false }
            return canMoveInvoice(from: source.columnType, to: column)

        case .group:
            return false
        }
    }

    public func canAcceptSessionDropInGroupedColumn(sourceID: UUID, beforeClusterID: UUID?) -> Bool {
        guard let source = sessionCard(for: sourceID) else { return false }
        guard canMoveSession(from: source.columnType, to: .grouped) else { return false }

        if let beforeClusterID {
            guard projection.groupedSessions.contains(where: { ($0.groupID ?? $0.sessions.first?.id) == beforeClusterID }) else { return false }
            if source.columnType == .grouped, source.groupID == nil, beforeClusterID == sourceID {
                return false
            }
        }
        return true
    }

    public func canAcceptSessionDropInGroup(
        sourceID: UUID,
        beforeTargetID: UUID?,
        scopeGroupID: UUID?
    ) -> Bool {
        guard let scopeGroupID else { return false }
        guard let source = sessionCard(for: sourceID) else { return false }
        guard let targetGroup = projection.groupedSessions.first(where: { $0.groupID == scopeGroupID }) else { return false }
        guard canMoveSession(from: source.columnType, to: .grouped) else { return false }

        if let beforeTargetID {
            guard targetGroup.sessions.contains(where: { $0.id == beforeTargetID }) else { return false }
            guard beforeTargetID != sourceID else { return false }
        }

        if targetGroup.sessions.contains(where: { $0.id == sourceID }) {
            return true
        }

        // Logic for client matching...
        guard let firstSession = targetGroup.sessions.first else { return false }
        
        let clientID = fetchClientForSession(firstSession.id)
        let sourceClientID = fetchClientForSession(source.sessionId)
        
        return sourceClientID == clientID
    }

    // MARK: - Private

    private func canMoveSession(from src: KanbanCardData.BillingColumnType, to dst: KanbanCardData.BillingColumnType) -> Bool {
        BillingTransitionRules.isValidSessionTransition(from: src.billingStatus, to: dst.billingStatus)
    }

    private func canMoveInvoice(from src: KanbanCardData.BillingColumnType, to dst: KanbanCardData.BillingColumnType) -> Bool {
        BillingTransitionRules.isValidInvoiceTransition(from: src.billingStatus, to: dst.billingStatus)
    }

    private func sessionCard(for id: UUID) -> SessionKanbanCardData? {
        guard case .session(let data) = projection.card(for: id) else { return nil }
        return data
    }

    private func invoiceCard(for id: UUID) -> InvoiceKanbanCardData? {
        guard case .invoice(let data) = projection.card(for: id) else { return nil }
        return data
    }
    
    private func fetchClientForSession(_: UUID) -> UUID? {
        // This usually comes from the model but for validation we might need the projection or a lookup
        // For simplicity in this coordinator, we'll assume the projection handles client summaries or similar
        return nil // Placeholder, needs actual implementation based on where client info lives
    }
}
