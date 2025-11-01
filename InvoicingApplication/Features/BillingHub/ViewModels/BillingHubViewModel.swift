//
//  BillingHubViewModel.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class BillingHubViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedSession: SessionEntity?
    @Published var selectedInvoice: InvoiceEntity?
    @Published var searchText: String = ""
    @Published var selectedClientID: UUID? = nil
    @Published private(set) var lastUpdated: Date = Date()

    // Cached properties for sessions and invoices
    @Published private var _allSessions: [SessionEntity] = []
    @Published private var _allInvoices: [InvoiceEntity] = []

    // MARK: - Dependencies
    private let modelContext: ModelContext
    // Debounced persistence to keep drops snappy
    private var pendingSaveTask: Task<Void, Never>? = nil
    
    // MARK: - Computed Properties
    
    /// All sessions grouped by billing status, mapped to KanbanCardData
    var sessionsByStatus: [KanbanCardData.BillingColumnType: [KanbanCardData]] {
        // Map filtered sessions to KanbanCardData once
        let filteredSessions = filteredSessionEntities()
        let kanbanCards = filteredSessions.compactMap(mapSessionToKanbanCard)

        // Group by columnType
        var dict = Dictionary(grouping: kanbanCards, by: { $0.columnType })

        // Sort the Grouped column by a stable groupedPosition stored on SessionEntity
        if var groupedCards = dict[.grouped] {
            // Build lookup: sessionID -> groupedPosition
            var positions: [UUID: Int32] = [:]
            for session in _allSessions where session.status == "grouped" {
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
            dict[.grouped] = groupedCards
        }
        return dict
    }
    
    /// All invoices grouped by billing status, mapped to KanbanCardData
    var invoicesByStatus: [KanbanCardData.BillingColumnType: [KanbanCardData]] {
        let invoices = filteredInvoiceEntities()
        let kanbanCards = invoices.compactMap(mapInvoiceToKanbanCard)

        return Dictionary(grouping: kanbanCards, by: { $0.columnType })
    }

    /// Filtered sessions based on search and client selection, mapped to KanbanCardData
    var filteredSessions: [KanbanCardData] {
        filteredSessionEntities().compactMap(mapSessionToKanbanCard)
    }

    struct ClientSummary: Identifiable, Hashable {
        let id: UUID
        let name: String
        let colorHex: String?
    }

    var clientSummaries: [ClientSummary] {
        var seen = Set<UUID>()
        var summaries: [ClientSummary] = []

        for session in _allSessions {
            guard let client = session.client else { continue }
            if seen.insert(client.id).inserted {
                summaries.append(ClientSummary(id: client.id, name: client.fullName, colorHex: client.colorHex))
            }
        }

        for invoice in _allInvoices {
            guard let client = invoice.client else { continue }
            if seen.insert(client.id).inserted {
                summaries.append(ClientSummary(id: client.id, name: client.fullName, colorHex: client.colorHex))
            }
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
    
    // MARK: - Initialization
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Initial fetch when ViewModel is created
        fetchData()
    }
    
    // MARK: - Public Methods
    
    /// Updates the billing status of a session
    func updateSessionStatus(_ session: SessionEntity, to status: KanbanCardData.BillingColumnType) {
        // Update session properties based on status
        switch status {
        case .completed:
            session.status = "completed"
        case .grouped:
            session.status = "grouped"
        case .assignServices:
            session.status = "needs_services"
        case .addTravel:
            session.status = "needs_travel"
        case .reviewDrafts:
            session.status = "review_draft"
        case .readyToSend:
            session.status = "ready_to_send"
        case .pending:
            session.status = "pending"
        case .received:
            session.status = "received"
        }
        
        try? modelContext.save()
        fetchData() // Refresh data after update
    }
    
    /// Updates the billing status of an invoice
    func updateInvoiceStatus(_ invoice: InvoiceEntity, to status: KanbanCardData.BillingColumnType) {
        switch status {
        case .reviewDrafts:
            invoice.status = "draft"
        case .readyToSend:
            invoice.status = "ready"
        case .pending:
            invoice.status = "sent"
        case .received:
            invoice.status = "paid"
        default:
            break
        }
        
        try? modelContext.save()
        fetchData() // Refresh data after update
    }

    func selectClient(withID id: UUID?) {
        selectedClientID = id
    }

    func clearFilters() {
        searchText = ""
        selectedClientID = nil
    }

    func refresh() {
        fetchData()
    }
    
    /// Creates a new invoice from grouped sessions
    func createInvoiceFromSessions(_ sessions: [SessionEntity]) {
        guard let firstSession = sessions.first,
              let client = firstSession.client else { return }
        
        let invoice = InvoiceEntity(
            id: UUID(),
            invoiceNumber: generateInvoiceNumber()
        )
        invoice.client = client
        
        // Set invoice properties
        invoice.issueDate = Date()
        invoice.dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        invoice.status = "draft"
        
        // Add invoice items for each session
        for session in sessions {
            if let clientService = session.clientService {
                let invoiceItem = InvoiceItemEntity(
                    id: UUID(),
                    itemDescription: session.title
                )
                invoiceItem.invoice = invoice
                invoiceItem.clientService = clientService
                invoiceItem.session = session
                invoiceItem.quantity = 1.0
                invoiceItem.rate = clientService.rate
                
                invoice.items.append(invoiceItem)
            }
        }
        
        // Calculate total
        invoice.totalAmount = invoice.items.reduce(0) { $0 + ($1.quantity * $1.rate) }
        
        modelContext.insert(invoice)
        try? modelContext.save()
        
        // Update session statuses
        for session in sessions {
            updateSessionStatus(session, to: .reviewDrafts)
        }
        fetchData() // Refresh data after creating invoice
    }
    
    /// Groups sessions for billing
    func groupSessions(_ sessions: [SessionEntity]) {
        for session in sessions {
            updateSessionStatus(session, to: .grouped)
        }
        fetchData() // Refresh data after grouping sessions
    }
    
    /// Assigns services to sessions
    func assignServicesToSessions(_ sessions: [SessionEntity]) {
        for session in sessions {
            updateSessionStatus(session, to: .assignServices)
        }
        fetchData() // Refresh data after assigning services
    }
    
    /// Adds travel charges to sessions
    func addTravelToSessions(_ sessions: [SessionEntity]) {
        for session in sessions {
            updateSessionStatus(session, to: .addTravel)
        }
        fetchData() // Refresh data after adding travel
    }
    
    // MARK: - Private Methods

    private func fetchData() {
        _allSessions = fetchAllSessionsInternal()
        _allInvoices = fetchAllInvoicesInternal()
        // Ensure grouped positions are normalized based on current order
        normalizeGroupedPositionsIfNeeded()
        lastUpdated = Date()
    }

    private func fetchAllSessionsInternal() -> [SessionEntity] {
        let descriptor = FetchDescriptor<SessionEntity>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func filteredSessionEntities() -> [SessionEntity] {
        var sessions = _allSessions

        if let selectedClientID {
            sessions = sessions.filter { $0.client?.id == selectedClientID }
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            sessions = sessions.filter { session in
                session.title.localizedCaseInsensitiveContains(trimmedQuery) ||
                session.client?.fullName.localizedCaseInsensitiveContains(trimmedQuery) == true ||
                session.clientService?.serviceName.localizedCaseInsensitiveContains(trimmedQuery) == true
            }
        }

        return sessions
    }

    /// Ensure every session in the Grouped column has a contiguous groupedPosition within its scope
    private func normalizeGroupedPositionsIfNeeded() {
        var nextIndexByScope: [UUID?: Int32] = [:]
        var changed = false
        for s in _allSessions where s.status == "grouped" {
            let scope = s.groupID
            let next = nextIndexByScope[scope] ?? 0
            if s.groupedPosition != next { s.groupedPosition = next; changed = true }
            nextIndexByScope[scope] = next + 1
        }
        if changed { scheduleSave() }
    }
    
    private func fetchAllInvoicesInternal() -> [InvoiceEntity] {
        let descriptor = FetchDescriptor<InvoiceEntity>(
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func filteredInvoiceEntities() -> [InvoiceEntity] {
        var invoices = _allInvoices

        if let selectedClientID {
            invoices = invoices.filter { $0.client?.id == selectedClientID }
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            invoices = invoices.filter { invoice in
                invoice.invoiceNumber.localizedCaseInsensitiveContains(trimmedQuery) ||
                invoice.client?.fullName.localizedCaseInsensitiveContains(trimmedQuery) == true ||
                invoice.clientName?.localizedCaseInsensitiveContains(trimmedQuery) == true ||
                invoice.items.contains { $0.itemDescription.localizedCaseInsensitiveContains(trimmedQuery) }
            }
        }

        return invoices
    }
    
    /// Maps a SessionEntity to a KanbanCardData
    private func mapSessionToKanbanCard(_ session: SessionEntity) -> KanbanCardData? {
        let sessionId = session.id
        
        let title = session.title
        let clientName = session.client?.fullName ?? "Unknown Client"
        let serviceName = session.clientService?.serviceName ?? "Unknown Service"
        let hasIssues = session.reviewItems.contains { $0.hasViolations }
        let date = session.startTime?.formatted(date: .abbreviated, time: .omitted) ?? ""
        let amount = String(format: "$%.2f", session.clientService?.rate ?? 0.0) // Reverted to show financial amount
        
        var duration: String = "-"
        var sessionEndTime: Date? // Declare a variable for sessionEndTime
        
        if let startTime = session.startTime, let endTime = session.endTime {
            let components = Calendar.current.dateComponents([.hour, .minute], from: startTime, to: endTime)
            if let hours = components.hour, let minutes = components.minute {
                let totalMinutes = Double(hours * 60 + minutes)
                if totalMinutes > 0 {
                    duration = String(format: "%.1f", totalMinutes / 60.0) + "h"
                }
            }
            sessionEndTime = endTime // Assign the actual endTime from session
        }
        
        let columnType = mapBillingStatus(for: session)
        let workflowStatus = KanbanCardData.workflowStatus(for: columnType)
        let accentColor = KanbanCardData.columnAccentColor(for: columnType)
        let priority = hasIssues ? Priority.high : .low // Simple priority for now
        
        let sessionCardData = SessionKanbanCardData(
            sessionId: sessionId,
            title: title,
            clientName: clientName,
            serviceName: serviceName,
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
    
    /// Maps an InvoiceEntity to a KanbanCardData
    private func mapInvoiceToKanbanCard(_ invoice: InvoiceEntity) -> KanbanCardData? {
        let invoiceId = invoice.id
        
        let title = invoice.invoiceNumber.isEmpty ? "Draft Invoice" : "\(invoice.invoiceNumber)"
        let clientName = invoice.client?.fullName ?? invoice.clientName ?? "Unknown Client"
        let serviceName = invoice.items.first?.itemDescription ?? "Multiple Services"
        let hasIssues = false // Invoices don't directly have 'issues' in the same way sessions do
        let date = invoice.issueDate.formatted(date: .abbreviated, time: .omitted)
        let amount = String(format: "$%.2f", invoice.totalAmount)
        let duration = "-"
        
        let columnType = mapBillingStatus(for: invoice)
        let workflowStatus = KanbanCardData.workflowStatus(for: columnType)
        let accentColor = KanbanCardData.columnAccentColor(for: columnType)
        let priority = Priority.medium // Default medium priority for invoices
        
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
            columnType: columnType
        )
        return .invoice(invoiceCardData)
    }
    
    private func mapBillingStatus(for session: SessionEntity) -> KanbanCardData.BillingColumnType {
        guard let status = session.status else { return .completed }
        
        switch status {
        case "completed":
            return .completed
        case "grouped":
            return .grouped
        case "needs_services":
            return .assignServices
        case "needs_travel":
            return .addTravel
        case "review_draft":
            return .reviewDrafts
        case "ready_to_send":
            return .readyToSend
        case "pending":
            return .pending
        case "received":
            return KanbanCardData.BillingColumnType.received
        default:
            return .completed
        }
    }
    
    private func mapBillingStatus(for invoice: InvoiceEntity) -> KanbanCardData.BillingColumnType {
        guard let status = invoice.status else { return .reviewDrafts }
        
        switch status {
        case "draft":
            return .reviewDrafts
        case "ready":
            return .readyToSend
        case "sent":
            return .pending
        case "paid":
            return .received
        default:
            return .reviewDrafts
        }
    }
    
    private func generateInvoiceNumber() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        
        let descriptor = FetchDescriptor<InvoiceEntity>()
        let count = (try? modelContext.fetch(descriptor).count) ?? 0
        
        return "INV-\(dateString)-\(String(format: "%04d", count + 1))"
    }
    
    // MARK: - Drag & Drop Helpers
    /// Returns a SessionEntity by its UUID if present in cache or persistent store
    func fetchSession(byID id: UUID) -> SessionEntity? {
        if let cached = _allSessions.first(where: { $0.id == id }) { return cached }
        let descriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    /// Moves a session into the Grouped column (no pairing)
    func moveSessionToGrouped(sessionID: UUID) {
        guard let session = fetchSession(byID: sessionID) else { return }
        updateSessionStatus(session, to: .grouped)
    }

    /// Pair/group two sessions together: attach source to the target's group, or create a new one
    func groupSessions(sourceID: UUID, targetID: UUID) {
        // Ignore self-drops
        guard sourceID != targetID else { return }
        guard let source = fetchSession(byID: sourceID), let target = fetchSession(byID: targetID) else { return }
        // Ensure both are in grouped status
        updateSessionStatus(target, to: .grouped)
        updateSessionStatus(source, to: .grouped)

        let previousGroup = source.groupID
        // Adopt target's group or create a new group
        var newGroupID: UUID
        if let existingGroup = target.groupID {
            newGroupID = existingGroup
            source.groupID = existingGroup
        } else {
            let newGroup = UUID()
            newGroupID = newGroup
            target.groupID = newGroup
            source.groupID = newGroup
        }
        try? modelContext.save()
        // If source left a previous group that now has only one member, dissolve it
        if let previousGroup, previousGroup != newGroupID {
            dissolveGroupIfSingleton(groupID: previousGroup)
        }
        fetchData()
    }

    /// Moves a session back to the Completed column
    func moveSessionToCompleted(sessionID: UUID) {
        guard let session = fetchSession(byID: sessionID) else { return }
        // Remove grouping when leaving Grouped
        let previousGroup = session.groupID
        session.groupID = nil
        updateSessionStatus(session, to: .completed)
        if let previousGroup {
            dissolveGroupIfSingleton(groupID: previousGroup)
        }
    }

    /// Handles dropping a session into the Grouped column background (not onto a card).
    /// If the session came from Completed, moves to grouped. If already grouped and part of a group,
    /// it gets ungrouped (groupID cleared). If that leaves its old group with a singleton, dissolve it.
    func dropIntoGroupedColumn(sessionID: UUID) {
        guard let session = fetchSession(byID: sessionID) else { return }
        let previousGroup = session.groupID

        // Ensure status is grouped
        if session.status != "grouped" {
            updateSessionStatus(session, to: .grouped)
        }

        // If part of a group, ungroup it
        if previousGroup != nil {
            session.groupID = nil
            try? modelContext.save()
            if let previousGroup { dissolveGroupIfSingleton(groupID: previousGroup) }
            fetchData()
        }
    }

    // MARK: - Group maintenance
    /// If a group's remaining membership is a single session, clear its groupID to dissolve the group.
    private func dissolveGroupIfSingleton(groupID: UUID) {
        // Prefer in-memory cache to avoid I/O during drag-drop
        let cached = _allSessions.filter { $0.groupID == groupID }
        if cached.count <= 1, let last = cached.first {
            last.groupID = nil
            scheduleSave()
            return
        }
        // Fallback to a lightweight fetch if cache is stale
        let descriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.groupID == groupID })
        if let sessions = try? modelContext.fetch(descriptor), sessions.count <= 1, let last = sessions.first {
            last.groupID = nil
            scheduleSave()
        }
    }

    // MARK: - Debounced save scheduler
    private func scheduleSave(delay: TimeInterval = 0.15) {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self else { return }
            try? self.modelContext.save()
        }
    }

    // MARK: - Smooth (no-refetch) operations for better animations
    /// Move to Completed without triggering a full refetch.
    func moveSessionToCompletedSmooth(sessionID: UUID) {
        guard let session = fetchSession(byID: sessionID) else { return }
        let previousGroup = session.groupID
        session.groupID = nil
        session.status = "completed"
        scheduleSave()
        if let previousGroup {
            dissolveGroupIfSingleton(groupID: previousGroup)
            reindexGroupedScope(previousGroup)
        } else {
            // Removing from ungrouped scope
            reindexGroupedScope(nil)
        }
        objectWillChange.send()
    }

    /// Background drop into Grouped without a full refetch. If already grouped and had a group, ungroup.
    func dropIntoGroupedColumnSmooth(sessionID: UUID) {
        guard let session = fetchSession(byID: sessionID) else { return }
        let previousGroup = session.groupID
        if session.status != "grouped" {
            session.status = "grouped"
        }
        if previousGroup != nil {
            session.groupID = nil
            scheduleSave()
            if let previousGroup {
                dissolveGroupIfSingleton(groupID: previousGroup)
                reindexGroupedScope(previousGroup)
            }
        } else {
            scheduleSave()
        }
        // Normalize ungrouped scope positions after insert
        reindexGroupedScope(nil)
        objectWillChange.send()
    }

    /// Group sessions together smoothly without a full refetch; adopts/creates target's group.
    func groupSessionsSmooth(sourceID: UUID, targetID: UUID) {
        guard sourceID != targetID else { return }
        guard let source = fetchSession(byID: sourceID), let target = fetchSession(byID: targetID) else { return }

        // Ensure both are grouped
        if target.status != "grouped" { target.status = "grouped" }
        if source.status != "grouped" { source.status = "grouped" }

        let previousGroup = source.groupID

        // Adopt or create group
        if let existingGroup = target.groupID {
            source.groupID = existingGroup
        } else {
            let newGroup = UUID()
            target.groupID = newGroup
            source.groupID = newGroup
        }
        scheduleSave()

        if let previousGroup, previousGroup != source.groupID {
            dissolveGroupIfSingleton(groupID: previousGroup)
        }
        // Normalize positions for both source and target scopes
        reindexGroupedScope(target.groupID)
        if let previousGroup { reindexGroupedScope(previousGroup) }
        objectWillChange.send()
    }

    /// Reassign contiguous groupedPosition values for a given Grouped scope (nil = ungrouped in Grouped)
    private func reindexGroupedScope(_ groupID: UUID?) {
        let items = _allSessions.filter { $0.status == "grouped" && $0.groupID == groupID }
        for (idx, s) in items.enumerated() {
            s.groupedPosition = Int32(idx)
        }
        scheduleSave()
    }

    // MARK: - Reordering within Preparing Sessions
    /// Reorder within the Completed subcolumn (and also handles moving in from other columns first).
    /// Places the `sourceID` session just before `beforeTargetID` if provided, otherwise appends to end of Completed.
    /// Returns true when the operation succeeded and UI should accept the drop.
    @discardableResult
    func reorderInCompleted(sourceID: UUID, beforeTargetID: UUID?) -> Bool {
        // Ensure source exists
        guard let source = fetchSession(byID: sourceID) else { return false }

        // If source isn't completed yet, move it first (this refreshes _allSessions)
        if source.status != "completed" {
            // Use smooth path to avoid synchronous fetch/save during drop
            moveSessionToCompletedSmooth(sessionID: sourceID)
        }

        guard let sIndex = _allSessions.firstIndex(where: { $0.id == sourceID }) else { return false }

        let insertIndexPreRemoval: Int = {
            if let beforeID = beforeTargetID, let tIndex = _allSessions.firstIndex(where: { $0.id == beforeID }) {
                return tIndex
            } else {
                // Append to end of Completed scope: find last completed index
                var lastIndex = -1
                for (idx, s) in _allSessions.enumerated() {
                    if s.status == "completed" { lastIndex = idx }
                }
                return lastIndex + 1
            }
        }()

        if sIndex == insertIndexPreRemoval || sIndex + 1 == insertIndexPreRemoval { return true }

        let item = _allSessions.remove(at: sIndex)
        let adjusted = sIndex < insertIndexPreRemoval ? insertIndexPreRemoval - 1 : insertIndexPreRemoval
        let bounded = max(0, min(adjusted, _allSessions.count))
        _allSessions.insert(item, at: bounded)
        objectWillChange.send()
        return true
    }

    /// Backwards-compatible helper: reorder before a specific target ID
    @discardableResult
    func reorderInCompleted(sourceID: UUID, targetID: UUID) -> Bool {
        reorderInCompleted(sourceID: sourceID, beforeTargetID: targetID)
    }

    /// Reorder within the Grouped subcolumn by dropping between items.
    /// Scope is defined by `scopeGroupID` (nil = ungrouped within Grouped, otherwise that group UUID).
    /// If the source is in a different scope (different group or ungrouped), it is moved into the target scope
    /// and inserted at the requested position. This also dissolves the previous group if it becomes a singleton.
    @discardableResult
    func reorderInGrouped(sourceID: UUID, beforeTargetID: UUID?, scopeGroupID: UUID?) -> Bool {
        guard let source = fetchSession(byID: sourceID) else { return false }
        // Ensure source is in grouped status
        if source.status != "grouped" { source.status = "grouped"; scheduleSave() }

        // If moving across scopes (including from ungrouped to inside a group), update groupID
        let previousGroup = source.groupID
        let needsScopeChange: Bool = {
            switch (scopeGroupID, previousGroup) {
            case (nil, nil): return false
            case let (a?, b?): return a != b
            default: return true
            }
        }()
        if needsScopeChange {
            source.groupID = scopeGroupID
            scheduleSave()
            if let previousGroup, previousGroup != scopeGroupID { dissolveGroupIfSingleton(groupID: previousGroup) }
        }

        guard let currentIndex = _allSessions.firstIndex(where: { $0.id == sourceID }) else { return false }

        let insertIndexPreRemoval: Int = {
            if let beforeID = beforeTargetID, let tIndex = _allSessions.firstIndex(where: { $0.id == beforeID }) {
                return tIndex
            } else {
                // Append to end of scope within Grouped
                var lastIndex = -1
                for (idx, s) in _allSessions.enumerated() {
                    if s.status == "grouped" && s.groupID == scopeGroupID { lastIndex = idx }
                }
                return lastIndex + 1
            }
        }()

        // No-op adjacent checks (UI already filters, but keep safe-guard)
        if currentIndex == insertIndexPreRemoval || currentIndex + 1 == insertIndexPreRemoval { return true }

        let item = _allSessions.remove(at: currentIndex)
        let adjusted = currentIndex < insertIndexPreRemoval ? insertIndexPreRemoval - 1 : insertIndexPreRemoval
        let bounded = max(0, min(adjusted, _allSessions.count))
        _allSessions.insert(item, at: bounded)
        // Normalize positions for new and previous scopes
        reindexGroupedScope(scopeGroupID)
        if let previousGroup, previousGroup != scopeGroupID { reindexGroupedScope(previousGroup) }
        objectWillChange.send()
        return true
    }
}
