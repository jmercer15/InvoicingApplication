import Foundation
import Core
import SharedUI
import SwiftData
import os

struct InvoicesListQuerySpec: Equatable {
    var searchText: String
    var statuses: Set<String>
    var filterStartDate: Date?
    var filterEndDate: Date?
    var minimumAmount: Double?
    var maximumAmount: Double?
    var clientNames: Set<String>
    var sortField: SortField
    var sortDirection: SortDirection
    var groupBy: GroupBy
}

struct InvoicesListProjection {
    let filteredInvoices: [Invoice]
    let groupedInvoices: [String: [Invoice]]
    let treeItems: [TreeItem]
    let availableClientNames: [String]
}

enum InvoiceListRowPresentation {
    static func title(for invoice: Invoice) -> String {
        let number = invoice.invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return number.isEmpty ? "Untitled Invoice" : number
    }

    static func subtitle(for invoice: Invoice) -> String {
        let trimmedClient = invoice.clientName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let client = trimmedClient.isEmpty ? "No Client" : trimmedClient
        let status = AppConstants.invoiceStatusDisplayName(for: invoice.effectiveStatus.rawValue)
        let currencyCode = InvoiceCurrencyCode.normalizedOrDefault(invoice.currencyCode)
        let amount = invoice.totalAmount.formatted(.currency(code: currencyCode))
        return "\(client) · \(status) · \(amount)"
    }
}

struct InvoicePersistenceQuerySpec: Equatable {
    let statuses: Set<String>
    let filterStartDate: Date
    let filterEndDate: Date
    let minimumAmount: Double
    let maximumAmount: Double
    let sortField: SortField
    let sortDirection: SortDirection
}

struct InvoicePersistenceMembershipSpec: Equatable {
    let statuses: Set<String>
    let filterStartDate: Date
    let filterEndDate: Date
    let minimumAmount: Double
    let maximumAmount: Double
}

extension InvoicePersistenceQuerySpec {
    var membershipSpec: InvoicePersistenceMembershipSpec {
        InvoicePersistenceMembershipSpec(
            statuses: statuses,
            filterStartDate: filterStartDate,
            filterEndDate: filterEndDate,
            minimumAmount: minimumAmount,
            maximumAmount: maximumAmount
        )
    }
}

enum InvoicesProjectionPublicationPolicy {
    /// Existing rows are complete for search, client, grouping, and sort changes. Status, date,
    /// and amount changes require a successful persistence fetch before reprojection; otherwise
    /// an already-filtered row set can produce false empty or incomplete results.
    static func canProject(
        currentSpec: InvoicePersistenceQuerySpec,
        loadedSpec: InvoicePersistenceQuerySpec?
    ) -> Bool {
        loadedSpec?.membershipSpec == currentSpec.membershipSpec
    }
}

struct InvoicePersistenceQuery {
    let predicate: Predicate<Invoice>
    let sortDescriptors: [SortDescriptor<Invoice>]
}

enum InvoicesListQueryEngine {
    private static let querySignpostLog = OSLog(subsystem: "com.invoicingapplication.app", category: "invoice-query")

    static func buildPersistenceQuerySpec(from spec: InvoicesListQuerySpec) -> InvoicePersistenceQuerySpec {
        let calendar = Calendar.current
        let dateBounds = orderedBounds(spec.filterStartDate, spec.filterEndDate)
        let amountBounds = orderedAmountBounds(spec.minimumAmount, spec.maximumAmount)
        let filterStartDate = dateBounds.lower.flatMap { calendar.startOfDay(for: $0) } ?? .distantPast
        let filterEndDate = dateBounds.upper.flatMap {
            calendar.date(bySettingHour: 23, minute: 59, second: 59, of: $0)
            ?? calendar.date(byAdding: DateComponents(day: 1, second: -1), to: $0)
            ?? $0
        } ?? .distantFuture
        let minimumAmount = amountBounds.lower ?? -Double.infinity
        let maximumAmount = amountBounds.upper ?? Double.infinity
        let activeStatuses = spec.statuses.isEmpty ? Set(AppConstants.invoiceStatusOptions) : spec.statuses
        return InvoicePersistenceQuerySpec(
            statuses: activeStatuses,
            filterStartDate: filterStartDate,
            filterEndDate: filterEndDate,
            minimumAmount: minimumAmount,
            maximumAmount: maximumAmount,
            sortField: spec.sortField,
            sortDirection: spec.sortDirection
        )
    }

    static func buildPersistenceQuery(from spec: InvoicesListQuerySpec) -> InvoicePersistenceQuery {
        let persistenceSpec = buildPersistenceQuerySpec(from: spec)
        let statusFilterActive = !spec.statuses.isEmpty
        let statusValues = persistenceSpec.statuses
        let startDate = persistenceSpec.filterStartDate
        let endDate = persistenceSpec.filterEndDate
        let minimumAmount = persistenceSpec.minimumAmount
        let maximumAmount = persistenceSpec.maximumAmount

        // Apply only the most stable, macro-safe constraints at the persistence layer.
        // Search remains in-memory so fuzzy matching stays source-of-truth at the view layer.
        let predicate = #Predicate<Invoice> { invoice in
            invoice.totalAmount >= minimumAmount &&
            invoice.totalAmount <= maximumAmount &&
            invoice.date >= startDate &&
            invoice.date <= endDate &&
            (!statusFilterActive || statusValues.contains(invoice.statusToken))
        }

        let sortDescriptors: [SortDescriptor<Invoice>] = switch persistenceSpec.sortField {
        case .date:
            [SortDescriptor(\.date, order: persistenceSpec.sortDirection == .ascending ? .forward : .reverse)]
        case .dueDate:
            [SortDescriptor(\.dueDate, order: persistenceSpec.sortDirection == .ascending ? .forward : .reverse)]
        case .amount:
            [SortDescriptor(\.totalAmount, order: persistenceSpec.sortDirection == .ascending ? .forward : .reverse)]
        case .clientName:
            [SortDescriptor(\.clientName, order: persistenceSpec.sortDirection == .ascending ? .forward : .reverse)]
        case .invoiceNumber:
            [SortDescriptor(\.invoiceNumber, order: persistenceSpec.sortDirection == .ascending ? .forward : .reverse)]
        }

        return InvoicePersistenceQuery(predicate: predicate, sortDescriptors: sortDescriptors)
    }

    static func buildPersistenceDescriptor(from spec: InvoicesListQuerySpec) -> FetchDescriptor<Invoice> {
        let persistenceQuery = buildPersistenceQuery(from: spec)
        return FetchDescriptor(
            predicate: persistenceQuery.predicate,
            sortBy: persistenceQuery.sortDescriptors
        )
    }

    static func project(invoices: [Invoice], spec: InvoicesListQuerySpec) -> InvoicesListProjection {
        #if DEBUG
        let signpostID = OSSignpostID(log: querySignpostLog)
        os_signpost(.begin, log: querySignpostLog, name: "InvoicesListQuery", signpostID: signpostID, "%{public}d rows", invoices.count)
        #endif

        let availableClientNames = Array(
            Set(
                invoices
                    .compactMap(\.clientName)
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()

        let filteredInvoices = sort(
            applyFilters(to: invoices, spec: spec),
            spec: spec
        )
        let groupedInvoices = group(filteredInvoices, by: spec.groupBy)

        let projection = InvoicesListProjection(
            filteredInvoices: filteredInvoices,
            groupedInvoices: groupedInvoices,
            treeItems: makeTreeItems(from: filteredInvoices, groupedInvoices: groupedInvoices, groupBy: spec.groupBy),
            availableClientNames: availableClientNames
        )

        #if DEBUG
        os_signpost(.end, log: querySignpostLog, name: "InvoicesListQuery", signpostID: signpostID, "%{public}d filtered", projection.filteredInvoices.count)
        #endif
        return projection
    }

    private static func applyFilters(to invoices: [Invoice], spec: InvoicesListQuerySpec) -> [Invoice] {
        var filtered = invoices
        let calendar = Calendar.current
        let statusFilter = spec.statuses.isEmpty ? Set(AppConstants.invoiceStatusOptions) : spec.statuses
        let dateBounds = orderedBounds(spec.filterStartDate, spec.filterEndDate)
        let amountBounds = orderedAmountBounds(spec.minimumAmount, spec.maximumAmount)

        filtered = filtered.filter { invoice in
            statusFilter.contains(invoice.effectiveStatus.rawValue)
        }

        if let filterStartDate = dateBounds.lower {
            let startDate = calendar.startOfDay(for: filterStartDate)
            filtered = filtered.filter { $0.date >= startDate }
        }

        if let filterEndDate = dateBounds.upper {
            let endDate = calendar.date(
                bySettingHour: 23,
                minute: 59,
                second: 59,
                of: filterEndDate
            ) ?? calendar.date(byAdding: DateComponents(day: 1, second: -1), to: filterEndDate) ?? filterEndDate
            filtered = filtered.filter { $0.date <= endDate }
        }

        if let minimumAmount = amountBounds.lower {
            filtered = filtered.filter { $0.totalAmount >= minimumAmount }
        }

        if let maximumAmount = amountBounds.upper {
            filtered = filtered.filter { $0.totalAmount <= maximumAmount }
        }

        if !spec.clientNames.isEmpty {
            filtered = filtered.filter { spec.clientNames.contains($0.clientName ?? "") }
        }

        let searchQuery = spec.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !searchQuery.isEmpty {
            let normalizedQuery = searchQuery.localizedLowercase
            filtered = filtered.filter { invoice in
                let haystack = [
                    invoice.invoiceNumber,
                    invoice.clientName ?? "",
                    invoice.billToName ?? "",
                    invoice.billToEmail ?? "",
                    invoice.notes ?? ""
                ]
                .joined(separator: " | ")
                .localizedLowercase
                return haystack.localizedStandardContains(normalizedQuery)
            }
        }

        return filtered
    }

    private static func orderedBounds<Value: Comparable>(
        _ first: Value?,
        _ second: Value?
    ) -> (lower: Value?, upper: Value?) {
        guard let first, let second, first > second else {
            return (first, second)
        }
        return (second, first)
    }

    private static func orderedAmountBounds(
        _ first: Double?,
        _ second: Double?
    ) -> (lower: Double?, upper: Double?) {
        orderedBounds(normalizedAmount(first), normalizedAmount(second))
    }

    private static func normalizedAmount(_ value: Double?) -> Double? {
        value.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }

    private static func sort(_ invoices: [Invoice], spec: InvoicesListQuerySpec) -> [Invoice] {
        invoices.sorted { first, second in
            switch spec.sortField {
            case .date:
                return compare(first.date, second.date, direction: spec.sortDirection, firstID: first.id, secondID: second.id)
            case .dueDate:
                return compare(first.dueDate ?? .distantPast, second.dueDate ?? .distantPast, direction: spec.sortDirection, firstID: first.id, secondID: second.id)
            case .amount:
                return compare(first.totalAmount, second.totalAmount, direction: spec.sortDirection, firstID: first.id, secondID: second.id)
            case .clientName:
                return compareLocalized(
                    first.clientName ?? "",
                    second.clientName ?? "",
                    direction: spec.sortDirection,
                    firstID: first.id,
                    secondID: second.id
                )
            case .invoiceNumber:
                return compareLocalized(
                    first.invoiceNumber,
                    second.invoiceNumber,
                    direction: spec.sortDirection,
                    firstID: first.id,
                    secondID: second.id
                )
            }
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private static func group(_ invoices: [Invoice], by groupBy: GroupBy) -> [String: [Invoice]] {
        let calendar = Calendar.current

        return Dictionary(grouping: invoices) { invoice in
            switch groupBy {
            case .status:
                return AppConstants.invoiceStatusDisplayName(for: invoice.effectiveStatus.rawValue)
            case .client:
                return invoice.clientName ?? "No Client"
            case .month:
                return monthFormatter.string(from: invoice.date)
            case .quarter:
                let month = calendar.component(.month, from: invoice.date)
                let year = calendar.component(.year, from: invoice.date)
                let quarter = (month - 1) / 3 + 1
                return "Q\(quarter) \(year)"
            case .none:
                return "All Invoices"
            }
        }
    }

    private static func makeTreeItems(from filteredInvoices: [Invoice], groupedInvoices: [String: [Invoice]], groupBy: GroupBy) -> [TreeItem] {
        if groupBy == .none {
            return filteredInvoices.map(makeInvoiceTreeItem)
        }

        let sortedGroups = sortedGroups(groupedInvoices, by: groupBy)
        if sortedGroups.count == 1,
           let (_, invoicesInGroup) = sortedGroups.first,
           invoicesInGroup.count <= 5 {
            return invoicesInGroup.map(makeInvoiceTreeItem)
        }

        return sortedGroups.map { key, invoicesInGroup in
            TreeItem(
                id: "section_\(key)",
                title: key,
                subtitle: "\(invoicesInGroup.count) \(invoicesInGroup.count == 1 ? "invoice" : "invoices")",
                children: invoicesInGroup.map(makeInvoiceTreeItem)
            )
        }
    }

    private static func sortedGroups(
        _ groupedInvoices: [String: [Invoice]],
        by groupBy: GroupBy
    ) -> [(key: String, value: [Invoice])] {
        let statusRanks = Dictionary(
            uniqueKeysWithValues: AppConstants.invoiceStatusOptions.enumerated().map { index, status in
                (AppConstants.invoiceStatusDisplayName(for: status), index)
            }
        )

        return groupedInvoices.sorted { lhs, rhs in
            switch groupBy {
            case .status:
                let lhsRank = statusRanks[lhs.key] ?? Int.max
                let rhsRank = statusRanks[rhs.key] ?? Int.max
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                return localizedGroupNamePrecedes(lhs.key, rhs.key)
            case .client:
                return localizedGroupNamePrecedes(lhs.key, rhs.key)
            case .month, .quarter:
                let lhsDate = lhs.value.map(\.date).max() ?? .distantPast
                let rhsDate = rhs.value.map(\.date).max() ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return localizedGroupNamePrecedes(lhs.key, rhs.key)
            case .none:
                return localizedGroupNamePrecedes(lhs.key, rhs.key)
            }
        }
    }

    private static func localizedGroupNamePrecedes(_ lhs: String, _ rhs: String) -> Bool {
        let comparison = lhs.localizedStandardCompare(rhs)
        if comparison == .orderedSame {
            return lhs < rhs
        }
        return comparison == .orderedAscending
    }

    private static func makeInvoiceTreeItem(_ invoice: Invoice) -> TreeItem {
        TreeItem(
            id: "invoice_\(invoice.id)",
            title: InvoiceListRowPresentation.title(for: invoice),
            subtitle: InvoiceListRowPresentation.subtitle(for: invoice),
            children: nil,
            entityID: invoice.id.uuidString,
            entityType: "invoice",
            entityState: invoice.effectiveStatus.rawValue
        )
    }

    private static func compare<T: Comparable>(
        _ lhs: T,
        _ rhs: T,
        direction: SortDirection,
        firstID: UUID,
        secondID: UUID
    ) -> Bool {
        if lhs == rhs {
            return firstID.uuidString < secondID.uuidString
        }
        switch direction {
        case .ascending:
            return lhs < rhs
        case .descending:
            return lhs > rhs
        }
    }

    private static func compareLocalized(
        _ lhs: String,
        _ rhs: String,
        direction: SortDirection,
        firstID: UUID,
        secondID: UUID
    ) -> Bool {
        let comparison = lhs.localizedStandardCompare(rhs)
        if comparison == .orderedSame {
            return firstID.uuidString < secondID.uuidString
        }
        return direction == .ascending
            ? comparison == .orderedAscending
            : comparison == .orderedDescending
    }
}
