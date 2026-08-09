// swift-tools-version:5.9

import SwiftUI
import SwiftData
import Core
import PersistenceModels
import Data
import DataInterfaces
import SharedUI
import Observation
import InvoiceTableLayoutEditor

// The data race warnings below are false positives for main-thread UI state usage.

public struct InvoiceFilterTag: Identifiable, Equatable, Sendable {
    public enum FilterCategory: String, Hashable, Equatable, Sendable {
        case search
        case status
        case date
        case amount
        case client
    }
    public var id: FilterCategory
    public var label: String

    public init(id: FilterCategory, label: String) {
        self.id = id
        self.label = label
    }
}

// MARK: - GroupBy Enum
enum GroupBy: String, CaseIterable, Identifiable, Sendable {
    case none = "None"
    case status = "Status"
    case client = "Client"
    case month = "Month"
    case quarter = "Quarter"
    var id: String { self.rawValue }
}

enum InvoicesFeatureError: LocalizedError, Equatable {
    case createdInvoiceUnavailable
    case creationAlreadyInProgress
    case currentInvoiceCouldNotBePrepared

    var errorDescription: String? {
        switch self {
        case .createdInvoiceUnavailable:
            "Created invoice could not be loaded from the store."
        case .creationAlreadyInProgress:
            "Another invoice is already being created."
        case .currentInvoiceCouldNotBePrepared:
            "Current invoice could not be saved. Fix its errors before creating another invoice."
        }
    }
}

enum InvoiceCreationPhase: Equatable {
    case idle
    case preparing
    case savingCurrentInvoice
    case creating

    var isActive: Bool { self != .idle }

    var progressTitle: String {
        switch self {
        case .idle: "New Invoice"
        case .preparing: "Preparing…"
        case .savingCurrentInvoice: "Saving current invoice…"
        case .creating: "Creating invoice…"
        }
    }
}

@Observable
@MainActor
public class InvoicesContainerViewModel {
    // MARK: - Dependencies
    let modelContext: ModelContext
    var modelContainer: ModelContainer { modelContext.container }
    public let editorSession: InvoiceEditorSession
    let persistenceCommands: InvoicesPersistenceCommands
    let listFetcher: any InvoiceListFetching
    private let invoiceCreationPreparation: @MainActor () async -> Bool

    // MARK: - List State
    public var dataRevision: Int = 0
    var listContentRevision: Int = 0
    public var selectedInvoice: Invoice?
    public internal(set) var analyticsSummary: RevenueAnalyticsSummary = RevenueAnalyticsSummary(currencySummaries: [], totalDraftCount: 0, totalInvoiceCount: 0)
    public var isLoading: Bool = false
    public var listLoadError: String? = nil
    var hasCompletedSuccessfulListLoad = false
    var lastSuccessfulPersistenceSpec: InvoicePersistenceQuerySpec?
    public private(set) var actionErrorMessage: String? = nil
    public var totalInvoiceCount: Int = 0
    private(set) var invoiceCreationPhase = InvoiceCreationPhase.idle
    public var isCreatingInvoice: Bool { invoiceCreationPhase.isActive }
    public var invoiceSearchText: String = ""
    var invoiceFilterStatus: Set<String> = []
    var invoiceSortOrder: InvoicesSortOrder = .dateDesc
    var groupBy: GroupBy = .none

    var sortField: SortField = .date {
        didSet { updateSortOrder() }
    }
    var sortDirection: SortDirection = .descending {
        didSet { updateSortOrder() }
    }

    var invoiceEntities: [Invoice] = []
    var loadedInvoicesByID: [UUID: Invoice] = [:]
    private var listLoadRequestID = UUID()

    var filterStartDate: Date? = nil
    var filterEndDate: Date? = nil
    var filterMinAmount: Double? = nil
    var filterMaxAmount: Double? = nil
    var filterClients: Set<String> = []
    private(set) var filterInputResetRevision = 0

    var isDateFilterActive: Bool {
        filterStartDate != nil || filterEndDate != nil
    }
    var isAmountFilterActive: Bool {
        filterMinAmount != nil || filterMaxAmount != nil
    }
    var isClientFilterActive: Bool {
        !filterClients.isEmpty
    }

    var hasActiveListFilters: Bool {
        !invoiceSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (!invoiceFilterStatus.isEmpty
                && invoiceFilterStatus.count < AppConstants.invoiceStatusOptions.count)
            || isDateFilterActive
            || isAmountFilterActive
            || isClientFilterActive
    }

    public var activeFilterDescriptions: [String] {
        var descriptions: [String] = []
        let trimmedSearch = invoiceSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            descriptions.append("Search \"\(trimmedSearch)\"")
        }
        if !invoiceFilterStatus.isEmpty && invoiceFilterStatus.count < AppConstants.invoiceStatusOptions.count {
            let statusNames = invoiceFilterStatus.sorted().map { raw in
                InvoiceStatus(rawValue: raw)?.displayName ?? raw.capitalized
            }
            descriptions.append("Status: \(statusNames.joined(separator: ", "))")
        }
        if let startDate = filterStartDate, let endDate = filterEndDate {
            descriptions.append("Date: \(startDate.formatted(date: .numeric, time: .omitted)) – \(endDate.formatted(date: .numeric, time: .omitted))")
        } else if let startDate = filterStartDate {
            descriptions.append("From \(startDate.formatted(date: .numeric, time: .omitted))")
        } else if let endDate = filterEndDate {
            descriptions.append("Until \(endDate.formatted(date: .numeric, time: .omitted))")
        }
        if let minAmount = filterMinAmount, let maxAmount = filterMaxAmount {
            descriptions.append("Amount: \(Self.formatAmountFilterValue(minAmount)) – \(Self.formatAmountFilterValue(maxAmount))")
        } else if let minAmount = filterMinAmount {
            descriptions.append("Min Amount: \(Self.formatAmountFilterValue(minAmount))")
        } else if let maxAmount = filterMaxAmount {
            descriptions.append("Max Amount: \(Self.formatAmountFilterValue(maxAmount))")
        }
        if !filterClients.isEmpty {
            descriptions.append("Client: \(filterClients.sorted().joined(separator: ", "))")
        }
        return descriptions
    }

    public var activeFilterTags: [InvoiceFilterTag] {
        var tags: [InvoiceFilterTag] = []
        let trimmedSearch = invoiceSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            tags.append(InvoiceFilterTag(id: .search, label: "Search: \"\(trimmedSearch)\""))
        }
        if !invoiceFilterStatus.isEmpty && invoiceFilterStatus.count < AppConstants.invoiceStatusOptions.count {
            let statusNames = invoiceFilterStatus.sorted().map { raw in
                InvoiceStatus(rawValue: raw)?.displayName ?? raw.capitalized
            }
            tags.append(InvoiceFilterTag(id: .status, label: "Status: \(statusNames.joined(separator: ", "))"))
        }
        if let startDate = filterStartDate, let endDate = filterEndDate {
            tags.append(InvoiceFilterTag(id: .date, label: "Date: \(startDate.formatted(date: .numeric, time: .omitted)) – \(endDate.formatted(date: .numeric, time: .omitted))"))
        } else if let startDate = filterStartDate {
            tags.append(InvoiceFilterTag(id: .date, label: "From \(startDate.formatted(date: .numeric, time: .omitted))"))
        } else if let endDate = filterEndDate {
            tags.append(InvoiceFilterTag(id: .date, label: "Until \(endDate.formatted(date: .numeric, time: .omitted))"))
        }
        if let minAmount = filterMinAmount, let maxAmount = filterMaxAmount {
            tags.append(InvoiceFilterTag(id: .amount, label: "Amount: \(Self.formatAmountFilterValue(minAmount)) – \(Self.formatAmountFilterValue(maxAmount))"))
        } else if let minAmount = filterMinAmount {
            tags.append(InvoiceFilterTag(id: .amount, label: "Min Amount: \(Self.formatAmountFilterValue(minAmount))"))
        } else if let maxAmount = filterMaxAmount {
            tags.append(InvoiceFilterTag(id: .amount, label: "Max Amount: \(Self.formatAmountFilterValue(maxAmount))"))
        }
        if !filterClients.isEmpty {
            tags.append(InvoiceFilterTag(id: .client, label: "Client: \(filterClients.sorted().joined(separator: ", "))"))
        }
        return tags
    }

    public var activeFilterSummaryText: String {
        let descriptions = activeFilterDescriptions
        guard !descriptions.isEmpty else { return "" }
        return "Active filters: " + descriptions.joined(separator: " • ")
    }

    var canProjectCurrentListSpec: Bool {
        InvoicesProjectionPublicationPolicy.canProject(
            currentSpec: InvoicesListQueryEngine.buildPersistenceQuerySpec(from: listQuerySpec),
            loadedSpec: lastSuccessfulPersistenceSpec
        )
    }

    var isShowingPreviousQueryResults: Bool {
        hasCompletedSuccessfulListLoad && !canProjectCurrentListSpec
    }

    public func clearListFilters() {
        invoiceSearchText = ""
        invoiceFilterStatus.removeAll()
        filterStartDate = nil
        filterEndDate = nil
        filterMinAmount = nil
        filterMaxAmount = nil
        filterClients.removeAll()
        filterInputResetRevision &+= 1
    }

    public func clearFilter(category: InvoiceFilterTag.FilterCategory) {
        switch category {
        case .search:
            invoiceSearchText = ""
        case .status:
            invoiceFilterStatus.removeAll()
        case .date:
            filterStartDate = nil
            filterEndDate = nil
        case .amount:
            filterMinAmount = nil
            filterMaxAmount = nil
        case .client:
            filterClients.removeAll()
        }
        filterInputResetRevision &+= 1
    }

    public func clearSearchFilter() {
        clearFilter(category: .search)
    }

    public func clearStatusFilters() {
        clearFilter(category: .status)
    }

    public func clearDateFilters() {
        clearFilter(category: .date)
    }

    public func clearClientFilters() {
        clearFilter(category: .client)
    }

    public func clearAmountFilters() {
        filterMinAmount = nil
        filterMaxAmount = nil
        filterInputResetRevision &+= 1
    }

    public func reportActionError(_ message: String) {
        actionErrorMessage = message
    }

    public func dismissActionError() {
        actionErrorMessage = nil
    }

    func updateFilterStartDate(_ date: Date?) {
        filterStartDate = date
        if let date, let endDate = filterEndDate, endDate < date {
            filterEndDate = date
        }
    }

    func updateFilterEndDate(_ date: Date?) {
        filterEndDate = date
        if let date, let startDate = filterStartDate, startDate > date {
            filterStartDate = date
        }
    }

    func updateFilterMinimumAmount(_ amount: Double?) {
        let normalizedAmount = normalizedFilterAmount(amount)
        filterMinAmount = normalizedAmount
        if let normalizedAmount, let maximum = filterMaxAmount, maximum < normalizedAmount {
            filterMaxAmount = normalizedAmount
        }
    }

    func updateFilterMaximumAmount(_ amount: Double?) {
        let normalizedAmount = normalizedFilterAmount(amount)
        filterMaxAmount = normalizedAmount
        if let normalizedAmount, let minimum = filterMinAmount, minimum > normalizedAmount {
            filterMinAmount = normalizedAmount
        }
    }

    private func normalizedFilterAmount(_ amount: Double?) -> Double? {
        amount.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }

    /// Currency-neutral amount labels for mixed-currency invoice lists.
    private static func formatAmountFilterValue(_ amount: Double) -> String {
        CurrencyFormatting.editableAmount(amount)
    }

    func beginListLoad() -> UUID {
        let requestID = UUID()
        listLoadRequestID = requestID
        isLoading = true
        return requestID
    }

    func finishListLoad(_ requestID: UUID) {
        guard listLoadRequestID == requestID else { return }
        isLoading = false
    }

    func isCurrentListLoad(_ requestID: UUID) -> Bool {
        listLoadRequestID == requestID
    }

    func invalidateListLoad() {
        listLoadRequestID = UUID()
        isLoading = false
    }

    func beginInvoiceCreation() throws {
        guard !isCreatingInvoice else {
            throw InvoicesFeatureError.creationAlreadyInProgress
        }
        invoiceCreationPhase = .preparing
    }

    func finishInvoiceCreation() {
        invoiceCreationPhase = .idle
    }

    func prepareCurrentInvoiceForCreation() async throws {
        invoiceCreationPhase = editorSession.hasUnsavedChanges ? .savingCurrentInvoice : .creating
        guard await invoiceCreationPreparation() else {
            throw InvoicesFeatureError.currentInvoiceCouldNotBePrepared
        }
        invoiceCreationPhase = .creating
    }

    // MARK: - Initializer
    public init(
        modelContext: ModelContext,
        listFetcher: (any InvoiceListFetching)? = nil,
        storeChangeMonitor: (any StoreChangeMonitoring)? = nil,
        invoiceCreationPreparation: (@MainActor () async -> Bool)? = nil
    ) {
        self.modelContext = modelContext
        let editorSession = InvoiceEditorSession(modelContainer: modelContext.container)
        self.editorSession = editorSession
        self.persistenceCommands = InvoicesPersistenceCommands(modelContext: modelContext)
        self.listFetcher = listFetcher ?? InvoiceListFetchActor(modelContainer: modelContext.container)
        self.invoiceCreationPreparation = invoiceCreationPreparation ?? {
            await editorSession.prepareForInvoiceCreation()
        }
        StoreChangeMonitoringSubscription.subscribe(monitor: storeChangeMonitor) { [weak self] revision in
            self?.handleStoreRevision(revision)
        }
        editorSession.setMutationHandler { [weak self] mutation in
            Task { @MainActor [weak self] in
                await self?.reconcileEditorMutation(mutation)
            }
        }
    }

    func updateSortOrder() {
        invoiceSortOrder = InvoicesSortOrder.from(field: sortField, direction: sortDirection)
    }

    /// Store revision means persistent history advanced (including CloudKit HistoryExpired).
    /// Drop live Invoice / InvoiceItem refs before reload so UI cannot touch invalidated backing data.
    func handleStoreRevision(_ revision: Int) {
        guard revision != dataRevision else { return }
        dataRevision = revision
        invalidateLiveListModelsForStoreChange()
    }

    private func invalidateLiveListModelsForStoreChange() {
        guard !invoiceEntities.isEmpty || selectedInvoice != nil || !loadedInvoicesByID.isEmpty else {
            return
        }
        invoiceEntities = []
        loadedInvoicesByID = [:]
        applySelection(nil)
        analyticsSummary = InvoiceAnalyticsEngine.calculateSummary(from: [])
        listContentRevision &+= 1
        isLoading = true
    }
}

@MainActor
struct InvoicesPersistenceCommands {
    let modelContext: ModelContext

    func fetchInvoice(matching descriptor: FetchDescriptor<Invoice>) throws -> Invoice? {
        try modelContext.fetch(descriptor).first
    }

    func fetchInvoices(ids: [UUID]) throws -> [Invoice] {
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { ids.contains($0.id) }
        )
        let fetched = try modelContext.fetch(descriptor)
        let byID = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        return ids.compactMap { byID[$0] }
    }

    func deleteInvoices(_ invoices: [Invoice]) throws {
        do {
            for invoice in invoices {
                modelContext.delete(invoice)
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}

public protocol InvoiceListFetching: Sendable {
    func invoiceIDs(matching descriptor: FetchDescriptor<Invoice>) async throws -> [UUID]
    func totalInvoiceCount() async throws -> Int
}

@ModelActor
public actor InvoiceListFetchActor: InvoiceListFetching {
    public func invoiceIDs(matching descriptor: FetchDescriptor<Invoice>) async throws -> [UUID] {
        try modelContext.fetch(descriptor).map(\.id)
    }

    public func totalInvoiceCount() async throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<Invoice>())
    }
}
