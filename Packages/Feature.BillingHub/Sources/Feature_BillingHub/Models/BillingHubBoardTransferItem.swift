import Foundation

struct BillingHubBoardTransferItem: Codable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        case session
        case invoice
        case group
    }

    struct Snapshot: Codable, Hashable, Sendable {
        let title: String
        let subtitle: String
    }

    let itemID: UUID
    let kind: Kind
    let snapshot: Snapshot

    var id: UUID { itemID }

    public var dragKind: BillingHubBoardDragKind {
        switch kind {
        case .session:
            return .session(itemID)
        case .invoice:
            return .invoice(itemID)
        case .group:
            return .group(itemID)
        }
    }
}

extension BillingHubBoardTransferItem {
    static func previewItem(for card: KanbanCardData) -> Self {
        let kind: Kind = switch card {
        case .session: .session
        case .invoice: .invoice
        }

        return BillingHubBoardTransferItem(
            itemID: card.id,
            kind: kind,
            snapshot: .init(title: card.titleText, subtitle: card.subtitleText)
        )
    }

    static func previewItem(for group: SessionGroup) -> Self {
        let itemLabel: String
        if case .invoice? = group.sessions.first {
            itemLabel = "items"
        } else {
            itemLabel = "sessions"
        }

        let snapshot = Snapshot(
            title: group.sessions.first?.titleText ?? "Group",
            subtitle: "\(group.sessions.count) \(itemLabel)"
        )

        return BillingHubBoardTransferItem(
            itemID: group.groupID ?? group.id,
            kind: group.groupID == nil ? .session : .group,
            snapshot: snapshot
        )
    }
}
