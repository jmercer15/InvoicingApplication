import Core
import CoreLocation
import Foundation

/// Builds a **board projection** (`KanbanCardData` lanes) from raw `@Model` graphs.
struct BillingHubProjectionBuilder {
    static func project(
        sessions: [Session],
        invoices: [Invoice],
        clients: [Client],
        clientServices: [ClientService],
        searchText: String,
        selectedClientID: UUID?,
        sortOptions: [KanbanCardData.BillingColumnType: ColumnSortOption]
    ) -> BillingHubBoardProjection {
        var clientServicesCache: [UUID: [ClientService]] = [:]
        for service in clientServices {
            guard let clientId = service.clientId else { continue }
            clientServicesCache[clientId, default: []].append(service)
        }

        let filteredSessions = filterSessions(
            sessions,
            clients: clients,
            searchText: searchText,
            selectedClientID: selectedClientID
        )
        let filteredInvoices = filterInvoices(
            invoices,
            searchText: searchText,
            selectedClientID: selectedClientID
        )

        let sessionCards = filteredSessions.compactMap {
            mapSessionToKanbanCard($0, clients: clients, clientServicesCache: clientServicesCache, allSessions: sessions)
        }
        let invoiceCards = filteredInvoices.compactMap { mapInvoiceToKanbanCard($0, allSessions: sessions) }

        var sessionsByStatus = Dictionary(grouping: sessionCards, by: { $0.columnType })
        let groupedPositions = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.groupedPosition) })
        for (column, cards) in sessionsByStatus {
            if column == .grouped {
                sessionsByStatus[column] = cards.sorted { lhs, rhs in
                    let leftPosition: Int32 = {
                        if case .session(let data) = lhs { return groupedPositions[data.sessionId] ?? Int32.max }
                        return Int32.max
                    }()
                    let rightPosition: Int32 = {
                        if case .session(let data) = rhs { return groupedPositions[data.sessionId] ?? Int32.max }
                        return Int32.max
                    }()
                    return leftPosition < rightPosition
                }
            } else {
                sessionsByStatus[column] = sortCards(cards, for: column, sortOptions: sortOptions)
            }
        }

        var invoicesByStatus = Dictionary(grouping: invoiceCards, by: \.columnType)
        for (column, cards) in invoicesByStatus {
            invoicesByStatus[column] = sortCards(cards, for: column, sortOptions: sortOptions)
        }

        let groupedSessionModels = filteredSessions.filter { canonicalSessionStatusToken($0.statusToken) == "grouped" }
        let summaries = clientSummaries(from: sessions, invoices: invoices, clients: clients)

        return BillingHubBoardProjection(
            sessionsByStatus: sessionsByStatus,
            invoicesByStatus: invoicesByStatus,
            groupedSessions: makeSessionGroups(
                from: groupedSessionModels,
                clients: clients,
                clientServicesCache: clientServicesCache,
                allSessions: sessions
            ),
            clientSummaries: summaries
        )
    }

    private static func clientSummaries(from sessions: [Session], invoices: [Invoice], clients: [Client]) -> [BillingHubViewModel.ClientSummary] {
        let clientNames = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0.fullName) })
        let sessionClientIDs = sessions.compactMap(\.clientId)
        let invoiceClientIDs = invoices.compactMap(\.clientId)
        let clientIDs = Set(sessionClientIDs + invoiceClientIDs)

        let summaries = clientIDs.map { clientID -> BillingHubViewModel.ClientSummary in
        let snapshotName = invoices.first(where: { $0.clientId == clientID })?.clientName
            let resolvedName = clientNames[clientID] ?? snapshotName ?? "Client \(clientID.uuidString.prefix(8))"
            return BillingHubViewModel.ClientSummary(id: clientID, name: resolvedName)
        }

        return summaries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func sortCards(
        _ cards: [KanbanCardData],
        for column: KanbanCardData.BillingColumnType,
        sortOptions: [KanbanCardData.BillingColumnType: ColumnSortOption]
    ) -> [KanbanCardData] {
        let option = sortOptions[column] ?? .manual
        guard option != .manual else { return cards }

        return cards.sorted { lhs, rhs in
            switch option {
            case .manual:
                return false
            case .dateAsc:
                return cardDate(lhs) < cardDate(rhs)
            case .dateDesc:
                return cardDate(lhs) > cardDate(rhs)
            case .clientName:
                return cardClientName(lhs).localizedCaseInsensitiveCompare(cardClientName(rhs)) == .orderedAscending
            case .amountAsc:
                return cardAmount(lhs) < cardAmount(rhs)
            case .amountDesc:
                return cardAmount(lhs) > cardAmount(rhs)
            }
        }
    }

    private static func cardDate(_ card: KanbanCardData) -> Date {
        switch card {
        case .session(let data):
            return data.startTime ?? .distantPast
        case .invoice(let data):
            return data.rawDate ?? parseCardDate(data.date) ?? .distantPast
        }
    }

    private static func cardClientName(_ card: KanbanCardData) -> String {
        switch card {
        case .session(let data): return data.clientName
        case .invoice(let data): return data.clientName
        }
    }

    private static func cardAmount(_ card: KanbanCardData) -> Decimal {
        switch card {
        case .session: return 0
        case .invoice(let data): return parseAmount(data.amount) ?? 0
        }
    }

    private static func parseCardDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        for format in ["MMM d", "MMM d, yyyy", "d MMM", "d MMM yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }

    private static func parseAmount(_ amountString: String) -> Decimal? {
        let cleaned = amountString
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned)
    }
}
