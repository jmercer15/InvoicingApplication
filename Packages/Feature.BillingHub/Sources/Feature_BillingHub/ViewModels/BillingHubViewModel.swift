import Foundation
import SwiftUI
import CoreLocation
import Combine
import AppKit
import CoreText
import os
import Core
import Data

/// Result of a session or invoice movement operation
public enum MoveResult: Error, Equatable {
    case success
    case invalidTransition(from: String, to: String)
    case clientMismatch
    case notFound
    
    /// Whether the operation was successful
    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    /// User-facing description of the result
    public var description: String {
        switch self {
        case .success:
            return "Item moved successfully"
        case .invalidTransition(let from, let to):
            return "Cannot move from '\(from)' to '\(to)'"
        case .clientMismatch:
            return "Sessions must belong to the same client"
        case .notFound:
            return "Item not found"
        }
    }
    
}

public struct SupportLogDraft: Sendable {
    public var participantName: String
    public var participantNdisNumber: String
    public var supportItemNumber: String
    public var serviceDescription: String
    public var location: String
    public var deliveredFrom: Date
    public var deliveredTo: Date
    public var quantityHours: Double
    public var deliveredBy: String
    public var attestedBy: String
    public var attestedAt: Date
    public var signatureMethod: String?
    public var signedBy: String?
    public var signedAt: Date?
    public var cancellationReasonCode: String?
    public var notes: String?

    public init(
        participantName: String = "",
        participantNdisNumber: String = "",
        supportItemNumber: String = "",
        serviceDescription: String = "",
        location: String = "",
        deliveredFrom: Date = Date(),
        deliveredTo: Date = Date().addingTimeInterval(3600),
        quantityHours: Double = 1.0,
        deliveredBy: String = "",
        attestedBy: String = "",
        attestedAt: Date = Date(),
        signatureMethod: String? = SignatureMethod.attestation.rawValue,
        signedBy: String? = nil,
        signedAt: Date? = nil,
        cancellationReasonCode: String? = nil,
        notes: String? = nil
    ) {
        self.participantName = participantName
        self.participantNdisNumber = participantNdisNumber
        self.supportItemNumber = supportItemNumber
        self.serviceDescription = serviceDescription
        self.location = location
        self.deliveredFrom = deliveredFrom
        self.deliveredTo = deliveredTo
        self.quantityHours = quantityHours
        self.deliveredBy = deliveredBy
        self.attestedBy = attestedBy
        self.attestedAt = attestedAt
        self.signatureMethod = signatureMethod
        self.signedBy = signedBy
        self.signedAt = signedAt
        self.cancellationReasonCode = cancellationReasonCode
        self.notes = notes
    }
}

@MainActor
public class BillingHubViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var searchText: String = ""
    @Published var selectedClientID: UUID? = nil
    @Published var isLoading: Bool = false
    @Published private(set) var bulkActionFeedback: String?
    @Published var sortOptions: [KanbanCardData.BillingColumnType: ColumnSortOption] = [:]

    // Cached properties for sessions, invoices, and clients (domain models)
    @Published private var _allSessions: [Session] = []
    @Published private var _allInvoices: [Invoice] = []
    @Published private var _allClients: [Client] = []
    // Client services keyed by clientId for fast travel rate lookups
    private var _clientServicesCache: [UUID: [ClientService]] = [:]

    // MARK: - Dependencies
    private let sessionsRepository: SessionsRepository
    private let invoicesRepository: InvoicesRepository
    private let clientsRepository: ClientsRepository
    private let clientServicesRepository: ClientServicesRepository
    private let travelChargeRepository: TravelChargeRepository
    private let ndisBillingIntegrationService: NDISBillingIntegrationService
    private let complianceValidator: NDISComplianceValidator?
    private let supportLogRepository: SupportLogRepository?
    private let complianceBlockingEnabled: Bool
    private let userDefaults: UserDefaults
    private let complianceLogger = Logger(subsystem: "com.invoicing.compliance", category: "BillingHub")
    private let invoiceStatusSequence: [String] = [
        BillingStatus.reviewDrafts.rawValue,
        BillingStatus.readyToSend.rawValue,
        BillingStatus.pending.rawValue,
        "overdue",
        BillingStatus.received.rawValue
    ]
    private static let invoiceOrderStorageKey = "Feature.BillingHub.InvoiceOrderByStatus.v1"
    private static let complianceBlockerDowngradeKey = "debug.compliance.downgradeBlockersToWarnings"
    private var invoiceOrderByStatus: [String: [UUID]] = [:]
    private var emailSharingService: NSSharingService?
    
    // MARK: - Computed Properties
    
    /// All sessions grouped by billing status, mapped to KanbanCardData
    var sessionsByStatus: [KanbanCardData.BillingColumnType: [KanbanCardData]] {
        // Map filtered sessions to KanbanCardData once
        let filteredSessions = filteredSessions()
        let kanbanCards = filteredSessions.compactMap(mapSessionToKanbanCard)

        // Group by columnType
        var dict = Dictionary(grouping: kanbanCards, by: { $0.columnType })

        // Apply per-column sorting
        for (column, cards) in dict {
            if column == .grouped {
                // Grouped column uses manual position ordering
                var groupedCards = cards
                var positions: [UUID: Int32] = [:]
                for session in _allSessions where canonicalSessionStatusToken(session.status) == "grouped" {
                    positions[session.id] = session.groupedPosition
                }
                groupedCards.sort { lhs, rhs in
                    let leftPosition: Int32 = {
                        if case .session(let data) = lhs { return positions[data.sessionId] ?? Int32.max }
                        return Int32.max
                    }()
                    let rightPosition: Int32 = {
                        if case .session(let data) = rhs { return positions[data.sessionId] ?? Int32.max }
                        return Int32.max
                    }()
                    return leftPosition < rightPosition
                }
                dict[column] = groupedCards
            } else {
                // Apply user-selected sort option
                dict[column] = sortCards(cards, for: column)
            }
        }
        return dict
    }
    
    /// All invoices grouped by billing status, mapped to KanbanCardData
    var invoicesByStatus: [KanbanCardData.BillingColumnType: [KanbanCardData]] {
        let invoices = filteredInvoices()
        let kanbanCards = invoices.compactMap(mapInvoiceToKanbanCard)

        var dict = Dictionary(grouping: kanbanCards, by: { $0.columnType })
        
        // Apply per-column sorting
        for (column, cards) in dict {
            dict[column] = sortCards(cards, for: column)
        }
        
        return dict
    }
    
    /// Invoice totals per column (for display in headers)
    var invoiceTotalsByColumn: [KanbanCardData.BillingColumnType: Decimal] {
        var totals: [KanbanCardData.BillingColumnType: Decimal] = [:]
        
        for invoice in filteredInvoices() {
            guard let column = invoiceStatusToColumn(invoice.status) else { continue }
            let amount = Decimal(invoice.totalAmount)
            totals[column, default: 0] += amount
        }
        
        return totals
    }
    
    /// Formatted total for a column (currency string)
    func formattedTotal(for column: KanbanCardData.BillingColumnType) -> String? {
        guard let total = invoiceTotalsByColumn[column], total > 0 else { return nil }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: total as NSDecimalNumber)
    }
    
    private func invoiceStatusToColumn(_ status: String?) -> KanbanCardData.BillingColumnType? {
        guard let status = canonicalInvoiceStatusToken(status) else { return nil }
        switch status {
        case BillingStatus.reviewDrafts.rawValue: return .reviewDrafts
        case BillingStatus.readyToSend.rawValue: return .readyToSend
        case BillingStatus.pending.rawValue, "overdue": return .pending
        case BillingStatus.received.rawValue: return .received
        default: return nil
        }
    }
    
    /// Grouped sessions organized by groupID for the grouped column
    var groupedSessions: [SessionGroup] {
        let filteredSessions = filteredSessions()
        let groupedSessions = filteredSessions.filter { canonicalSessionStatusToken($0.status) == "grouped" }
        let kanbanCards = groupedSessions.compactMap(mapSessionToKanbanCard)
        
        // Group sessions by their groupID
        let groupedByID = Dictionary(grouping: kanbanCards) { card in
            switch card {
            case .session(let data):
                // Find the original session to get its groupID
                return groupedSessions.first { $0.id == data.sessionId }?.groupID
            case .invoice:
                return UUID?.none
            }
        }
        
        // Convert to SessionGroup objects
        var groups: [SessionGroup] = []
        
        // Handle sessions with groupID (actual groups)
        for (groupID, sessions) in groupedByID {
            if let groupID = groupID {
                groups.append(SessionGroup(groupID: groupID, sessions: sessions))
            }
        }
        
        // Handle ungrouped sessions (sessions with nil groupID)
        if let ungroupedSessions = groupedByID[nil] {
            for session in ungroupedSessions {
                groups.append(SessionGroup(groupID: nil, sessions: [session]))
            }
        }
        
        let positionsBySessionID: [UUID: Int32] = Dictionary(
            uniqueKeysWithValues: groupedSessions.map { ($0.id, $0.groupedPosition) }
        )

        func sortPosition(for group: SessionGroup) -> Int32 {
            let sessionIDs = group.sessions.compactMap { card -> UUID? in
                guard case .session(let data) = card else { return nil }
                return data.sessionId
            }
            return sessionIDs.compactMap { positionsBySessionID[$0] }.min() ?? Int32.max
        }

        // Keep grouped scopes stable by persisted groupedPosition.
        return groups.sorted { lhs, rhs in
            let left = sortPosition(for: lhs)
            let right = sortPosition(for: rhs)
            if left == right {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return left < right
        }
    }

    /// Filtered sessions based on search and client selection, mapped to KanbanCardData
    var filteredSessionsCards: [KanbanCardData] {
        filteredSessions().compactMap(mapSessionToKanbanCard)
    }

    struct ClientSummary: Identifiable, Hashable {
        let id: UUID
        let name: String
        // colorHex property removed - using deterministic color system instead
    }

    var clientSummaries: [ClientSummary] {
        let clientNames = Dictionary(uniqueKeysWithValues: _allClients.map { ($0.id, $0.fullName) })
        let sessionClientIDs = _allSessions.compactMap(\.clientId)
        let invoiceClientIDs = _allInvoices.compactMap(\.clientId)
        let clientIDs = Set(sessionClientIDs + invoiceClientIDs)

        let summaries = clientIDs.map { clientID -> ClientSummary in
            let snapshotName = _allInvoices.first(where: { $0.clientId == clientID })?.clientName
            let resolvedName = clientNames[clientID] ?? snapshotName ?? "Client \(clientID.uuidString.prefix(8))"
            return ClientSummary(id: clientID, name: resolvedName)
        }

        return summaries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var selectedClientName: String? {
        guard let selectedClientID else { return nil }
        return clientSummaries.first(where: { $0.id == selectedClientID })?.name
    }

    var hasActiveFilters: Bool {
        !(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || selectedClientID != nil
    }

    var groupedDraftBatchCount: Int {
        groupedDraftBatches().count
    }

    var canBulkCreateDrafts: Bool {
        groupedDraftBatchCount > 0
    }

    var readyToSendCount: Int {
        filteredInvoices().reduce(into: 0) { count, invoice in
            if canonicalInvoiceStatusToken(invoice.status) == BillingStatus.readyToSend.rawValue {
                count += 1
            }
        }
    }

    var pendingPaymentCount: Int {
        filteredInvoices().reduce(into: 0) { count, invoice in
            let status = canonicalInvoiceStatusToken(invoice.status)
            if status == BillingStatus.pending.rawValue || status == "overdue" {
                count += 1
            }
        }
    }

    var canBulkSendReadyInvoices: Bool {
        readyToSendCount > 0
    }

    var canBulkCompletePendingInvoices: Bool {
        pendingPaymentCount > 0
    }

    var canUndoLastBulkAction: Bool {
        lastBulkUndoAction != nil
    }
    
    /// Find an invoice by ID from the cached invoices
    func invoice(byId id: UUID) -> Invoice? {
        _allInvoices.first { $0.id == id }
    }
    
    // MARK: - Initialization
    public init(
        sessionsRepository: SessionsRepository,
        invoicesRepository: InvoicesRepository,
        clientsRepository: ClientsRepository,
        clientServicesRepository: ClientServicesRepository,
        travelChargeRepository: TravelChargeRepository,
        ndisBillingIntegrationService: NDISBillingIntegrationService,
        complianceValidator: NDISComplianceValidator? = nil,
        supportLogRepository: SupportLogRepository? = nil,
        complianceBlockingEnabled: Bool = true,
        userDefaults: UserDefaults = .standard
    ) {
        self.sessionsRepository = sessionsRepository
        self.invoicesRepository = invoicesRepository
        self.clientsRepository = clientsRepository
        self.clientServicesRepository = clientServicesRepository
        self.travelChargeRepository = travelChargeRepository
        self.ndisBillingIntegrationService = ndisBillingIntegrationService
        self.complianceValidator = complianceValidator
        self.supportLogRepository = supportLogRepository
        self.complianceBlockingEnabled = complianceBlockingEnabled
        self.userDefaults = userDefaults
        self.invoiceOrderByStatus = Self.loadInvoiceOrder(from: userDefaults)
        
        // Subscribe to cross-feature invoice refresh notifications
        InvoiceChangePublisher.shared.invoicesRefreshNeeded
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        // Subscribe to cross-feature session refresh notifications
        SessionChangePublisher.shared.sessionsRefreshNeeded
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
        
        // Initial fetch when ViewModel is created
        refresh()
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var lastBulkUndoAction: BulkUndoAction?
    private var refreshTask: Task<Void, Never>?
    private var hasCompletedInitialFetch = false
    private var pendingRefreshAfterCurrent = false
    
    // MARK: - Sorting
    
    /// Sets the sort option for a specific column
    func setSortOption(_ option: ColumnSortOption, for column: KanbanCardData.BillingColumnType) {
        sortOptions[column] = option
        objectWillChange.send()
    }
    
    /// Gets the current sort option for a column (defaults to manual)
    func sortOption(for column: KanbanCardData.BillingColumnType) -> ColumnSortOption {
        sortOptions[column] ?? .manual
    }
    
    /// Sorts cards based on the column's sort option
    private func sortCards(_ cards: [KanbanCardData], for column: KanbanCardData.BillingColumnType) -> [KanbanCardData] {
        let option = sortOption(for: column)
        guard option != .manual else { return cards }
        
        return cards.sorted { lhs, rhs in
            switch option {
            case .manual:
                return false // Keep original order
                
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
    
    private func cardDate(_ card: KanbanCardData) -> Date {
        switch card {
        case .session(let data):
            return data.startTime ?? .distantPast
        case .invoice(let data):
            // Use rawDate if available for precision, otherwise parse string
            return data.rawDate ?? parseCardDate(data.date) ?? .distantPast
        }
    }
    
    private func cardClientName(_ card: KanbanCardData) -> String {
        switch card {
        case .session(let data):
            return data.clientName
        case .invoice(let data):
            return data.clientName
        }
    }
    
    private func cardAmount(_ card: KanbanCardData) -> Decimal {
        switch card {
        case .session:
            return 0 // Sessions don't have amounts
        case .invoice(let data):
            return parseAmount(data.amount) ?? 0
        }
    }
    
    private func parseCardDate(_ dateString: String) -> Date? {
        // Common date formats used in card display
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
    
    private func parseAmount(_ amountString: String) -> Decimal? {
        // Remove currency symbols and parse
        let cleaned = amountString
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned)
    }
    
    // MARK: - Public Methods
    
    /// Updates the billing status of a session
    func updateSessionStatus(_ sessionId: UUID, to status: KanbanCardData.BillingColumnType) async {
        guard let statusString = statusString(for: status) else { return }
        
        do {
            try await sessionsRepository.updateStatus(id: sessionId, status: statusString)
            await fetchData()
        } catch {
            print("❌ [BillingHubViewModel] Error updating session status: \(error)")
        }
    }
    
    /// Updates the billing status of an invoice.
    /// Note: repository rules also transition linked session statuses to keep workflow states aligned.
    func updateInvoiceStatus(_ invoiceId: UUID, to status: KanbanCardData.BillingColumnType) async {
        guard let targetStatus = invoiceStatusString(for: status) else { return }
        
        do {
            if let invoice = _allInvoices.first(where: { $0.id == invoiceId }) {
                let validation = await validateInvoiceTransitionIfNeeded(
                    invoice: invoice,
                    targetStatus: targetStatus,
                    action: .statusChange
                )
                if let validation, validation.isBlocked {
                    bulkActionFeedback = blockerSummary(for: validation)
                    return
                }
                if let validation, !validation.warnings.isEmpty {
                    bulkActionFeedback = warningSummary(for: validation)
                }
            }
            try await invoicesRepository.updateStatus(id: invoiceId, status: targetStatus)
            await fetchData()
            // Notify Invoice feature about the change
            InvoiceChangePublisher.shared.notifyChange(invoiceId: invoiceId)
        } catch {
            print("❌ [BillingHubViewModel] Error updating invoice status: \(error)")
        }
    }

    // MARK: - Unified Movement Methods
    
    /// Moves a session to a new column with validation.
    /// - Parameters:
    ///   - sessionID: The ID of the session to move
    ///   - column: The target column
    ///   - handleGrouping: Whether to automatically handle group cleanup (default: true)
    /// - Returns: A `MoveResult` indicating success or failure reason
    @discardableResult
    func moveSession(_ sessionID: UUID, to column: KanbanCardData.BillingColumnType, handleGrouping: Bool = true) async -> MoveResult {
        guard let session = await fetchSessionFromRepository(byID: sessionID) else {
            return .notFound
        }
        
        // Get current and target statuses
        guard let currentStatusRaw = canonicalSessionStatusToken(session.status),
              let currentStatus = BillingStatus(rawValue: currentStatusRaw),
              let targetStatus = columnToBillingStatus(column) else {
            return .invalidTransition(from: session.status ?? "unknown", to: column.rawValue)
        }
        
        // Validate transition
        guard BillingTransitionRules.isValidSessionTransition(from: currentStatus, to: targetStatus) else {
            return .invalidTransition(from: currentStatus.rawValue, to: targetStatus.rawValue)
        }
        
        // Handle grouping cleanup if moving out of grouped column
        let previousGroup = session.groupID
        let sourceWasInGroupedColumn = currentStatus == .grouped
        
        // Update status
        await updateSessionStatus(sessionID, to: column)
        
        // Handle group cleanup if requested
        if handleGrouping {
            if let previousGroup {
                try? await sessionsRepository.ungroupSessions([sessionID])
                await dissolveGroupIfSingleton(groupID: previousGroup)
                if column == .grouped {
                    await reindexGroupedScope(previousGroup)
                }
            }
            
            if column == .grouped {
                await reindexGroupedScope(nil)
            } else if sourceWasInGroupedColumn || previousGroup != nil {
                await reindexGroupedScope(previousGroup)
                await reindexGroupedScope(nil)
            }
        }
        
        objectWillChange.send()
        return .success
    }
    
    /// Moves an invoice to a new column with validation.
    /// Handles clearing of sentDate/paidDate on backward transitions.
    /// - Parameters:
    ///   - invoiceID: The ID of the invoice to move
    ///   - column: The target column
    /// - Returns: A `MoveResult` indicating success or failure reason
    @discardableResult
    func moveInvoice(_ invoiceID: UUID, to column: KanbanCardData.BillingColumnType) async -> MoveResult {
        guard var invoice = _allInvoices.first(where: { $0.id == invoiceID }) else {
            return .notFound
        }
        
        // Get current and target statuses
        guard let currentStatusRaw = canonicalInvoiceStatusToken(invoice.status),
              let currentStatus = invoiceRawToBillingStatus(currentStatusRaw),
              let targetStatus = columnToBillingStatus(column) else {
            return .invalidTransition(from: invoice.status, to: column.rawValue)
        }
        
        // Validate transition
        guard BillingTransitionRules.isValidInvoiceTransition(from: currentStatus, to: targetStatus) else {
            return .invalidTransition(from: currentStatus.rawValue, to: targetStatus.rawValue)
        }

        if let validation = await validateInvoiceTransitionIfNeeded(
            invoice: invoice,
            targetStatus: targetStatus.rawValue,
            action: .statusChange
        ) {
            if validation.isBlocked {
                bulkActionFeedback = blockerSummary(for: validation)
                return .invalidTransition(from: currentStatus.rawValue, to: targetStatus.rawValue)
            }
            if !validation.warnings.isEmpty {
                bulkActionFeedback = warningSummary(for: validation)
            }
        }
        
        // Determine if dates need to be cleared
        let dateClearing = BillingTransitionRules.requiresDateClearing(to: targetStatus)
        
        // Update invoice with cleared dates if needed
        if dateClearing.clearSentDate { invoice.sentDate = nil }
        if dateClearing.clearPaidDate { invoice.paidDate = nil }
        invoice.status = targetStatus.rawValue
        
        do {
            _ = try await invoicesRepository.update(invoice)
            await fetchData()
            InvoiceChangePublisher.shared.notifyChange(invoiceId: invoiceID)
        } catch {
            print("❌ [BillingHubViewModel] Error moving invoice: \(error)")
            return .invalidTransition(from: currentStatus.rawValue, to: targetStatus.rawValue)
        }
        
        objectWillChange.send()
        return .success
    }

    func nextColumn(for card: KanbanCardData) -> KanbanCardData.BillingColumnType? {
        switch card {
        case .session(let session):
            switch session.columnType {
            case .completed:
                return .grouped
            case .grouped:
                return .addTravel
            case .addTravel, .reviewDrafts, .readyToSend, .pending, .received:
                return nil
            }
        case .invoice(let invoice):
            switch invoice.columnType {
            case .reviewDrafts:
                return .readyToSend
            case .readyToSend:
                return .pending
            case .pending:
                return .received
            case .received, .completed, .grouped, .addTravel:
                return nil
            }
        }
    }

    func canAdvance(_ card: KanbanCardData) -> Bool {
        nextColumn(for: card) != nil
    }

    @discardableResult
    func advanceCard(_ card: KanbanCardData) async -> MoveResult {
        guard let destination = nextColumn(for: card) else {
            return .invalidTransition(from: card.columnType.rawValue, to: "none")
        }

        let result: MoveResult
        switch card {
        case .session(let session):
            result = await moveSession(session.sessionId, to: destination)
        case .invoice(let invoice):
            result = await moveInvoice(invoice.invoiceId, to: destination)
        }

        if !result.isSuccess {
            bulkActionFeedback = result.description
        }
        return result
    }
    
    /// Helper to convert column type to BillingStatus
    private func columnToBillingStatus(_ column: KanbanCardData.BillingColumnType) -> BillingStatus? {
        switch column {
        case .completed: return .completed
        case .grouped: return .grouped
        case .addTravel: return .addTravel
        case .reviewDrafts: return .reviewDrafts
        case .readyToSend: return .readyToSend
        case .pending: return .pending
        case .received: return .received
        }
    }
    
    /// Helper to convert raw invoice status to BillingStatus (handles overdue → pending)
    private func invoiceRawToBillingStatus(_ raw: String) -> BillingStatus? {
        if raw == "overdue" { return .pending }
        return BillingStatus(rawValue: raw)
    }

    /// Approves a draft invoice by setting due date and moving to ready-to-send.
    func approveDraftInvoice(id: UUID, dueDate: Date) async {
        guard var invoice = _allInvoices.first(where: { $0.id == id }) else { return }
        if let validation = await validateInvoiceTransitionIfNeeded(
            invoice: invoice,
            targetStatus: BillingStatus.readyToSend.rawValue,
            action: .approveDraft
        ) {
            if validation.isBlocked {
                bulkActionFeedback = blockerSummary(for: validation)
                return
            }
            if !validation.warnings.isEmpty {
                bulkActionFeedback = warningSummary(for: validation)
            }
        }
        invoice.dueDate = dueDate
        invoice.status = BillingStatus.readyToSend.rawValue

        do {
            _ = try await invoicesRepository.update(invoice)
            await fetchData()
            InvoiceChangePublisher.shared.notifyChange(invoiceId: id)
        } catch {
            print("❌ [BillingHubViewModel] Error approving draft invoice: \(error)")
        }
    }

    func selectClient(withID id: UUID?) {
        selectedClientID = id
    }

    func clearFilters() {
        searchText = ""
        selectedClientID = nil
    }

    func refresh() {
        scheduleRefresh(force: true)
    }

    func refreshIfNeeded() {
        scheduleRefresh(force: false)
    }

    private func scheduleRefresh(force: Bool) {
        if !force && hasCompletedInitialFetch {
            return
        }

        if refreshTask != nil {
            if force {
                pendingRefreshAfterCurrent = true
            }
            return
        }

        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.fetchData()
            self.finishRefreshCycle()
        }
    }

    private func finishRefreshCycle() {
        refreshTask = nil

        guard pendingRefreshAfterCurrent else { return }
        pendingRefreshAfterCurrent = false
        scheduleRefresh(force: true)
    }
    
    /// Creates a new invoice from grouped sessions
    func createInvoiceFromSessions(_ sessionIds: [UUID]) async {
        let uniqueSessionIds = uniqueIDsPreservingOrder(sessionIds)
        guard !uniqueSessionIds.isEmpty else { return }

        guard let clientId = await sharedClientID(for: uniqueSessionIds) else {
            return
        }
        
        do {
            let report = try await createInvoiceAndTransitionSessions(sessionIds: uniqueSessionIds, clientId: clientId)
            if let invoice = report.invoice {
                print("✅ [BillingHubViewModel] Created invoice: \(invoice.invoiceNumber)")
                if !report.failedSessions.isEmpty {
                    bulkActionFeedback = "Created invoice \(invoice.invoiceNumber), but \(report.failedSessions.count) sessions failed. Click details for info."
                }
            } else {
                bulkActionFeedback = "Could not create invoice. \(report.failedSessions.count) sessions failed."
            }
            await fetchData()
        } catch {
            print("❌ [BillingHubViewModel] Error creating invoice from sessions: \(error)")
            bulkActionFeedback = "Error: \(error.localizedDescription)"
        }
    }

    /// Creates a draft invoice from all sessions in a specific group
    func createDraftInvoice(fromGroupID groupID: UUID) async {
        let sessions = _allSessions.filter {
            $0.groupID == groupID && canonicalSessionStatusToken($0.status) == "grouped"
        }
        let sessionIds = sessions.map { $0.id }
        guard !sessionIds.isEmpty else { return }
        
        await createInvoiceFromSessions(sessionIds)
    }

    /// Creates draft invoices for all grouped sessions, separated by logical batch.
    func createDraftInvoicesForGroupedSessions() async {
        let batches = groupedDraftBatches()
        guard !batches.isEmpty else { return }

        var created = 0
        for batch in batches {
            do {
                let report = try await createInvoiceAndTransitionSessions(
                    sessionIds: batch.sessionIDs,
                    clientId: batch.clientID
                )
                if report.invoice != nil {
                    created += 1
                }
            } catch {
                print("❌ [BillingHubViewModel] Failed draft batch for client \(batch.clientID): \(error)")
            }
        }

        if created > 0 {
            await fetchData()
            InvoiceChangePublisher.shared.notifyRefreshNeeded()
            print("✅ [BillingHubViewModel] Created \(created) draft invoice batch(es)")
        }
    }
    
    /// Sends an invoice (updates status and sent date)
    func sendInvoice(id: UUID, recipients: String, subject: String, message: String) async {
        _ = subject
        let normalizedRecipients = recipients.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRecipients.isEmpty else { return }

        if var invoice = _allInvoices.first(where: { $0.id == id }) {
            if let validation = await validateInvoiceTransitionIfNeeded(
                invoice: invoice,
                targetStatus: BillingStatus.pending.rawValue,
                action: .sendInvoice
            ) {
                if validation.isBlocked {
                    bulkActionFeedback = blockerSummary(for: validation)
                    return
                }
                if !validation.warnings.isEmpty {
                    bulkActionFeedback = warningSummary(for: validation)
                }
            }
            invoice.status = BillingStatus.pending.rawValue
            invoice.sentDate = Date()
            invoice.clientEmail = normalizedRecipients
            invoice.notes = message // Storing message in notes for now
            
            do {
                _ = try await invoicesRepository.update(invoice)
                InvoiceChangePublisher.shared.notifyChange(invoiceId: id)
                await fetchData()
            } catch {
                print("❌ [BillingHubViewModel] Error sending invoice: \(error)")
            }
        }
    }

    /// Marks an invoice as overdue while keeping it in the payment column.
    func markInvoiceOverdue(id: UUID) async {
        guard var invoice = _allInvoices.first(where: { $0.id == id }) else { return }
        invoice.status = "overdue"
        invoice.paidDate = nil
        if invoice.sentDate == nil {
            invoice.sentDate = Date()
        }

        do {
            _ = try await invoicesRepository.update(invoice)
            InvoiceChangePublisher.shared.notifyChange(invoiceId: id)
            await fetchData()
        } catch {
            print("❌ [BillingHubViewModel] Error marking invoice overdue: \(error)")
        }
    }

    /// Moves an invoice back to draft review and clears payment/send markers.
    func moveInvoiceBackToDraftReview(id: UUID) async {
        guard var invoice = _allInvoices.first(where: { $0.id == id }) else { return }
        invoice.status = BillingStatus.reviewDrafts.rawValue
        invoice.sentDate = nil
        invoice.paidDate = nil

        do {
            _ = try await invoicesRepository.update(invoice)
            InvoiceChangePublisher.shared.notifyChange(invoiceId: id)
            await fetchData()
        } catch {
            print("❌ [BillingHubViewModel] Error moving invoice back to draft review: \(error)")
        }
    }

    /// Moves an invoice back to ready-to-send and clears payment/send markers.
    func moveInvoiceBackToReadyToSend(id: UUID) async {
        guard var invoice = _allInvoices.first(where: { $0.id == id }) else { return }
        invoice.status = BillingStatus.readyToSend.rawValue
        invoice.sentDate = nil
        invoice.paidDate = nil

        do {
            _ = try await invoicesRepository.update(invoice)
            InvoiceChangePublisher.shared.notifyChange(invoiceId: id)
            await fetchData()
        } catch {
            print("❌ [BillingHubViewModel] Error moving invoice back to ready-to-send: \(error)")
        }
    }

    /// Reopens a completed invoice as pending payment.
    func reopenInvoiceAsPending(id: UUID) async {
        guard var invoice = _allInvoices.first(where: { $0.id == id }) else { return }
        invoice.status = BillingStatus.pending.rawValue
        invoice.paidDate = nil
        if invoice.sentDate == nil {
            invoice.sentDate = Date()
        }

        do {
            _ = try await invoicesRepository.update(invoice)
            InvoiceChangePublisher.shared.notifyChange(invoiceId: id)
            await fetchData()
        } catch {
            print("❌ [BillingHubViewModel] Error reopening invoice as pending: \(error)")
        }
    }

    /// Finalizes payment details and marks invoice as received with chosen payment date.
    func finalizePayment(id: UUID, amount: String, date: Date, method: String, reference: String) async {
        guard var invoice = _allInvoices.first(where: { $0.id == id }) else { return }
        if let validation = await validateInvoiceTransitionIfNeeded(
            invoice: invoice,
            targetStatus: BillingStatus.received.rawValue,
            action: .markPaid
        ) {
            if validation.isBlocked {
                bulkActionFeedback = blockerSummary(for: validation)
                return
            }
            if !validation.warnings.isEmpty {
                bulkActionFeedback = warningSummary(for: validation)
            }
        }

        let cleanedAmount = amount
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        if let parsedAmount = Double(cleanedAmount) {
            invoice.totalAmount = parsedAmount
        }

        invoice.paymentTerms = method
        if !reference.isEmpty {
            invoice.notes = "Ref: \(reference)\(invoice.notes.map { " | \($0)" } ?? "")"
        }

        invoice.status = BillingStatus.received.rawValue
        invoice.paidDate = date

        do {
            _ = try await invoicesRepository.update(invoice)
            InvoiceChangePublisher.shared.notifyChange(invoiceId: id)
            await fetchData()
        } catch {
            print("❌ [BillingHubViewModel] Error finalizing invoice payment: \(error)")
        }
    }

    func sendAllReadyToSendInvoices() async {
        let readyInvoices = filteredInvoices().filter {
            canonicalInvoiceStatusToken($0.status) == BillingStatus.readyToSend.rawValue
        }
        guard !readyInvoices.isEmpty else { return }

        var sentCount = 0
        var skippedMissingRecipient = 0
        var blockedCount = 0
        var warningOnlyCount = 0
        var snapshots: [InvoiceWorkflowSnapshot] = []
        for var invoice in readyInvoices {
            let recipient = (invoice.clientEmail ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !recipient.isEmpty else {
                skippedMissingRecipient += 1
                continue
            }

            if let validation = await validateInvoiceTransitionIfNeeded(
                invoice: invoice,
                targetStatus: BillingStatus.pending.rawValue,
                action: .bulkSendReady
            ) {
                if validation.isBlocked {
                    blockedCount += 1
                    continue
                }
                if !validation.warnings.isEmpty {
                    warningOnlyCount += 1
                }
            }

            snapshots.append(captureSnapshot(for: invoice))

            invoice.status = BillingStatus.pending.rawValue
            invoice.sentDate = Date()

            do {
                _ = try await invoicesRepository.update(invoice)
                sentCount += 1
                InvoiceChangePublisher.shared.notifyChange(invoiceId: invoice.id)
            } catch {
                print("❌ [BillingHubViewModel] Error sending ready invoice \(invoice.id): \(error)")
            }
        }

        if sentCount > 0 {
            await fetchData()
            InvoiceChangePublisher.shared.notifyRefreshNeeded()
            lastBulkUndoAction = BulkUndoAction(
                label: "Send Ready",
                snapshots: snapshots
            )
            var summary = "Processed \(sentCount), blocked \(blockedCount)."
            if skippedMissingRecipient > 0 {
                summary += " Skipped \(skippedMissingRecipient) missing email."
            }
            if warningOnlyCount > 0 {
                summary += " \(warningOnlyCount) processed with warnings."
            }
            bulkActionFeedback = summary
            complianceLogger.info(
                "bulk_validation_summary action=\(ComplianceAction.bulkSendReady.rawValue, privacy: .public) processed=\(sentCount, privacy: .public) blocked=\(blockedCount, privacy: .public) warnings=\(warningOnlyCount, privacy: .public)"
            )
            print("✅ [BillingHubViewModel] Sent \(sentCount) ready invoice(s)")
        } else if blockedCount > 0 || skippedMissingRecipient > 0 {
            var summary = "Processed 0, blocked \(blockedCount)."
            if skippedMissingRecipient > 0 {
                summary += " Skipped \(skippedMissingRecipient) missing email."
            }
            bulkActionFeedback = summary
            complianceLogger.info(
                "bulk_validation_summary action=\(ComplianceAction.bulkSendReady.rawValue, privacy: .public) processed=0 blocked=\(blockedCount, privacy: .public) warnings=0 skipped_missing_email=\(skippedMissingRecipient, privacy: .public)"
            )
        }
    }

    func completeAllPendingInvoices() async {
        let pendingInvoices = filteredInvoices().filter {
            let status = canonicalInvoiceStatusToken($0.status)
            return status == BillingStatus.pending.rawValue || status == "overdue"
        }
        guard !pendingInvoices.isEmpty else { return }

        var completedCount = 0
        var blockedCount = 0
        var warningOnlyCount = 0
        var snapshots: [InvoiceWorkflowSnapshot] = []
        for var invoice in pendingInvoices {
            if let validation = await validateInvoiceTransitionIfNeeded(
                invoice: invoice,
                targetStatus: BillingStatus.received.rawValue,
                action: .bulkCompletePending
            ) {
                if validation.isBlocked {
                    blockedCount += 1
                    continue
                }
                if !validation.warnings.isEmpty {
                    warningOnlyCount += 1
                }
            }

            snapshots.append(captureSnapshot(for: invoice))
            invoice.status = BillingStatus.received.rawValue
            if invoice.paidDate == nil {
                invoice.paidDate = Date()
            }

            do {
                _ = try await invoicesRepository.update(invoice)
                completedCount += 1
                InvoiceChangePublisher.shared.notifyChange(invoiceId: invoice.id)
            } catch {
                print("❌ [BillingHubViewModel] Error completing pending invoice \(invoice.id): \(error)")
            }
        }

        if completedCount > 0 {
            await fetchData()
            InvoiceChangePublisher.shared.notifyRefreshNeeded()
            lastBulkUndoAction = BulkUndoAction(
                label: "Complete Pending",
                snapshots: snapshots
            )
            var summary = "Processed \(completedCount), blocked \(blockedCount)."
            if warningOnlyCount > 0 {
                summary += " \(warningOnlyCount) processed with warnings."
            }
            bulkActionFeedback = summary
            complianceLogger.info(
                "bulk_validation_summary action=\(ComplianceAction.bulkCompletePending.rawValue, privacy: .public) processed=\(completedCount, privacy: .public) blocked=\(blockedCount, privacy: .public) warnings=\(warningOnlyCount, privacy: .public)"
            )
            print("✅ [BillingHubViewModel] Completed \(completedCount) pending invoice(s)")
        } else if blockedCount > 0 {
            bulkActionFeedback = "Processed 0, blocked \(blockedCount)."
            complianceLogger.info(
                "bulk_validation_summary action=\(ComplianceAction.bulkCompletePending.rawValue, privacy: .public) processed=0 blocked=\(blockedCount, privacy: .public) warnings=0"
            )
        }
    }

    func undoLastBulkAction() async {
        guard let action = lastBulkUndoAction else { return }

        var restored = 0
        for snapshot in action.snapshots {
            do {
                guard var invoice = try await invoicesRepository.fetch(by: snapshot.id) else { continue }
                invoice.status = snapshot.status
                invoice.sentDate = snapshot.sentDate
                invoice.paidDate = snapshot.paidDate
                _ = try await invoicesRepository.update(invoice)
                restored += 1
                InvoiceChangePublisher.shared.notifyChange(invoiceId: snapshot.id)
            } catch {
                print("❌ [BillingHubViewModel] Error undoing invoice \(snapshot.id): \(error)")
            }
        }

        lastBulkUndoAction = nil
        if restored > 0 {
            await fetchData()
            InvoiceChangePublisher.shared.notifyRefreshNeeded()
            bulkActionFeedback = "Undid \(action.label) for \(restored) invoice(s)."
        }
    }

    func clearBulkActionFeedback() {
        bulkActionFeedback = nil
    }
    
    /// Sends a test invoice to the user's own email
    func sendTestInvoice(id: UUID, recipients: String, subject: String, message: String) async {
        guard let invoice = _allInvoices.first(where: { $0.id == id }) else { return }
        let normalizedRecipients = parseRecipients(recipients)
        guard !normalizedRecipients.isEmpty else {
            bulkActionFeedback = "Enter at least one test recipient email."
            return
        }

        let finalSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Test Invoice \(invoice.invoiceNumber)"
            : subject
        let finalMessage = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "This is a test send for invoice \(invoice.invoiceNumber)."
            : message

        let sent = composeEmail(
            subject: finalSubject,
            recipients: normalizedRecipients,
            body: finalMessage,
            attachments: []
        )
        if sent {
            bulkActionFeedback = "Opened mail composer for test send."
        } else {
            bulkActionFeedback = "Unable to open mail composer."
        }
    }
    
    /// Saves payment details as a draft without finalizing the payment
    func savePaymentDraft(id: UUID, amount: String, date: Date, method: String, reference: String) async {
        guard var invoice = _allInvoices.first(where: { $0.id == id }) else { return }
        
        // Parse amount (strip currency symbols)
        let cleanedAmount = amount.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        if let parsedAmount = Double(cleanedAmount) {
            invoice.totalAmount = parsedAmount
        }
        
        // Store payment method and reference in notes (could use dedicated fields if available)
        invoice.paymentTerms = method
        if !reference.isEmpty {
            invoice.notes = "Ref: \(reference)\(invoice.notes.map { " | \($0)" } ?? "")"
        }
        
        do {
            _ = try await invoicesRepository.update(invoice)
            InvoiceChangePublisher.shared.notifyChange(invoiceId: id)
            await fetchData()
            print("💾 [BillingHubViewModel] Saved payment draft for invoice \(id)")
        } catch {
            print("❌ [BillingHubViewModel] Error saving payment draft: \(error)")
        }
    }
    
    /// Sends a payment receipt to the specified email
    func sendReceipt(id: UUID, recipientEmail: String, includePDF: Bool) async {
        guard let invoice = _allInvoices.first(where: { $0.id == id }) else { return }

        let recipients = parseRecipients(recipientEmail)
        guard !recipients.isEmpty else {
            bulkActionFeedback = "Enter a valid receipt email address."
            return
        }

        var attachments: [URL] = []
        if includePDF, let receiptURL = await exportReceiptPDF(id: id) {
            attachments.append(receiptURL)
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = invoice.currencyCode
        let amount = formatter.string(from: NSNumber(value: invoice.totalAmount))
            ?? String(format: "%.2f", invoice.totalAmount)
        let paymentDate = (invoice.paidDate ?? Date()).formatted(date: .abbreviated, time: .omitted)
        let body = """
        Receipt for invoice \(invoice.invoiceNumber)

        Amount received: \(amount)
        Payment date: \(paymentDate)

        Thank you.
        """

        let sent = composeEmail(
            subject: "Receipt \(invoice.invoiceNumber)",
            recipients: recipients,
            body: body,
            attachments: attachments
        )
        if sent {
            bulkActionFeedback = "Opened receipt email draft."
        } else {
            bulkActionFeedback = "Unable to open mail composer."
        }
    }
    
    /// Exports invoice/receipt as PDF
    func exportReceiptPDF(id: UUID) async -> URL? {
        guard let invoice = _allInvoices.first(where: { $0.id == id }) else { return nil }

        let sanitizedNumber = invoice.invoiceNumber
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        let filename = "Receipt-\(sanitizedNumber)-\(invoice.id.uuidString.prefix(8)).pdf"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        guard let pdfData = makeReceiptPDFData(for: invoice) else {
            bulkActionFeedback = "Failed to generate receipt PDF."
            return nil
        }

        do {
            try pdfData.write(to: outputURL, options: .atomic)
            bulkActionFeedback = "Receipt PDF exported to temporary files."
            return outputURL
        } catch {
            print("❌ [BillingHubViewModel] Error writing receipt PDF: \(error)")
            bulkActionFeedback = "Failed to write receipt PDF."
            return nil
        }
    }
    
    /// Updates session details (duration) from EditingPanel
    func updateSessionDetails(id: UUID, durationString: String) async {
        guard let session = fetchSession(byID: id) else { return }
        
        // Parse duration string (e.g. "2.0h" or "120m")
        var durationMinutes: Double?
        
        let cleaned = durationString.lowercased().trimmingCharacters(in: .whitespaces)
        if cleaned.hasSuffix("h") {
            if let hours = Double(cleaned.dropLast()) {
                durationMinutes = hours * 60
            }
        } else if cleaned.hasSuffix("m") {
            if let mins = Double(cleaned.dropLast()) {
                durationMinutes = mins
            }
        } else {
            // Assume hours if no suffix
            if let val = Double(cleaned) {
                durationMinutes = val * 60
            }
        }
        
        guard let minutes = durationMinutes, let startTime = session.startTime else { return }
        
        // Create new session with updated endTime
        let newEndTime = startTime.addingTimeInterval(minutes * 60)
        
        let updatedSession = Session(
            id: session.id,
            title: session.title,
            startTime: startTime,
            endTime: newEndTime,
            isAllDay: session.isAllDay,
            location: session.location,
            notes: session.notes,
            status: session.status,
            isTravel: session.isTravel,
            clientId: session.clientId,
            clientServiceId: session.clientServiceId,
            addressId: session.addressId,
            groupID: session.groupID,
            groupedPosition: session.groupedPosition,
            eventIdentifier: session.eventIdentifier,
            calendarIdentifier: session.calendarIdentifier,
            lastModifiedDate: Date(),
            lastSyncTag: session.lastSyncTag,
            recurrenceRuleData: session.recurrenceRuleData,
            attendeesCount: session.attendeesCount,
            derivedFromEKEventID: session.derivedFromEKEventID,
            googleColorId: session.googleColorId,
            sessionLatitude: session.sessionLatitude,
            sessionLongitude: session.sessionLongitude
        )
        
        do {
            _ = try await sessionsRepository.update(updatedSession)
            await fetchData()
        } catch {
            print("❌ [BillingHubViewModel] Error updating session details: \(error)")
        }
    }
    
    /// Updates invoice details (amount, client name) from EditingPanel
    func updateInvoiceDetails(id: UUID, amountString: String, clientName: String) async {
        guard var invoice = _allInvoices.first(where: { $0.id == id }) else { return }
        
        // Parse amount (strip currency symbols)
        let cleanedAmount = amountString.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        if let amount = Double(cleanedAmount) {
            invoice.totalAmount = amount
        }
        
        if !clientName.isEmpty {
            invoice.clientName = clientName
        }
        
        do {
            _ = try await invoicesRepository.update(invoice)
            await fetchData()
            InvoiceChangePublisher.shared.notifyChange(invoiceId: id)
        } catch {
            print("❌ [BillingHubViewModel] Error updating invoice details: \(error)")
        }
    }
    
    /// Reverts a draft invoice back to editable sessions
    func requestChanges(for invoiceId: UUID) async {
        guard let invoice = _allInvoices.first(where: { $0.id == invoiceId }) else { return }
        let sessionIds = uniqueIDsPreservingOrder(invoice.sessionIds)
        
        do {
            var priorGroups = Set<UUID>()
            for sessionId in sessionIds {
                if let session = try await sessionsRepository.fetch(byId: sessionId),
                   let groupID = session.groupID {
                    priorGroups.insert(groupID)
                }
            }

            // Return sessions to processing so travel/details can be corrected.
            for sessionId in sessionIds {
                guard let status = statusString(for: .addTravel) else { continue }
                try await sessionsRepository.updateStatus(id: sessionId, status: status)
            }

            if !sessionIds.isEmpty {
                try? await sessionsRepository.ungroupSessions(sessionIds)
            }
            let scrubbedGroups = await clearStaleGroupAssociations(in: .addTravel)
            for groupID in priorGroups.union(scrubbedGroups) {
                await dissolveGroupIfSingleton(groupID: groupID)
                await reindexGroupedScope(groupID)
            }
            if !priorGroups.isEmpty || !scrubbedGroups.isEmpty {
                await reindexGroupedScope(nil)
            }
            
            // Delete the draft invoice
            try await invoicesRepository.delete(id: invoiceId)
            
            await fetchData()
            // Notify overall refresh for both features
            InvoiceChangePublisher.shared.notifyRefreshNeeded()
        } catch {
            print("❌ [BillingHubViewModel] Error requesting changes: \(error)")
        }
    }
    
    // MARK: - Private Methods

    private func fetchData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _allSessions = try await sessionsRepository.fetchAll()
            _allInvoices = try await invoicesRepository.fetchAll()
            synchronizeInvoiceOrderBuckets()
            _allClients = try await clientsRepository.fetchAll()
            
            // Prefetch client services for all active clients for travel rate lookups
            var servicesCache: [UUID: [ClientService]] = [:]
            for client in _allClients {
                let services = try await clientServicesRepository.fetch(for: client.id)
                servicesCache[client.id] = services
            }
            _clientServicesCache = servicesCache
            
            // Defensive invariant: non-Grouped statuses must not retain persisted group IDs.
            await normalizeNonGroupedGroupAssociationsIfNeeded()

            // Ensure grouped positions are normalized based on current order
            await normalizeGroupedPositionsIfNeeded()
            // Note: Invoice position normalization handled by repository
            hasCompletedInitialFetch = true
        } catch {
            print("❌ [BillingHubViewModel] Error fetching data: \(error)")
        }
    }

    private func filteredSessions() -> [Session] {
        var sessions = _allSessions

        if let selectedClientID {
            sessions = sessions.filter { $0.clientId == selectedClientID }
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            sessions = sessions.filter { session in
                let clientName = _allClients.first(where: { $0.id == session.clientId })?.fullName ?? ""
                return session.title.localizedCaseInsensitiveContains(trimmedQuery) ||
                    clientName.localizedCaseInsensitiveContains(trimmedQuery) ||
                    (session.assignedServiceName?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
            }
        }

        return sessions
    }

    /// Ensure every session in the Grouped column has a contiguous groupedPosition across the column.
    private func normalizeGroupedPositionsIfNeeded() async {
        let grouped = _allSessions.filter { canonicalSessionStatusToken($0.status) == "grouped" }
        guard !grouped.isEmpty else { return }

        var clusters = groupedClusters(from: grouped)
        sortGroupedClusters(&clusters)
        let updates = groupedPositionUpdates(from: clusters)
        await applyGroupedPositionUpdates(updates)

        if !updates.isEmpty {
            if let refreshedSessions = try? await sessionsRepository.fetchAll() {
                _allSessions = refreshedSessions
            }
        }
    }

    /// Clears persisted group IDs for sessions that are not in the Grouped status.
    private func normalizeNonGroupedGroupAssociationsIfNeeded() async {
        let staleSessions = _allSessions.filter {
            canonicalSessionStatusToken($0.status) != BillingStatus.grouped.rawValue && $0.groupID != nil
        }
        guard !staleSessions.isEmpty else { return }

        let staleGroupIDs = Set(staleSessions.compactMap(\.groupID))
        try? await sessionsRepository.ungroupSessions(staleSessions.map(\.id))

        for groupID in staleGroupIDs {
            await dissolveGroupIfSingleton(groupID: groupID)
            await reindexGroupedScope(groupID)
        }
        await reindexGroupedScope(nil)

        if let refreshed = try? await sessionsRepository.fetchAll() {
            _allSessions = refreshed
        }
    }
    
    private func filteredInvoices() -> [Invoice] {
        var invoices = _allInvoices

        if let selectedClientID {
            invoices = invoices.filter { $0.clientId == selectedClientID }
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            invoices = invoices.filter { invoice in
                invoice.invoiceNumber.localizedCaseInsensitiveContains(trimmedQuery) ||
                invoice.clientName?.localizedCaseInsensitiveContains(trimmedQuery) == true
            }
        }

        invoices.sort { lhs, rhs in
            let leftStatus = canonicalInvoiceStatusToken(lhs.status) ?? ""
            let rightStatus = canonicalInvoiceStatusToken(rhs.status) ?? ""
            let leftStatusOrder = invoiceStatusSequence.firstIndex(of: leftStatus) ?? Int.max
            let rightStatusOrder = invoiceStatusSequence.firstIndex(of: rightStatus) ?? Int.max

            if leftStatusOrder != rightStatusOrder {
                return leftStatusOrder < rightStatusOrder
            }

            let leftBucket = invoiceOrderBucket(for: lhs)
            let rightBucket = invoiceOrderBucket(for: rhs)
            if leftBucket == rightBucket, let bucket = leftBucket {
                let ranks = invoiceOrderRanks(for: bucket)
                let leftRank = ranks[lhs.id]
                let rightRank = ranks[rhs.id]
                switch (leftRank, rightRank) {
                case let (a?, b?) where a != b:
                    return a < b
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    break
                }
            }

            return lhs.issueDate > rhs.issueDate
        }

        return invoices
    }
    
    /// Maps a Session to a KanbanCardData
    private func mapSessionToKanbanCard(_ session: Session) -> KanbanCardData? {
        guard let columnType = mapBillingStatus(for: session) else { return nil }
        let sessionId = session.id
        
        let title = session.title
        // Fetch client name from cache
        let clientName = _allClients.first(where: { $0.id == session.clientId })?.fullName ?? "Client"
        let serviceName = session.assignedServiceName ?? session.title
        // hasIssues: Check for missing required data (no service assigned, no client, or missing travel data when expected)
        let hasIssues = session.assignedServiceName == nil || session.clientId == nil
        let date = session.startTime?.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()) ?? ""
        var duration: String = "-"
        let sessionEndTime: Date? = session.endTime
        
        if let startTime = session.startTime, let endTime = session.endTime {
            let components = Calendar.current.dateComponents([.hour, .minute], from: startTime, to: endTime)
            if let hours = components.hour, let minutes = components.minute {
                let totalMinutes = Double(hours * 60 + minutes)
                if totalMinutes > 0 {
                    duration = String(format: "%.1f", totalMinutes / 60.0) + "h"
                }
            }
        }
        
        let workflowStatus = KanbanCardData.workflowStatus(for: columnType)
        let accentColor = KanbanCardData.columnAccentColor(for: columnType)
        let priority = hasIssues ? Priority.high : .low
        let rateInfo = travelRateInfo(for: session)
        // Use persisted travel data if available, otherwise suggestion
        let travelSuggestion = travelSuggestion(for: session)
        let displayDistance = session.travelDistanceKM ?? travelSuggestion.distanceKilometres
        let displayTime = session.travelTimeMinutes ?? travelSuggestion.timeMinutes

        let sessionCardData = SessionKanbanCardData(
            sessionId: sessionId,
            title: title,
            clientName: clientName,
            serviceName: serviceName,
            travelRate: session.assignedRate ?? rateInfo?.rate,
            travelRateUnit: rateInfo?.unit,
            suggestedTravelDistanceKM: displayDistance,
            suggestedTravelTimeMinutes: displayTime,
            priority: priority,
            accentColor: accentColor,
            duration: duration,
            date: date,
            hasIssues: hasIssues,
            workflowStatus: workflowStatus,
            columnType: columnType,
            startTime: session.startTime,
            endTime: sessionEndTime,
            groupID: session.groupID
        )
        return .session(sessionCardData)
    }
    
    /// Maps an Invoice to a KanbanCardData
    private func mapInvoiceToKanbanCard(_ invoice: Invoice) -> KanbanCardData? {
        // Skip invoices that shouldn't appear in Kanban (Cancelled, Voided)
        guard let columnType = mapBillingStatus(for: invoice) else {
            return nil
        }
        
        let invoiceId = invoice.id
        
        let title = invoice.invoiceNumber.isEmpty ? "Draft Invoice" : "\(invoice.invoiceNumber)"
        let clientName = invoice.clientName ?? "Unknown Client"
        // Derive service name from linked sessions (first session's assigned service)
        let serviceName: String
        if let firstSessionId = invoice.sessionIds.first,
           let firstSession = _allSessions.first(where: { $0.id == firstSessionId }) {
            serviceName = firstSession.assignedServiceName ?? firstSession.title
        } else {
            serviceName = "Invoice Services"
        }
        let date = invoice.issueDate.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year())
        let amount = String(format: "$%.2f", invoice.totalAmount)
        
        let workflowStatus = KanbanCardData.workflowStatus(for: columnType)
        let accentColor = KanbanCardData.columnAccentColor(for: columnType)
        let priority: Priority = invoice.isOverdue ? .high : .medium
        
        let invoiceCardData = InvoiceKanbanCardData(
            invoiceId: invoiceId,
            title: title,
            clientName: clientName,
            serviceName: serviceName,
            priority: priority,
            accentColor: accentColor,
            amount: amount,
            date: date,
            workflowStatus: workflowStatus,
            columnType: columnType,
            isOverdue: invoice.isOverdue,
            daysOverdue: invoice.daysUntilDue.flatMap { $0 < 0 ? abs($0) : nil },
            rawDate: invoice.issueDate
        )
        return .invoice(invoiceCardData)
    }
    
    private func mapBillingStatus(for session: Session) -> KanbanCardData.BillingColumnType? {
        switch canonicalSessionStatusToken(session.status) {
        case "completed":
            return .completed
        case "grouped":
            return .grouped
        case "needs_travel":
            return .addTravel
        default:
            return nil
        }
    }

    private func statusString(for column: KanbanCardData.BillingColumnType) -> String? {
        switch column {
        case .completed: return BillingStatus.completed.rawValue
        case .grouped: return BillingStatus.grouped.rawValue
        case .addTravel: return BillingStatus.addTravel.rawValue
        case .reviewDrafts: return BillingStatus.reviewDrafts.rawValue
        case .readyToSend: return BillingStatus.readyToSend.rawValue
        case .pending: return BillingStatus.pending.rawValue
        case .received: return BillingStatus.received.rawValue
        }
    }
    
    private func mapBillingStatus(for invoice: Invoice) -> KanbanCardData.BillingColumnType? {
        switch canonicalInvoiceStatusToken(invoice.status) {
        case "review_draft":
            return .reviewDrafts
        case "ready_to_send":
            return .readyToSend
        case "pending":
            return .pending
        case "received":
            return .received
        case "overdue":
            // Overdue invoices go to Pending column with a visual indicator
            return .pending
        case "cancelled", "voided":
            // Hide cancelled/voided invoices from Kanban
            return nil
        default:
            return nil
        }
    }
    
    private func generateInvoiceNumber() async -> String {
        do {
            return try await invoicesRepository.generateInvoiceNumber()
        } catch {
            // Fallback to simple generation
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            let dateString = formatter.string(from: Date())
            return "INV-\(dateString)-0001"
        }
    }
    
    // MARK: - Drag & Drop Helpers
    /// Returns a Session by its UUID if present in cache
    func fetchSession(byID id: UUID) -> Session? {
        return _allSessions.first(where: { $0.id == id })
    }
    
    /// Fetches session from repository (for async operations)
    func fetchSessionFromRepository(byID id: UUID) async -> Session? {
        do {
            return try await sessionsRepository.fetch(byId: id)
        } catch {
            print("❌ [BillingHubViewModel] Error fetching session: \(error)")
            return nil
        }
    }

    /// Moves a session into the Grouped column (no pairing)
    /// - Note: Now delegates to the unified `moveSession` method for consistent validation
    func moveSessionToGrouped(sessionID: UUID) {
        Task {
            _ = await moveSession(sessionID, to: .grouped)
        }
    }

    /// Handles dropping a session into the Grouped column background (not onto a card).
    /// If the session came from Completed, moves to grouped. If already grouped and part of a group,
    /// it gets ungrouped (groupID cleared). If that leaves its old group with a singleton, dissolve it.
    /// - Note: Now delegates to the unified `moveSession` method for consistent validation
    func dropIntoGroupedColumn(sessionID: UUID) {
        Task {
            _ = await moveSession(sessionID, to: .grouped)
        }
    }

    // MARK: - Group maintenance
    /// If a group's remaining membership is a single session, clear its groupID to dissolve the group.
    private func dissolveGroupIfSingleton(groupID: UUID) async {
        guard let members = try? await sessionsRepository.fetch(byGroupId: groupID) else { return }
        if members.count <= 1, let last = members.first {
            do {
                try await sessionsRepository.ungroupSessions([last.id])
            } catch {
                print("❌ [BillingHubViewModel] Error dissolving group: \(error)")
            }
        }
    }

    // MARK: - Optimized operations (async repository-based)
    /// Move to Completed (optimized for performance)
    /// - Note: Now delegates to the unified `moveSession` method for consistent validation
    /// Group sessions together (async repository-based)
    /// - Note: Uses unified `moveSession` for non-grouped column transitions
    func groupSessionsSmooth(sourceID: UUID, targetID: UUID, in column: KanbanCardData.BillingColumnType = .grouped) -> Bool {
        Task {
            guard sourceID != targetID else { return }
            guard let source = await fetchSessionFromRepository(byID: sourceID),
                  let target = await fetchSessionFromRepository(byID: targetID) else { return }

            guard source.clientId != nil, source.clientId == target.clientId else { return }

            // Group IDs are only valid in the Grouped column.
            if column != .grouped {
                let priorGroups = Set([source.groupID, target.groupID].compactMap { $0 })
                _ = await moveSession(targetID, to: column, handleGrouping: false)
                _ = await moveSession(sourceID, to: column, handleGrouping: false)
                try? await sessionsRepository.ungroupSessions(uniqueIDsPreservingOrder([sourceID, targetID]))
                let scrubbedGroups = await clearStaleGroupAssociations(in: column)

                for groupID in priorGroups.union(scrubbedGroups) {
                    await dissolveGroupIfSingleton(groupID: groupID)
                    await reindexGroupedScope(groupID)
                }
                await reindexGroupedScope(nil)
                objectWillChange.send()
                return
            }
            
            await updateSessionStatus(targetID, to: column)
            await updateSessionStatus(sourceID, to: column)

            let previousGroup = source.groupID
            let newGroupID: UUID

            if let existingGroup = target.groupID {
                newGroupID = existingGroup
                try? await sessionsRepository.groupSessions([sourceID], groupId: existingGroup)
            } else {
                let newGroup = UUID()
                newGroupID = newGroup
                try? await sessionsRepository.groupSessions([sourceID, targetID], groupId: newGroup)
            }

            if let previousGroup, previousGroup != newGroupID {
                await dissolveGroupIfSingleton(groupID: previousGroup)
                if column == .grouped { await reindexGroupedScope(previousGroup) }
            }

            if column == .grouped {
                await reindexGroupedScope(newGroupID)
            } else {
                await reindexGroupedScope(previousGroup)
                await reindexGroupedScope(nil)
            }

            objectWillChange.send()
        }
        return true
    }
    
    /// Add a session to an existing group
    func addSessionToGroup(sessionID: UUID, groupID: UUID) -> Bool {
        Task {
            guard let session = await fetchSessionFromRepository(byID: sessionID) else { return }
            let isCurrentlyGrouped = canonicalSessionStatusToken(session.status) == BillingStatus.grouped.rawValue
            
            // Check if session is already in the target group
            if session.groupID == groupID {
                if !isCurrentlyGrouped {
                    try? await sessionsRepository.updateBillingStatus(id: sessionID, status: .grouped)
                    await fetchData()
                    objectWillChange.send()
                }
                return
            }
            
            // Validate that all sessions in the group have the same client
            let targetGroupMembers = _allSessions.filter {
                $0.groupID == groupID && canonicalSessionStatusToken($0.status) == BillingStatus.grouped.rawValue
            }
            if !targetGroupMembers.isEmpty {
                guard let firstClientId = targetGroupMembers.first?.clientId,
                      session.clientId == firstClientId else {
                    return // Different client, cannot group
                }
            }
            
            let previousGroup = session.groupID

            if !isCurrentlyGrouped {
                try? await sessionsRepository.updateBillingStatus(id: sessionID, status: .grouped)
            }
            
            // Group session
            try? await sessionsRepository.groupSessions([sessionID], groupId: groupID)
            
            if let previousGroup {
                await dissolveGroupIfSingleton(groupID: previousGroup)
                await reindexGroupedScope(previousGroup)
            }
            
            await reindexGroupedScope(groupID)
            await fetchData()
            objectWillChange.send()
        }
        return true
    }
    
    /// Check if a session can be added to a group (same client only)
    func canAddSessionToGroup(sessionID: UUID, groupID: UUID) -> Bool {
        guard let session = fetchSession(byID: sessionID) else { return false }
        
        let targetGroupMembers = _allSessions.filter {
            $0.groupID == groupID && canonicalSessionStatusToken($0.status) == BillingStatus.grouped.rawValue
        }
        if targetGroupMembers.isEmpty {
            return true
        }
        
        guard let firstClientId = targetGroupMembers.first?.clientId else { return true }
        return session.clientId == firstClientId
    }

    /// Reassign contiguous groupedPosition values for a given Grouped scope
    private func reindexGroupedScope(_ groupID: UUID?) async {
        let grouped = (try? await sessionsRepository.fetch(byStatus: BillingStatus.grouped.rawValue)) ?? []
        guard !grouped.isEmpty else { return }

        var clusters = groupedClusters(from: grouped)
        sortGroupedClusters(&clusters)
        let updates = groupedPositionUpdates(from: clusters)
        await applyGroupedPositionUpdates(updates)
    }

    /// Clears stale grouping metadata from non-Grouped columns.
    /// Returns any group IDs that were removed so callers can dissolve/reindex affected groups.
    private func clearStaleGroupAssociations(in column: KanbanCardData.BillingColumnType) async -> Set<UUID> {
        guard column != .grouped, let status = statusString(for: column) else { return [] }

        let staleSessions = ((try? await sessionsRepository.fetch(byStatus: status)) ?? []).filter { $0.groupID != nil }
        guard !staleSessions.isEmpty else { return [] }

        let staleGroupIDs = Set(staleSessions.compactMap(\.groupID))
        try? await sessionsRepository.ungroupSessions(staleSessions.map(\.id))
        return staleGroupIDs
    }

    // MARK: - Reordering within Preparing Sessions
    /// Reorder within the Completed subcolumn (and also handles moving in from other columns first).
    /// Places the `sourceID` session just before `beforeTargetID` if provided, otherwise appends to end of Completed.
    /// Returns true when the operation succeeded and UI should accept the drop.
    @discardableResult
    func reorderInCompleted(sourceID: UUID, beforeTargetID: UUID?) -> Bool {
        reorderSessionsInColumn(.completed, sourceID: sourceID, beforeTargetID: beforeTargetID, scopeGroupID: nil)
    }

    /// Reorder within the Grouped subcolumn by dropping between items.
    /// Scope is defined by `scopeGroupID` (nil = ungrouped within Grouped, otherwise that group UUID).
    /// If the source is in a different scope (different group or ungrouped), it is moved into the target scope
    /// and inserted at the requested position. This also dissolves the previous group if it becomes a singleton.
    @discardableResult
    func reorderInGrouped(sourceID: UUID, beforeTargetID: UUID?, scopeGroupID: UUID?) -> Bool {
        return reorderSessionsInColumn(.grouped, sourceID: sourceID, beforeTargetID: beforeTargetID, scopeGroupID: scopeGroupID)
    }

    @discardableResult
    func reorderInAddTravel(sourceID: UUID, beforeTargetID: UUID?, scopeGroupID: UUID?) -> Bool {
        return reorderSessionsInColumn(.addTravel, sourceID: sourceID, beforeTargetID: beforeTargetID, scopeGroupID: scopeGroupID)
    }

    @discardableResult
    func reorderGroupInGroupedColumn(sourceGroupID: UUID, beforeTargetID: UUID?) -> Bool {
        Task {
            let grouped = _allSessions.filter { canonicalSessionStatusToken($0.status) == "grouped" }
            guard !grouped.isEmpty else { return }
            if beforeTargetID == sourceGroupID { return }

            var clusters = groupedClusters(from: grouped)
            sortGroupedClusters(&clusters)

            guard let sourceIndex = clusters.firstIndex(where: { $0.groupID == sourceGroupID }) else { return }
            let sourceCluster = clusters.remove(at: sourceIndex)

            let insertionIndex: Int
            if let beforeTargetID,
               let targetIndex = clusters.firstIndex(where: { $0.id == beforeTargetID }) {
                insertionIndex = targetIndex
            } else {
                insertionIndex = clusters.count
            }

            clusters.insert(sourceCluster, at: min(insertionIndex, clusters.count))
            let updates = groupedPositionUpdates(from: clusters)
            await applyGroupedPositionUpdates(updates)
            await fetchData()
            objectWillChange.send()
        }
        return true
    }

    private func reorderSessionsInColumn(
        _ column: KanbanCardData.BillingColumnType,
        sourceID: UUID,
        beforeTargetID: UUID?,
        scopeGroupID: UUID?
    ) -> Bool {
        Task {
            guard let source = await fetchSessionFromRepository(byID: sourceID),
                  let desiredStatus = statusString(for: column) else { return }
            if beforeTargetID == sourceID { return }

            let sourceStatusToken = canonicalSessionStatusToken(source.status)
            let sourceWasInGroupedColumn = sourceStatusToken == BillingStatus.grouped.rawValue
            if canonicalSessionStatusToken(source.status) != desiredStatus {
                // Use unified moveSession - skip grouping handling since we manage it below
                _ = await moveSession(sourceID, to: column, handleGrouping: false)
            }

            // Only the Grouped column supports persisted group scopes.
            let supportsGrouping = (column == .grouped)
            let previousGroup = source.groupID

            if supportsGrouping {
                let needsScopeChange: Bool = {
                    switch (scopeGroupID, previousGroup) {
                    case (nil, nil): return false
                    case let (a?, b?): return a != b
                    default: return true
                    }
                }()
                if needsScopeChange {
                    if let scopeGroupID {
                        let groupMembers = _allSessions.filter {
                            $0.groupID == scopeGroupID && canonicalSessionStatusToken($0.status) == desiredStatus
                        }
                        if let groupClientID = groupMembers.first?.clientId,
                           source.clientId != groupClientID {
                            return
                        }
                        try? await sessionsRepository.groupSessions([sourceID], groupId: scopeGroupID)
                    } else {
                        try? await sessionsRepository.ungroupSessions([sourceID])
                    }
                    if let previousGroup, previousGroup != scopeGroupID {
                        await dissolveGroupIfSingleton(groupID: previousGroup)
                    }
                }
            } else if source.groupID != nil {
                try? await sessionsRepository.ungroupSessions([sourceID])
                if let previousGroup {
                    await dissolveGroupIfSingleton(groupID: previousGroup)
                }
            }

            // Refresh to ensure scope/group changes are reflected before computing order.
            await fetchData()

            let reorderScopeGroupID = supportsGrouping ? scopeGroupID : nil
            var orderedIDs = orderedSessionIDs(
                status: desiredStatus,
                scopeGroupID: reorderScopeGroupID,
                supportsGrouping: supportsGrouping
            )
            orderedIDs.removeAll { $0 == sourceID }

            let insertionIndex: Int
            if let beforeTargetID,
               let targetIndex = orderedIDs.firstIndex(of: beforeTargetID) {
                insertionIndex = targetIndex
            } else {
                insertionIndex = orderedIDs.count
            }
            orderedIDs.insert(sourceID, at: min(insertionIndex, orderedIDs.count))

            try? await sessionsRepository.reorderSessions(orderedIDs, in: reorderScopeGroupID)

            if supportsGrouping && column == .grouped {
                await reindexGroupedScope(scopeGroupID)
                if let previousGroup, previousGroup != scopeGroupID {
                    await reindexGroupedScope(previousGroup)
                }
            } else if column != .grouped && (sourceWasInGroupedColumn || previousGroup != nil) {
                await reindexGroupedScope(previousGroup)
                await reindexGroupedScope(nil)
            }

            await fetchData()
            objectWillChange.send()
        }
        return true
    }

    private func orderedSessionIDs(
        status: String,
        scopeGroupID: UUID?,
        supportsGrouping: Bool
    ) -> [UUID] {
        _allSessions
            .filter { session in
                guard canonicalSessionStatusToken(session.status) == status else { return false }
                if supportsGrouping {
                    return session.groupID == scopeGroupID
                }
                return true
            }
            .sorted { lhs, rhs in
                if lhs.groupedPosition != rhs.groupedPosition {
                    return lhs.groupedPosition < rhs.groupedPosition
                }

                let leftStart = lhs.startTime ?? .distantFuture
                let rightStart = rhs.startTime ?? .distantFuture
                if leftStart != rightStart {
                    return leftStart < rightStart
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .map(\.id)
    }

    private struct GroupedCluster: Hashable {
        let id: UUID
        let groupID: UUID?
        let sessions: [Session]
        let sortPosition: Int32

        static func == (lhs: GroupedCluster, rhs: GroupedCluster) -> Bool {
            lhs.id == rhs.id && lhs.groupID == rhs.groupID && lhs.sortPosition == rhs.sortPosition && lhs.sessions == rhs.sessions
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(groupID)
            hasher.combine(sortPosition)
        }
    }

    private func groupedClusters(from sessions: [Session]) -> [GroupedCluster] {
        let grouped = sessions.filter { canonicalSessionStatusToken($0.status) == "grouped" }
        let groupedByID = Dictionary(grouping: grouped, by: { $0.groupID })
        var clusters: [GroupedCluster] = []

        for (groupID, members) in groupedByID {
            let orderedMembers = orderGroupedMembers(members)
            if let groupID {
                let minPosition = orderedMembers.map(\.groupedPosition).min() ?? 0
                clusters.append(
                    GroupedCluster(
                        id: groupID,
                        groupID: groupID,
                        sessions: orderedMembers,
                        sortPosition: minPosition
                    )
                )
            } else {
                for session in orderedMembers {
                    clusters.append(
                        GroupedCluster(
                            id: session.id,
                            groupID: nil,
                            sessions: [session],
                            sortPosition: session.groupedPosition
                        )
                    )
                }
            }
        }

        return clusters
    }

    private func sortGroupedClusters(_ clusters: inout [GroupedCluster]) {
        clusters.sort { lhs, rhs in
            if lhs.sortPosition != rhs.sortPosition {
                return lhs.sortPosition < rhs.sortPosition
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func groupedPositionUpdates(from clusters: [GroupedCluster]) -> [(UUID, Int32)] {
        var updates: [(UUID, Int32)] = []
        var next: Int32 = 0

        for cluster in clusters {
            for session in cluster.sessions {
                if session.groupedPosition != next {
                    updates.append((session.id, next))
                }
                next += 1
            }
        }

        return updates
    }

    private func applyGroupedPositionUpdates(_ updates: [(UUID, Int32)]) async {
        guard !updates.isEmpty else { return }
        for (sessionId, position) in updates {
            do {
                try await sessionsRepository.updateGroupedPosition(id: sessionId, position: position)
            } catch {
                print("❌ [BillingHubViewModel] Error updating grouped position: \(error)")
            }
        }
    }

    private func orderGroupedMembers(_ sessions: [Session]) -> [Session] {
        sessions.sorted { lhs, rhs in
            if lhs.groupedPosition != rhs.groupedPosition {
                return lhs.groupedPosition < rhs.groupedPosition
            }
            let leftStart = lhs.startTime ?? .distantFuture
            let rightStart = rhs.startTime ?? .distantFuture
            if leftStart != rightStart {
                return leftStart < rightStart
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    @discardableResult
    func reorderInvoices(in column: KanbanCardData.BillingColumnType, sourceID: UUID, beforeTargetID: UUID?) -> Bool {
        guard let targetStatus = invoiceStatusString(for: column) else { return false }
        guard _allInvoices.contains(where: { $0.id == sourceID }) else { return false }

        Task {
            guard let current = _allInvoices.first(where: { $0.id == sourceID }) else { return }
            let currentStatus = canonicalInvoiceStatusToken(current.status)

            if !invoiceStatusBelongsToColumn(currentStatus, column: column) {
                // Use unified moveInvoice for consistent validation and date clearing
                _ = await moveInvoice(sourceID, to: column)
            }

            await fetchData()

            guard let bucket = invoiceOrderBucket(forStatusToken: targetStatus) else { return }
            var orderedIDs = orderedInvoiceIDs(inBucket: bucket)
            orderedIDs.removeAll { $0 == sourceID }

            let insertionIndex: Int
            if let beforeTargetID,
               let targetIndex = orderedIDs.firstIndex(of: beforeTargetID) {
                insertionIndex = targetIndex
            } else {
                insertionIndex = orderedIDs.count
            }
            orderedIDs.insert(sourceID, at: min(insertionIndex, orderedIDs.count))

            invoiceOrderByStatus[bucket] = orderedIDs
            persistInvoiceOrder()

            await fetchData()
            objectWillChange.send()
        }
        return true
    }

    private func invoiceStatusString(for column: KanbanCardData.BillingColumnType) -> String? {
        switch column {
        case .reviewDrafts: return BillingStatus.reviewDrafts.rawValue
        case .readyToSend: return BillingStatus.readyToSend.rawValue
        case .pending: return BillingStatus.pending.rawValue
        case .received: return BillingStatus.received.rawValue
        default: return nil
        }
    }

    private func canonicalSessionStatusToken(_ status: String?) -> String? {
        guard let status else { return nil }

        let standardizedStatuses: Set<String> = [
            "scheduled",
            "completed",
            "cancelled",
            "no_show",
            "rescheduled",
            "grouped",
            "needs_travel",
            "review_draft",
            "ready_to_send",
            "pending",
            "received"
        ]

        guard standardizedStatuses.contains(status) else { return nil }
        return status
    }

    private func sharedClientID(for sessionIDs: [UUID]) async -> UUID? {
        var sessions: [Session] = []
        sessions.reserveCapacity(sessionIDs.count)

        for sessionID in sessionIDs {
            if let cached = _allSessions.first(where: { $0.id == sessionID }) {
                sessions.append(cached)
                continue
            }
            if let fetched = try? await sessionsRepository.fetch(byId: sessionID) {
                sessions.append(fetched)
            }
        }

        guard sessions.count == sessionIDs.count else { return nil }
        guard let firstClientID = sessions.first?.clientId else { return nil }
        guard sessions.allSatisfy({ $0.clientId == firstClientID }) else { return nil }
        return firstClientID
    }

    private func canonicalInvoiceStatusToken(_ status: String?) -> String? {
        guard let status else { return nil }
        let standardizedStatuses: Set<String> = [
            "review_draft",
            "ready_to_send",
            "pending",
            "received",
            "overdue",
            "cancelled",
            "voided"
        ]
        return standardizedStatuses.contains(status) ? status : nil
    }

    func fetchComplianceChecklist(for invoiceId: UUID) async -> ComplianceValidationResult? {
        guard complianceBlockingEnabled, let complianceValidator else { return nil }
        return try? await complianceValidator.validateInvoiceTransition(invoiceId: invoiceId, action: .statusChange)
    }

    func fetchSupportLog(for sessionId: UUID) async -> SupportLog? {
        guard let supportLogRepository else { return nil }
        return try? await supportLogRepository.fetchBySession(sessionId).first
    }

    func upsertSupportLog(sessionId: UUID, draft: SupportLogDraft) async throws -> SupportLog {
        guard let supportLogRepository else {
            throw RepositoryError.validationFailed(message: "Support log repository is unavailable.")
        }
        guard let session = try await sessionsRepository.fetch(byId: sessionId),
              let clientId = session.clientId else {
            throw RepositoryError.validationFailed(message: "Session client is required to save a support log.")
        }

        let existing = try await supportLogRepository.fetchBySession(sessionId).first
        let quantityHours = max(draft.deliveredTo.timeIntervalSince(draft.deliveredFrom), 0) / 3600.0

        let log = SupportLog(
            id: existing?.id ?? UUID(),
            clientId: clientId,
            sessionId: sessionId,
            participantName: draft.participantName,
            participantNdisNumber: draft.participantNdisNumber,
            supportItemNumber: draft.supportItemNumber,
            serviceDescription: draft.serviceDescription,
            location: draft.location,
            deliveredFrom: draft.deliveredFrom,
            deliveredTo: draft.deliveredTo,
            quantityHours: quantityHours > 0 ? quantityHours : draft.quantityHours,
            deliveredBy: draft.deliveredBy,
            attestedBy: draft.attestedBy,
            attestedAt: draft.attestedAt,
            signatureMethod: draft.signatureMethod,
            signedBy: draft.signedBy,
            signedAt: draft.signedAt,
            cancellationReasonCode: draft.cancellationReasonCode,
            notes: draft.notes
        )

        if existing != nil {
            return try await supportLogRepository.update(log)
        }
        return try await supportLogRepository.create(log)
    }

    private func validateInvoiceTransitionIfNeeded(
        invoice: Invoice,
        targetStatus: String,
        action: ComplianceAction
    ) async -> ComplianceValidationResult? {
        guard complianceBlockingEnabled, let complianceValidator else { return nil }
        guard isForwardInvoiceTransition(from: invoice.status, to: targetStatus) else { return nil }
        do {
            let result = try await complianceValidator.validateInvoiceTransition(
                invoiceId: invoice.id,
                action: action,
                targetStatus: targetStatus
            )
            let adjustedResult = applyDebugBlockerDowngradeIfNeeded(
                result,
                invoiceId: invoice.id,
                action: action,
                targetStatus: targetStatus
            )
            logComplianceValidationResult(
                adjustedResult,
                invoiceId: invoice.id,
                action: action,
                targetStatus: targetStatus
            )
            return adjustedResult
        } catch {
            complianceLogger.error(
                "validation_failed action=\(action.rawValue, privacy: .public) invoice_id=\(invoice.id.uuidString, privacy: .public) target_status=\(targetStatus, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            return ComplianceValidationResult(
                blockers: [
                    ComplianceIssue(
                        id: "COMPLIANCE-VAL-001",
                        severity: .blocker,
                        message: "Unable to validate compliance: \(error.localizedDescription)",
                        entityId: invoice.id
                    )
                ]
            )
        }
    }

    private func isForwardInvoiceTransition(from current: String, to target: String) -> Bool {
        guard let currentRank = workflowRank(for: canonicalInvoiceStatusToken(current)),
              let targetRank = workflowRank(for: canonicalInvoiceStatusToken(target)) else {
            return false
        }
        return targetRank > currentRank
    }

    private func workflowRank(for statusToken: String?) -> Int? {
        switch statusToken {
        case BillingStatus.reviewDrafts.rawValue:
            return 0
        case BillingStatus.readyToSend.rawValue:
            return 1
        case BillingStatus.pending.rawValue, "overdue":
            return 2
        case BillingStatus.received.rawValue:
            return 3
        default:
            return nil
        }
    }

    private func blockerSummary(for result: ComplianceValidationResult) -> String {
        let messages = result.blockers.prefix(2).map(\.message).joined(separator: " ")
        return "Blocked by compliance (\(result.blockers.count)): \(messages)"
    }

    private func warningSummary(for result: ComplianceValidationResult) -> String {
        let messages = result.warnings.prefix(2).map(\.message).joined(separator: " ")
        return "Compliance warnings (\(result.warnings.count)): \(messages)"
    }

    private var complianceBlockerDowngradeEnabled: Bool {
#if DEBUG
        userDefaults.bool(forKey: Self.complianceBlockerDowngradeKey)
#else
        false
#endif
    }

    private func applyDebugBlockerDowngradeIfNeeded(
        _ result: ComplianceValidationResult,
        invoiceId: UUID,
        action: ComplianceAction,
        targetStatus: String
    ) -> ComplianceValidationResult {
        guard complianceBlockerDowngradeEnabled, !result.blockers.isEmpty else { return result }
        let downgradedWarnings = result.blockers.map {
            ComplianceIssue(
                id: $0.id,
                severity: .warning,
                message: $0.message,
                entityId: $0.entityId,
                field: $0.field
            )
        }
        complianceLogger.warning(
            "debug_downgrade_enabled action=\(action.rawValue, privacy: .public) invoice_id=\(invoiceId.uuidString, privacy: .public) target_status=\(targetStatus, privacy: .public) downgraded_blocker_count=\(result.blockers.count, privacy: .public)"
        )
        return ComplianceValidationResult(
            warnings: result.warnings + downgradedWarnings,
            blockers: []
        )
    }

    private func logComplianceValidationResult(
        _ result: ComplianceValidationResult,
        invoiceId: UUID,
        action: ComplianceAction,
        targetStatus: String
    ) {
        if !result.blockers.isEmpty {
            let ruleIds = result.blockers.map(\.id).joined(separator: ",")
            let issueEntityIds = result.blockers.compactMap(\.entityId).map(\.uuidString).joined(separator: ",")
            complianceLogger.error(
                "block_event action=\(action.rawValue, privacy: .public) invoice_id=\(invoiceId.uuidString, privacy: .public) target_status=\(targetStatus, privacy: .public) blocker_count=\(result.blockers.count, privacy: .public) rule_ids=\(ruleIds, privacy: .public) issue_entity_ids=\(issueEntityIds, privacy: .public)"
            )
        }

        if !result.warnings.isEmpty {
            let ruleIds = result.warnings.map(\.id).joined(separator: ",")
            complianceLogger.info(
                "warning_event action=\(action.rawValue, privacy: .public) invoice_id=\(invoiceId.uuidString, privacy: .public) target_status=\(targetStatus, privacy: .public) warning_count=\(result.warnings.count, privacy: .public) rule_ids=\(ruleIds, privacy: .public)"
            )
        }
    }

    private static func loadInvoiceOrder(from userDefaults: UserDefaults) -> [String: [UUID]] {
        guard let persisted = userDefaults.dictionary(forKey: invoiceOrderStorageKey) as? [String: [String]] else {
            return [:]
        }

        return persisted.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = entry.value.compactMap(UUID.init(uuidString:))
        }
    }

    private func persistInvoiceOrder() {
        let serialized = invoiceOrderByStatus.reduce(into: [String: [String]]()) { partialResult, entry in
            partialResult[entry.key] = entry.value.map(\.uuidString)
        }
        userDefaults.set(serialized, forKey: Self.invoiceOrderStorageKey)
    }

    private func invoiceOrderBucket(for invoice: Invoice) -> String? {
        invoiceOrderBucket(forStatusToken: canonicalInvoiceStatusToken(invoice.status))
    }

    private func invoiceOrderBucket(forStatusToken token: String?) -> String? {
        guard let token else { return nil }
        switch token {
        case BillingStatus.reviewDrafts.rawValue:
            return BillingStatus.reviewDrafts.rawValue
        case BillingStatus.readyToSend.rawValue:
            return BillingStatus.readyToSend.rawValue
        case BillingStatus.pending.rawValue, "overdue":
            return BillingStatus.pending.rawValue
        case BillingStatus.received.rawValue:
            return BillingStatus.received.rawValue
        default:
            return nil
        }
    }

    private func invoiceStatusBelongsToColumn(_ statusToken: String?, column: KanbanCardData.BillingColumnType) -> Bool {
        switch column {
        case .reviewDrafts:
            return statusToken == BillingStatus.reviewDrafts.rawValue
        case .readyToSend:
            return statusToken == BillingStatus.readyToSend.rawValue
        case .pending:
            // Keep overdue invoices in Pending without normalizing the underlying status token.
            return statusToken == BillingStatus.pending.rawValue || statusToken == "overdue"
        case .received:
            return statusToken == BillingStatus.received.rawValue
        default:
            return false
        }
    }

    private func orderedInvoiceIDs(inBucket bucket: String) -> [UUID] {
        let invoiceIDs = _allInvoices
            .filter { invoiceOrderBucket(for: $0) == bucket }
            .map(\.id)
        let preserved = invoiceOrderByStatus[bucket, default: []].filter { invoiceIDs.contains($0) }
        let missing = invoiceIDs.filter { !preserved.contains($0) }
        return preserved + missing
    }

    private func invoiceOrderRanks(for bucket: String) -> [UUID: Int] {
        let ids = invoiceOrderByStatus[bucket, default: []]
        return Dictionary(uniqueKeysWithValues: ids.enumerated().map { index, id in (id, index) })
    }

    private func synchronizeInvoiceOrderBuckets() {
        let supportedBuckets: Set<String> = [
            BillingStatus.reviewDrafts.rawValue,
            BillingStatus.readyToSend.rawValue,
            BillingStatus.pending.rawValue,
            BillingStatus.received.rawValue
        ]
        var updated = invoiceOrderByStatus

        for bucket in supportedBuckets {
            let bucketInvoiceIDs = _allInvoices
                .filter { invoiceOrderBucket(for: $0) == bucket }
                .sorted { $0.issueDate > $1.issueDate }
                .map(\.id)

            let existing = updated[bucket, default: []].filter { bucketInvoiceIDs.contains($0) }
            let missing = bucketInvoiceIDs.filter { !existing.contains($0) }
            let merged = existing + missing

            if merged.isEmpty {
                updated.removeValue(forKey: bucket)
            } else {
                updated[bucket] = merged
            }
        }

        for bucket in updated.keys where !supportedBuckets.contains(bucket) {
            updated.removeValue(forKey: bucket)
        }

        if updated != invoiceOrderByStatus {
            invoiceOrderByStatus = updated
            persistInvoiceOrder()
        }
    }

    private struct InvoiceWorkflowSnapshot: Hashable {
        let id: UUID
        let status: String
        let sentDate: Date?
        let paidDate: Date?
    }

    private struct BulkUndoAction: Hashable {
        let label: String
        let snapshots: [InvoiceWorkflowSnapshot]
    }

    private struct GroupedDraftBatch: Hashable {
        let key: String
        let clientID: UUID
        let sessionIDs: [UUID]
    }

    private func groupedDraftBatches() -> [GroupedDraftBatch] {
        var buckets: [String: (clientID: UUID, sessionIDs: [UUID])] = [:]
        let candidateSessions = filteredSessions()

        for session in candidateSessions where canonicalSessionStatusToken(session.status) == "grouped" {
            guard let clientID = session.clientId else { continue }
            let key = session.groupID?.uuidString ?? "client:\(clientID.uuidString)"
            if buckets[key] == nil {
                buckets[key] = (clientID, [])
            }
            buckets[key]?.sessionIDs.append(session.id)
        }

        return buckets.compactMap { key, value in
            let uniqueIDs = uniqueIDsPreservingOrder(value.sessionIDs)
            guard !uniqueIDs.isEmpty else { return nil }
            return GroupedDraftBatch(key: key, clientID: value.clientID, sessionIDs: uniqueIDs)
        }
        .sorted { lhs, rhs in
            if lhs.sessionIDs.count == rhs.sessionIDs.count {
                return lhs.key < rhs.key
            }
            return lhs.sessionIDs.count > rhs.sessionIDs.count
        }
    }

    private func createInvoiceAndTransitionSessions(sessionIds: [UUID], clientId: UUID) async throws -> NDISBillingReport {
        // 1. Fetch Client
        guard let client = try await clientsRepository.fetch(by: clientId) else {
            throw MoveResult.notFound // Or a specific error
        }
        
        // 2. Fetch Sessions
        var sessions: [Session] = []
        for id in sessionIds {
            if let session = try await sessionsRepository.fetch(byId: id) {
                sessions.append(session)
            }
        }
        
        guard !sessions.isEmpty else {
             throw MoveResult.notFound
        }
        
        // 3. Generate NDIS Invoice (uses rich TravelCharge data internally)
        let report = try await ndisBillingIntegrationService.generateNDISInvoice(for: sessions, client: client)
        
        // 4. Ungroup and Transition Sessions (Only for successful ones)
        if let invoice = report.invoice {
            // Identify successful session IDs
            let failedIDs = Set(report.failedSessions.map { $0.sessionId })
            let successfulIDs = sessionIds.filter { !failedIDs.contains($0) }
            
            try await sessionsRepository.ungroupSessions(successfulIDs)
            for sessionId in successfulIDs {
                try await sessionsRepository.updateBillingStatus(id: sessionId, status: .reviewDrafts)
            }
            
            InvoiceChangePublisher.shared.notifyChange(invoiceId: invoice.id)
        }
        
        return report
    }

    private func captureSnapshot(for invoice: Invoice) -> InvoiceWorkflowSnapshot {
        InvoiceWorkflowSnapshot(
            id: invoice.id,
            status: invoice.status,
            sentDate: invoice.sentDate,
            paidDate: invoice.paidDate
        )
    }

    private func parseRecipients(_ raw: String) -> [String] {
        raw
            .split { $0 == "," || $0 == ";" || $0.isWhitespace }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.contains("@") }
    }

    private func uniqueIDsPreservingOrder(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        var result: [UUID] = []
        result.reserveCapacity(ids.count)

        for id in ids where seen.insert(id).inserted {
            result.append(id)
        }
        return result
    }

    private func composeEmail(subject: String, recipients: [String], body: String, attachments: [URL]) -> Bool {
        guard let sharingService = NSSharingService(named: .composeEmail) else { return false }
        emailSharingService = sharingService
        sharingService.subject = subject
        sharingService.recipients = recipients

        var items: [Any] = [body]
        items.append(contentsOf: attachments)
        sharingService.perform(withItems: items)
        return true
    }

    private func makeReceiptPDFData(for invoice: Invoice) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 points
        let mutableData = NSMutableData()

        guard let consumer = CGDataConsumer(data: mutableData as CFMutableData) else { return nil }
        var mediaBox = pageRect
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        context.beginPDFPage(nil)
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = invoice.currencyCode
        let amount = formatter.string(from: NSNumber(value: invoice.totalAmount))
            ?? String(format: "%.2f", invoice.totalAmount)

        let issueDate = invoice.issueDate.formatted(date: .abbreviated, time: .omitted)
        let dueDate = invoice.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "N/A"
        let paidDate = invoice.paidDate?.formatted(date: .abbreviated, time: .omitted) ?? "N/A"

        let body = """
        Receipt

        Invoice Number: \(invoice.invoiceNumber)
        Client: \(invoice.clientName ?? "Unknown Client")
        Status: \(invoice.status)
        Amount: \(amount)
        Issue Date: \(issueDate)
        Due Date: \(dueDate)
        Paid Date: \(paidDate)
        """

        let attributed = NSAttributedString(
            string: body,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.black
            ]
        )

        let textPath = CGMutablePath()
        textPath.addRect(CGRect(x: 48, y: 48, width: pageRect.width - 96, height: pageRect.height - 96))
        let frameSetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: attributed.length), textPath, nil)
        CTFrameDraw(frame, context)

        context.endPDFPage()
        context.closePDF()

        return mutableData as Data
    }

    // MARK: - Travel Helpers

    private struct TravelRateInfo {
        let rate: Double
        let unit: String?
    }

    private struct TravelSuggestion {
        let distanceKilometres: Double?
        let timeMinutes: Double?
    }

    private func travelRateInfo(for session: Session) -> TravelRateInfo? {
        guard let clientId = session.clientId else { return nil }
        
        // Look up travel services from cached client services
        guard let clientServices = _clientServicesCache[clientId] else { return nil }
        
        // Find a travel-related service (case-insensitive match)
        let travelService = clientServices.first { service in
            let name = service.serviceName.lowercased()
            return name.contains("travel") || name.contains("transport") || name.contains("km")
        }
        
        if let travelService = travelService {
            return TravelRateInfo(rate: travelService.rate, unit: travelService.unit)
        }
        
        // Fallback: No travel service configured for this client
        return nil
    }

    private func travelSuggestion(for session: Session) -> TravelSuggestion {
        var suggestion = TravelSuggestion(distanceKilometres: nil, timeMinutes: nil)

        if let previous = previousSession(before: session) {
            let metrics = travelMetrics(between: previous, and: session)
            if suggestion.distanceKilometres == nil {
                suggestion = TravelSuggestion(
                    distanceKilometres: metrics.distance,
                    timeMinutes: suggestion.timeMinutes
                )
            }
            if suggestion.timeMinutes == nil {
                suggestion = TravelSuggestion(
                    distanceKilometres: suggestion.distanceKilometres,
                    timeMinutes: metrics.minutes
                )
            }
        }

        if (suggestion.distanceKilometres == nil || suggestion.timeMinutes == nil),
           let next = nextSession(after: session) {
            let metrics = travelMetrics(between: session, and: next)
            let distance = suggestion.distanceKilometres ?? metrics.distance
            let minutes = suggestion.timeMinutes ?? metrics.minutes
            suggestion = TravelSuggestion(distanceKilometres: distance, timeMinutes: minutes)
        }

        return suggestion
    }

    private func previousSession(before session: Session) -> Session? {
        guard let sessionStart = session.startTime else { return nil }
        let candidates = _allSessions
            .filter { $0.id != session.id && ($0.endTime ?? $0.startTime ?? .distantPast) <= sessionStart }
            .sorted { ($0.endTime ?? $0.startTime ?? .distantPast) > ($1.endTime ?? $1.startTime ?? .distantPast) }
        return candidates.first
    }

    private func nextSession(after session: Session) -> Session? {
        guard let sessionEnd = session.endTime ?? session.startTime else { return nil }
        let candidates = _allSessions
            .filter { $0.id != session.id && ($0.startTime ?? .distantFuture) >= sessionEnd }
            .sorted { ($0.startTime ?? .distantFuture) < ($1.startTime ?? .distantFuture) }
        return candidates.first
    }

    private func travelMetrics(between first: Session, and second: Session) -> (distance: Double?, minutes: Double?) {
        let distance = distanceKilometres(between: first, and: second)
        var minutes: Double? = nil

        if let firstEnd = first.endTime ?? first.startTime,
           let secondStart = second.startTime {
            let interval = secondStart.timeIntervalSince(firstEnd) / 60.0
            if interval > 0, interval <= (6 * 60) { // ignore gaps larger than 6 hours
                minutes = interval
            }
        }

        return (distance, minutes)
    }

    private func distanceKilometres(between first: Session, and second: Session) -> Double? {
        guard let firstCoordinate = coordinate(for: first),
              let secondCoordinate = coordinate(for: second) else { return nil }

        let firstLocation = CLLocation(latitude: firstCoordinate.latitude, longitude: firstCoordinate.longitude)
        let secondLocation = CLLocation(latitude: secondCoordinate.latitude, longitude: secondCoordinate.longitude)
        let metres = firstLocation.distance(from: secondLocation)
        guard metres.isFinite else { return nil }
        return metres / 1000.0
    }

    private func coordinate(for session: Session) -> CLLocationCoordinate2D? {
        let lat = session.sessionLatitude
        let lon = session.sessionLongitude
        if lat != 0.0 || lon != 0.0 {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        // Note: Address coordinate lookup would require fetching Address entity
        // For now, only use session coordinates
        return nil
    }
    // MARK: - Panel Actions

    /// Updates the assigned service for a session
    /// Calculates NDIS travel charge breakdown for UI preview
    /// - Parameters:
    ///   - sessionId: The session ID to calculate travel for
    ///   - distance: Distance in kilometers
    ///   - time: Time in minutes
    ///   - tolls: Toll costs
    ///   - parking: Parking costs
    ///   - chargeType: The type of charge (standard, labour, non-labour, activity-based)
    ///   - vehicleType: Vehicle type for activity-based charges
    ///   - participantCount: Number of participants for cost splitting
    ///   - splitCosts: Whether to split costs among participants
    /// - Returns: The calculated breakdown or nil if session not found
    func calculateTravelBreakdown(
        sessionId: UUID,
        distance: Double,
        time: Double,
        tolls: Double,
        parking: Double = 0,
        chargeType: String,
        vehicleType: String?,
        participantCount: Int = 1,
        splitCosts: Bool = false
    ) -> NDISTravelChargeBreakdown? {
        guard let session = fetchSession(byID: sessionId) else { return nil }
        
        let providerType = inferProviderType(for: session)
        let hourlyRate = session.assignedRate ?? 0.0
        let effectiveParticipants = splitCosts ? max(participantCount, 1) : 1
        
        return NDISTravelChargeCalculator.calculate(
            providerType: providerType,
            hourlyRate: hourlyRate,
            mmmZoneDescriptor: nil,
            minutesTravelled: time,
            kilometresTravelled: distance,
            ancillaryCosts: tolls + parking,
            participantCount: effectiveParticipants
        )
    }
    
    /// Infers the NDIS provider type from a session's service
    func inferProviderType(for session: Session) -> TravelChargeProviderType {
        if let serviceName = session.assignedServiceName {
            return NDISTravelChargeCalculator.inferredProviderType(
                itemName: serviceName,
                itemDescription: nil,
                ndisCode: nil
            )
        }
        return .dsw
    }

    /// Adds travel details to a session using the rich TravelCharge entity
    func addTravelToSession(
        id: UUID,
        distance: Double,
        time: Double,
        tolls: Double,
        parking: Double = 0,
        chargeType: String = "standard",
        vehicleType: String? = nil,
        travelDirection: String = "before",
        participantCount: Int = 1,
        splitCosts: Bool = false
    ) async {
        guard let session = fetchSession(byID: id), let clientId = session.clientId else { return }
        
        let providerType = inferProviderType(for: session)
        let effectiveParticipants = splitCosts ? max(participantCount, 1) : 1
        
        // Calculate the charge breakdown
        let breakdown = NDISTravelChargeCalculator.calculate(
            providerType: providerType,
            hourlyRate: session.assignedRate ?? 0.0,
            mmmZoneDescriptor: nil,
            minutesTravelled: time,
            kilometresTravelled: distance,
            ancillaryCosts: tolls + parking,
            participantCount: effectiveParticipants
        )
        
        // Determine the amount based on charge type
        let amount: Double
        switch chargeType.lowercased() {
        case "labour":
            amount = breakdown.labourPerParticipant
        case "non-labour", "nonlabour":
            amount = breakdown.nonLabourPerParticipant
        case "activity-based", "activitybased":
            amount = breakdown.totalPerParticipant
        default:
            amount = breakdown.totalPerParticipant
        }
        
        // Create the TravelCharge domain object
        // Note: TravelTime is stored in seconds (TimeInterval)
        // Note: Parking and Tolls are stored as the participant's SHARE if split costs are enabled
        let travelTimeSeconds = time * 60.0
        
        let parkingShare = splitCosts ? (parking / Double(effectiveParticipants)) : parking
        let tollShare = splitCosts ? (tolls / Double(effectiveParticipants)) : tolls
        
        let travelCharge = TravelCharge(
            id: UUID(),
            sessionId: session.id,
            clientId: clientId,
            serviceId: session.clientServiceId,
            amount: amount,
            distance: distance,
            travelTime: travelTimeSeconds,
            fromAddress: nil,
            toAddress: nil,
            status: .pending,
            chargeType: chargeType,
            travelDirection: travelDirection,
            vehicleType: vehicleType ?? "standard",
            participantCount: participantCount,
            splitCosts: splitCosts,
            parkingCost: parkingShare,
            tollCost: tollShare,
            createdDate: Date(),
            lastModifiedDate: Date(),
            notes: "Created via Billing Hub"
        )
        
        do {
            _ = try await travelChargeRepository.create(travelCharge)
            
            // Update session cache fields with the same split/unit logic to match
            let updatedSession = session.copy(
                travelDistanceKM: distance,
                travelTimeMinutes: time, // Keep as minutes for legacy compatibility
                travelTollsAmount: tollShare + parkingShare // Update with split amount
            )
            _ = try await sessionsRepository.update(updatedSession)
            
            await fetchData()
            print("✅ [BillingHubViewModel] Added TravelCharge and updated Session for \(session.title)")
        } catch {
            print("❌ [BillingHubViewModel] Error adding travel to session: \(error)")
        }
    }
}





// MARK: - Session Copy Extension
extension Session {
    func copy(
        title: String? = nil,
        status: String? = nil,
        clientServiceId: UUID? = nil,
        assignedServiceName: String? = nil,
        assignedRate: Double? = nil,
        travelDistanceKM: Double? = nil,
        travelTimeMinutes: Double? = nil,
        travelTollsAmount: Double? = nil,
        travelCharges: [TravelCharge] = []
    ) -> Session {
        Session(
            id: id,
            title: title ?? self.title,
            startTime: startTime,
            endTime: endTime,
            isAllDay: isAllDay,
            location: location,
            notes: notes,
            status: status ?? self.status,
            isTravel: isTravel,
            isDetached: isDetached,
            occurrenceDate: occurrenceDate,
            clientId: clientId,
            clientServiceId: clientServiceId ?? self.clientServiceId,
            addressId: addressId,
            groupID: groupID,
            groupedPosition: groupedPosition,
            eventIdentifier: eventIdentifier,
            eventExternalIdentifier: eventExternalIdentifier,
            calendarIdentifier: calendarIdentifier,
            lastModifiedDate: Date(),
            lastSyncTag: lastSyncTag,
            recurrenceRuleData: recurrenceRuleData,
            attendeesCount: attendeesCount,
            derivedFromEKEventID: derivedFromEKEventID,
            googleColorId: googleColorId,
            sessionLatitude: sessionLatitude,
            sessionLongitude: sessionLongitude,
            assignedServiceName: assignedServiceName ?? self.assignedServiceName,
            assignedRate: assignedRate ?? self.assignedRate,
            travelDistanceKM: travelDistanceKM ?? self.travelDistanceKM,
            travelTimeMinutes: travelTimeMinutes ?? self.travelTimeMinutes,
            travelTollsAmount: travelTollsAmount ?? self.travelTollsAmount,
            travelCharges: travelCharges
        )
    }
}
