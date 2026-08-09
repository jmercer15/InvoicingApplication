import Foundation
import Core

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
            // Same-column reorder stubs do not persist peer order — disable no-op drops.
            guard source.columnType != column else { return false }
            return canMoveSession(from: source.columnType, to: column)

        case .invoice(let sourceID):
            guard let source = invoiceCard(for: sourceID) else { return false }
            guard targetID != sourceID else { return false }
            // Invoice lanes have no persisted position — disable same-column reorder lies.
            guard source.columnType != column else { return false }
            return canMoveInvoice(from: source.columnType, to: column)

        case .group:
            return false
        }
    }

    public func canAcceptSessionDropInGroupedColumn(sourceID: UUID, beforeClusterID: UUID?) -> Bool {
        guard let source = sessionCard(for: sourceID) else { return false }
        // Already in Grouped: cluster reorder is a no-op stub — only accept column moves in.
        guard source.columnType != .grouped else { return false }
        guard canMoveSession(from: source.columnType, to: .grouped) else { return false }

        if let beforeClusterID {
            guard projection.groupedSessions.contains(where: { ($0.groupID ?? $0.sessions.first?.id) == beforeClusterID }) else {
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

        // Already a member: in-group reorder is a no-op stub.
        if targetGroup.sessions.contains(where: { $0.id == sourceID }) {
            return false
        }

        // Client matching: reject stacking sessions from different clients into one group.
        guard let firstSession = targetGroup.sessions.first else { return false }

        guard let clientID = fetchClientForSession(firstSession.id),
              let sourceClientID = fetchClientForSession(source.sessionId) else { return false }

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
    
    private func fetchClientForSession(_ id: UUID) -> UUID? {
        sessionCard(for: id)?.clientID
    }
}
