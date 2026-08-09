import Foundation
import Core

public struct BillingHubBoardProjection: Sendable {
    public static let empty = BillingHubBoardProjection(
        sessionsByStatus: [:],
        invoicesByStatus: [:],
        groupedSessions: [],
        clientSummaries: []
    )

    public let sessionsByStatus: [KanbanCardData.BillingColumnType: [KanbanCardData]]
    public let invoicesByStatus: [KanbanCardData.BillingColumnType: [KanbanCardData]]
    public let groupedSessions: [SessionGroup]
    public let clientSummaries: [BillingHubViewModel.ClientSummary]
    private let cardLookup: [UUID: KanbanCardData]

    public init(
        sessionsByStatus: [KanbanCardData.BillingColumnType: [KanbanCardData]],
        invoicesByStatus: [KanbanCardData.BillingColumnType: [KanbanCardData]],
        groupedSessions: [SessionGroup],
        clientSummaries: [BillingHubViewModel.ClientSummary]
    ) {
        self.sessionsByStatus = sessionsByStatus
        self.invoicesByStatus = invoicesByStatus
        self.groupedSessions = groupedSessions
        self.clientSummaries = clientSummaries
        self.cardLookup = Self.makeCardLookup(
            sessionsByStatus: sessionsByStatus,
            invoicesByStatus: invoicesByStatus,
            groupedSessions: groupedSessions
        )
    }

    func card(for id: UUID?) -> KanbanCardData? {
        guard let id else { return nil }
        return cardLookup[id]
    }

    /// Lightweight identity for kanban presentation caching (card counts + grouped batch count).
    var contentFingerprint: Int {
        var hasher = Hasher()
        for column in KanbanCardData.BillingColumnType.allCases {
            hasher.combine(sessionsByStatus[column]?.count ?? 0)
            hasher.combine(invoicesByStatus[column]?.count ?? 0)
        }
        hasher.combine(groupedSessions.count)
        hasher.combine(clientSummaries.count)
        return hasher.finalize()
    }
}

private extension BillingHubBoardProjection {
    static func makeCardLookup(
        sessionsByStatus: [KanbanCardData.BillingColumnType: [KanbanCardData]],
        invoicesByStatus: [KanbanCardData.BillingColumnType: [KanbanCardData]],
        groupedSessions: [SessionGroup]
    ) -> [UUID: KanbanCardData] {
        Dictionary(
            uniqueKeysWithValues: (
                Array(sessionsByStatus.values.joined()) +
                Array(invoicesByStatus.values.joined()) +
                groupedSessions.flatMap(\.sessions)
            ).map { ($0.id, $0) }
        )
    }
}
