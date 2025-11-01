
// LOCAL VERSION - COMMENTED OUT TO USE PACKAGE VERSION
//
//  BillingHubViewModel.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import Foundation
import SwiftData
import SwiftUI
import CoreLocation
import Core
import Data

@MainActor
public class BillingHubViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedSession: Session?
    @Published var selectedInvoice: Invoice?
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
    private let invoiceStatusSequence: [String] = ["draft", "ready", "sent", "paid"]
    
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
            for session in _allSessions where session.status?.rawValue == "grouped" {
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
    
    /// Grouped sessions organized by groupID for the grouped column
    var groupedSessions: [SessionGroup] {
        let filteredSessions = filteredSessionEntities()
        let groupedSessions = filteredSessions.filter { $0.status?.rawValue == "grouped" }
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
        
        // Sort groups by their position (you might want to implement proper sorting here)
        return groups.sorted { lhs, rhs in
            // Simple sorting by first session's ID for now
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Filtered sessions based on search and client selection, mapped to KanbanCardData
    var filteredSessions: [KanbanCardData] {
        filteredSessionEntities().compactMap(mapSessionToKanbanCard)
    }

    struct ClientSummary: Identifiable, Hashable {
        let id: UUID
        let name: String
        // colorHex property removed - using deterministic color system instead
    }

    var clientSummaries: [ClientSummary] {
        var seen = Set<UUID>()
        var summaries: [ClientSummary] = []

        for session in _allSessions {
            guard let client = session.client else { continue }
            if seen.insert(client.id).inserted {
                summaries.append(ClientSummary(id: client.id, name: client.fullName))
            }
        }

        for invoice in _allInvoices {
            guard let client = invoice.client else { continue }
            if seen.insert(client.id).inserted {
                summaries.append(ClientSummary(id: client.id, name: client.fullName))
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
    public init(modelContext: ModelContext) {
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
            session.status = .completed
        case .grouped:
            session.status = .grouped
        case .assignServices:
            session.status = .needsServices
        case .addTravel:
            session.status = .needsTravel
        case .reviewDrafts:
            session.status = .reviewDraft
        case .readyToSend:
            session.status = .readyToSend
        case .pending:
            session.status = .pending
        case .received:
            session.status = .received
        }
        
        try? modelContext.save()
        fetchData() // Refresh data after update
    }
    
    /// Updates the billing status of an invoice
    func updateInvoiceStatus(_ invoice: InvoiceEntity, to status: KanbanCardData.BillingColumnType) {
        let previousStatus = canonicalStatus(for: invoice)
        guard let targetStatus = invoiceStatusString(for: status) else { return }

        if invoice.status?.rawValue != targetStatus {
            invoice.status = InvoiceStatus(rawValue: targetStatus) ?? .draft
        }

        switch status {
        case .pending:
            if invoice.sentDate == nil {
                invoice.sentDate = Date()
            }
            invoice.paidDate = nil
        case .received:
            invoice.paidDate = Date()
        default:
            break
        }

        invoice.billingOrder = nextInvoiceOrder(for: targetStatus)
        if previousStatus != targetStatus {
            _ = normalizeInvoiceOrder(for: previousStatus)
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
        invoice.status = .draft
        invoice.billingOrder = nextInvoiceOrder(for: "draft")
        
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
        normalizeInvoicePositionsIfNeeded()
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
        for s in _allSessions where s.status == .grouped {
            let scope = s.groupID
            let next = nextIndexByScope[scope] ?? 0
            if s.groupedPosition != next { s.groupedPosition = next; changed = true }
            nextIndexByScope[scope] = next + 1
        }
        if changed { scheduleSave() }
    }
    
    private func fetchAllInvoicesInternal() -> [InvoiceEntity] {
        let descriptor = FetchDescriptor<InvoiceEntity>(
            sortBy: [
                SortDescriptor(\.billingOrder, order: .forward),
                SortDescriptor(\.issueDate, order: .reverse)
            ]
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

        invoices.sort { lhs, rhs in
            let leftStatus = canonicalStatus(for: lhs)
            let rightStatus = canonicalStatus(for: rhs)
            if leftStatus == rightStatus {
                if lhs.billingOrder == rhs.billingOrder {
                    return lhs.issueDate > rhs.issueDate
                }
                return lhs.billingOrder < rhs.billingOrder
            }
            return leftStatus < rightStatus
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
        let rateInfo = travelRateInfo(for: session)
        let travelSuggestion = travelSuggestion(for: session)

        let sessionCardData = SessionKanbanCardData(
            sessionId: sessionId,
            title: title,
            clientName: clientName,
            serviceName: serviceName,
            travelRate: rateInfo?.rate,
            travelRateUnit: rateInfo?.unit,
            suggestedTravelDistanceKM: travelSuggestion.distanceKilometres,
            suggestedTravelTimeMinutes: travelSuggestion.timeMinutes,
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
        let date = invoice.issueDate.formatted(date: .abbreviated, time: .omitted)
        let amount = String(format: "$%.2f", invoice.totalAmount)
        
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
        case .completed:
            return .completed
        case .grouped:
            return .grouped
        case .needsServices:
            return .assignServices
        case .needsTravel:
            return .addTravel
        case .reviewDraft:
            return .reviewDrafts
        case .readyToSend:
            return .readyToSend
        case .pending:
            return .pending
        case .received:
            return KanbanCardData.BillingColumnType.received
        default:
            return .completed
        }
    }

    private func statusString(for column: KanbanCardData.BillingColumnType) -> String? {
        switch column {
        case .completed: return "completed"
        case .grouped: return "grouped"
        case .assignServices: return "needs_services"
        case .addTravel: return "needs_travel"
        case .reviewDrafts: return "review_draft"
        case .readyToSend: return "ready_to_send"
        case .pending: return "pending"
        case .received: return "received"
        }
    }
    
    private func mapBillingStatus(for invoice: InvoiceEntity) -> KanbanCardData.BillingColumnType {
        guard let status = invoice.status else { return .reviewDrafts }
        
        switch status {
        case .draft:
            return .reviewDrafts
        case .ready:
            return .readyToSend
        case .sent:
            return .pending
        case .paid:
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

    /// Pair/group two sessions together within the specified column.
    func groupSessions(sourceID: UUID, targetID: UUID, in column: KanbanCardData.BillingColumnType = .grouped) {
        // Ignore self-drops
        guard sourceID != targetID else { return }
        guard let source = fetchSession(byID: sourceID), let target = fetchSession(byID: targetID) else { return }
        // Ensure both are in the desired status
        updateSessionStatus(target, to: column)
        updateSessionStatus(source, to: column)

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
        if column == .grouped {
            reindexGroupedScope(target.groupID)
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
        if session.status != .grouped {
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
    @discardableResult
    func moveSessionToCompletedSmooth(sessionID: UUID) -> Bool {
        guard let session = fetchSession(byID: sessionID) else { return false }
        let previousGroup = session.groupID
        session.groupID = nil
        session.status = .completed
        scheduleSave()
        if let previousGroup {
            dissolveGroupIfSingleton(groupID: previousGroup)
            reindexGroupedScope(previousGroup)
        } else {
            // Removing from ungrouped scope
            reindexGroupedScope(nil)
        }
        objectWillChange.send()
        return true
    }

    @discardableResult
    func moveGroupToCompletedSmooth(groupID: UUID) -> Bool {
        let members = _allSessions.filter { $0.groupID == groupID }
        guard !members.isEmpty else { return false }
        for session in members {
            session.groupID = nil
            session.status = .completed
        }
        scheduleSave()
        reindexGroupedScope(groupID)
        reindexGroupedScope(nil)
        objectWillChange.send()
        return true
    }

    /// Background drop into a column without a full refetch. If already grouped and had a group, ungroup.
    func dropIntoColumnSmooth(sessionID: UUID, column: KanbanCardData.BillingColumnType) -> Bool {
        guard let session = fetchSession(byID: sessionID) else { return false }
        guard let desiredStatus = statusString(for: column) else { return false }

        let previousGroup = session.groupID

        let desiredStatusEnum = SessionStatus(rawValue: desiredStatus) ?? .scheduled
        if session.status != desiredStatusEnum {
            session.status = desiredStatusEnum
        }

        if previousGroup != nil {
            session.groupID = nil
            scheduleSave()
            if let previousGroup {
                dissolveGroupIfSingleton(groupID: previousGroup)
                if column == .grouped { reindexGroupedScope(previousGroup) }
            }
        } else {
            scheduleSave()
        }

        if column == .grouped {
            // Normalize ungrouped scope positions after insert
            reindexGroupedScope(nil)
        }
        objectWillChange.send()
        return true
    }

    /// Convenience wrapper for existing behaviour.
    @discardableResult
    func dropIntoGroupedColumnSmooth(sessionID: UUID) -> Bool {
        return dropIntoColumnSmooth(sessionID: sessionID, column: .grouped)
    }

    @discardableResult
    func moveGroupSmooth(groupID: UUID, to column: KanbanCardData.BillingColumnType) -> Bool {
        guard let desiredStatus = statusString(for: column) else { return false }
        let members = _allSessions.filter { $0.groupID == groupID }
        guard !members.isEmpty else { return false }

        for session in members {
            let desiredStatusEnum = SessionStatus(rawValue: desiredStatus) ?? .scheduled
            if session.status != desiredStatusEnum {
                session.status = desiredStatusEnum
            }
        }

        scheduleSave()
        reindexGroupedScope(groupID)
        if column == .grouped {
            reindexGroupedScope(nil)
        } else {
            reindexGroupedScope(nil)
        }
        objectWillChange.send()
        return true
    }

    /// Group sessions together smoothly without a full refetch; adopts/creates target's group.
    func groupSessionsSmooth(sourceID: UUID, targetID: UUID, in column: KanbanCardData.BillingColumnType = .grouped) -> Bool {
        guard sourceID != targetID else { return false }
        guard let source = fetchSession(byID: sourceID), let target = fetchSession(byID: targetID) else { return false }
        guard let desiredStatus = statusString(for: column) else { return false }

        let desiredStatusEnum = SessionStatus(rawValue: desiredStatus) ?? .scheduled
        if target.status != desiredStatusEnum { target.status = desiredStatusEnum }
        if source.status != desiredStatusEnum { source.status = desiredStatusEnum }

        let previousGroup = source.groupID

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
            if column == .grouped { reindexGroupedScope(previousGroup) }
        }

        if column == .grouped {
            reindexGroupedScope(target.groupID)
        } else {
            reindexGroupedScope(previousGroup)
            reindexGroupedScope(nil)
        }

        objectWillChange.send()
        return true
    }
    
    /// Add a session to an existing group
    func addSessionToGroup(sessionID: UUID, groupID: UUID) -> Bool {
        guard let session = fetchSession(byID: sessionID) else { return false }
        
        // Check if session is already in the target group
        if session.groupID == groupID { return true }
        
        // If target group doesn't exist, try to create it from a single session
        let targetGroupMembers = _allSessions.filter { $0.groupID == groupID }
        if targetGroupMembers.isEmpty {
            if let targetSession = _allSessions.first(where: { $0.id == groupID }) {
                targetSession.groupID = groupID
                targetSession.status = .grouped
            } else {
                return false
            }
        }
        
        // Validate that all sessions in the group have the same client
        let updatedGroupMembers = _allSessions.filter { $0.groupID == groupID }
        if !updatedGroupMembers.isEmpty {
            let firstClientName = updatedGroupMembers.first?.client?.fullName
            if let firstClientName = firstClientName, session.client?.fullName != firstClientName {
                return false // Different client, cannot group
            }
        }
        
        // Store previous group for cleanup
        let previousGroup = session.groupID
        
        // Update session
        session.groupID = groupID
        session.status = .grouped
        
        // Clean up previous group if needed
        if let previousGroup = previousGroup {
            dissolveGroupIfSingleton(groupID: previousGroup)
            reindexGroupedScope(previousGroup)
        }
        
        // Reindex target group
        reindexGroupedScope(groupID)
        
        // Save and notify
        scheduleSave()
        objectWillChange.send()
        
        return true
    }
    
    /// Check if a session can be added to a group (same client only)
    func canAddSessionToGroup(sessionID: UUID, groupID: UUID) -> Bool {
        guard let session = fetchSession(byID: sessionID) else { return false }
        
        // If target group doesn't exist, allow creation
        let targetGroupMembers = _allSessions.filter { $0.groupID == groupID }
        if targetGroupMembers.isEmpty {
            return true
        }
        
        // Check if all sessions in the group have the same client
        let firstClientName = targetGroupMembers.first?.client?.fullName
        return firstClientName == nil || session.client?.fullName == firstClientName
    }

    @discardableResult
    func ungroupGroupSmooth(groupID: UUID) -> Bool {
        let members = _allSessions.filter { $0.groupID == groupID }
        guard !members.isEmpty else { return false }
        for session in members {
            session.groupID = nil
        }
        scheduleSave()
        reindexGroupedScope(groupID)
        reindexGroupedScope(nil)
        objectWillChange.send()
        return true
    }

    /// Reassign contiguous groupedPosition values for a given Grouped scope (nil = ungrouped in Grouped)
    private func reindexGroupedScope(_ groupID: UUID?) {
        let items = _allSessions.filter { $0.status == .grouped && $0.groupID == groupID }
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
        if source.status != .completed {
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
                    if s.status == .completed { lastIndex = idx }
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
        return reorderSessionsInColumn(.grouped, sourceID: sourceID, beforeTargetID: beforeTargetID, scopeGroupID: scopeGroupID)
    }

    @discardableResult
    func reorderInAssignServices(sourceID: UUID, beforeTargetID: UUID?, scopeGroupID: UUID?) -> Bool {
        return reorderSessionsInColumn(.assignServices, sourceID: sourceID, beforeTargetID: beforeTargetID, scopeGroupID: scopeGroupID)
    }

    @discardableResult
    func reorderInAddTravel(sourceID: UUID, beforeTargetID: UUID?, scopeGroupID: UUID?) -> Bool {
        return reorderSessionsInColumn(.addTravel, sourceID: sourceID, beforeTargetID: beforeTargetID, scopeGroupID: scopeGroupID)
    }

    private func reorderSessionsInColumn(
        _ column: KanbanCardData.BillingColumnType,
        sourceID: UUID,
        beforeTargetID: UUID?,
        scopeGroupID: UUID?
    ) -> Bool {
        guard let source = fetchSession(byID: sourceID),
              let desiredStatus = statusString(for: column) else { return false }

        let desiredStatusEnum = SessionStatus(rawValue: desiredStatus) ?? .scheduled
        if source.status != desiredStatusEnum {
            source.status = desiredStatusEnum
            scheduleSave()
        }

        let supportsGrouping = (column == .grouped || column == .assignServices || column == .addTravel)
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
                source.groupID = scopeGroupID
                scheduleSave()
                if let previousGroup, previousGroup != scopeGroupID { dissolveGroupIfSingleton(groupID: previousGroup) }
            }
        } else if previousGroup != nil {
            source.groupID = nil
        }

        guard let currentIndex = _allSessions.firstIndex(where: { $0.id == sourceID }) else { return false }

        let insertIndexPreRemoval: Int = {
            if let beforeID = beforeTargetID,
               let tIndex = _allSessions.firstIndex(where: { $0.id == beforeID }) {
                return tIndex
            }
            var lastIndex = -1
            for (idx, session) in _allSessions.enumerated() {
                let desiredStatusEnum = SessionStatus(rawValue: desiredStatus) ?? .scheduled
                guard session.status == desiredStatusEnum else { continue }
                if supportsGrouping {
                    if session.groupID == scopeGroupID { lastIndex = idx }
                } else {
                    lastIndex = idx
                }
            }
            return lastIndex + 1
        }()

        if currentIndex == insertIndexPreRemoval || currentIndex + 1 == insertIndexPreRemoval { return true }

        let item = _allSessions.remove(at: currentIndex)
        let adjusted = currentIndex < insertIndexPreRemoval ? insertIndexPreRemoval - 1 : insertIndexPreRemoval
        let bounded = max(0, min(adjusted, _allSessions.count))
        _allSessions.insert(item, at: bounded)

        if supportsGrouping && column == .grouped {
            reindexGroupedScope(scopeGroupID)
            if let previousGroup, previousGroup != scopeGroupID { reindexGroupedScope(previousGroup) }
        }

        objectWillChange.send()
        return true
    }

    @discardableResult
    func reorderInvoices(in column: KanbanCardData.BillingColumnType, sourceID: UUID, beforeTargetID: UUID?) -> Bool {
        guard let targetStatus = invoiceStatusString(for: column),
              let invoice = fetchInvoice(byID: sourceID) else { return false }

        let previousStatus = canonicalStatus(for: invoice)

        let targetStatusEnum = InvoiceStatus(rawValue: targetStatus) ?? .draft
        if invoice.status != targetStatusEnum {
            invoice.status = targetStatusEnum
        }

        switch column {
        case .pending:
            if invoice.sentDate == nil { invoice.sentDate = Date() }
            if canonicalStatus(for: invoice) != "paid" { invoice.paidDate = nil }
        case .received:
            invoice.paidDate = Date()
        default:
            break
        }

        var targetInvoices = _allInvoices.filter { canonicalStatus(for: $0) == targetStatus && $0.id != invoice.id }

        if let beforeTargetID,
           let insertionIndex = targetInvoices.firstIndex(where: { $0.id == beforeTargetID }) {
            targetInvoices.insert(invoice, at: insertionIndex)
        } else {
            targetInvoices.append(invoice)
        }

        if let currentIndex = _allInvoices.firstIndex(where: { $0.id == invoice.id }) {
            _allInvoices.remove(at: currentIndex)
        }

        let insertIndex: Int
        if let beforeTargetID,
           let idx = _allInvoices.firstIndex(where: { $0.id == beforeTargetID }) {
            insertIndex = idx
        } else if let lastIndex = _allInvoices.lastIndex(where: { canonicalStatus(for: $0) == targetStatus }) {
            insertIndex = lastIndex + 1
        } else {
            insertIndex = _allInvoices.count
        }

        _allInvoices.insert(invoice, at: min(insertIndex, _allInvoices.count))

        for (idx, item) in targetInvoices.enumerated() {
            item.billingOrder = Int32(idx)
        }

        if previousStatus != targetStatus {
            _ = normalizeInvoiceOrder(for: previousStatus)
        }

        scheduleSave()
        objectWillChange.send()
        return true
    }

    private func fetchInvoice(byID id: UUID) -> InvoiceEntity? {
        if let cached = _allInvoices.first(where: { $0.id == id }) { return cached }
        let descriptor = FetchDescriptor<InvoiceEntity>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func invoiceStatusString(for column: KanbanCardData.BillingColumnType) -> String? {
        switch column {
        case .reviewDrafts: return "draft"
        case .readyToSend: return "ready"
        case .pending: return "sent"
        case .received: return "paid"
        default: return nil
        }
    }

    private func canonicalStatus(for invoice: InvoiceEntity) -> String {
        invoice.status?.rawValue ?? "draft"
    }

    private func nextInvoiceOrder(for status: String) -> Int32 {
        let siblings = _allInvoices.filter { canonicalStatus(for: $0) == status }
        let maxOrder = siblings.map(\.billingOrder).max() ?? -1
        return maxOrder + 1
    }

    private func normalizeInvoicePositionsIfNeeded() {
        var changed = false
        for status in invoiceStatusSequence {
            if normalizeInvoiceOrder(for: status) { changed = true }
        }
        if changed { scheduleSave() }
    }

    @discardableResult
    private func normalizeInvoiceOrder(for status: String) -> Bool {
        let invoices = _allInvoices
            .filter { canonicalStatus(for: $0) == status }
            .sorted {
                if $0.billingOrder == $1.billingOrder {
                    return $0.issueDate > $1.issueDate
                }
                return $0.billingOrder < $1.billingOrder
            }

        var changed = false
        for (idx, invoice) in invoices.enumerated() {
            let desired = Int32(idx)
            if invoice.billingOrder != desired {
                invoice.billingOrder = desired
                changed = true
            }
        }
        return changed
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

    private func travelRateInfo(for session: SessionEntity) -> TravelRateInfo? {
        guard let clientService = session.clientService else { return nil }

        if let item = clientService.ndisItem {
            let region = preferredRegionCode(for: session.client)
            if let regionalRate = price(for: item, matching: region) ?? price(for: item, matching: nil) {
                return TravelRateInfo(rate: regionalRate, unit: item.unit ?? clientService.unit)
            }
        }

        if clientService.rate > 0 {
            return TravelRateInfo(rate: clientService.rate, unit: clientService.unit)
        }

        return nil
    }

    private func preferredRegionCode(for client: ClientEntity?) -> String? {
        guard let state = client?.address?.state.trimmingCharacters(in: .whitespacesAndNewlines), !state.isEmpty else {
            return nil
        }
        return state.uppercased()
    }

    private func price(for item: NDISItemEntity, matching regionCode: String?) -> Double? {
        guard !item.regionalPrices.isEmpty else { return nil }

        if let regionCode, !regionCode.isEmpty {
            if let match = item.regionalPrices.first(where: { price in
                guard let identifier = price.regionIdentifier else { return false }
                let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                return normalized == regionCode || normalized.contains(regionCode)
            }) {
                return match.amount
            }
        }

        return item.regionalPrices.first?.amount
    }

    private func travelSuggestion(for session: SessionEntity) -> TravelSuggestion {
        var suggestion = TravelSuggestion(distanceKilometres: nil, timeMinutes: nil)

        if let previous = previousSession(before: session) {
            let metrics = travelMetrics(between: previous, and: session)
            if suggestion.distanceKilometres == nil { suggestion = TravelSuggestion(distanceKilometres: metrics.distance, timeMinutes: suggestion.timeMinutes) }
            if suggestion.timeMinutes == nil { suggestion = TravelSuggestion(distanceKilometres: suggestion.distanceKilometres, timeMinutes: metrics.minutes) }
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

    private func previousSession(before session: SessionEntity) -> SessionEntity? {
        guard let sessionStart = session.startTime else { return nil }
        let candidates = _allSessions
            .filter { $0.id != session.id && ($0.endTime ?? $0.startTime ?? .distantPast) <= sessionStart }
            .sorted { ($0.endTime ?? $0.startTime ?? .distantPast) > ($1.endTime ?? $1.startTime ?? .distantPast) }
        return candidates.first
    }

    private func nextSession(after session: SessionEntity) -> SessionEntity? {
        guard let sessionEnd = session.endTime ?? session.startTime else { return nil }
        let candidates = _allSessions
            .filter { $0.id != session.id && ($0.startTime ?? .distantFuture) >= sessionEnd }
            .sorted { ($0.startTime ?? .distantFuture) < ($1.startTime ?? .distantFuture) }
        return candidates.first
    }

    private func travelMetrics(between first: SessionEntity, and second: SessionEntity) -> (distance: Double?, minutes: Double?) {
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

    private func distanceKilometres(between first: SessionEntity, and second: SessionEntity) -> Double? {
        guard let firstCoordinate = coordinate(for: first),
              let secondCoordinate = coordinate(for: second) else { return nil }

        let firstLocation = CLLocation(latitude: firstCoordinate.latitude, longitude: firstCoordinate.longitude)
        let secondLocation = CLLocation(latitude: secondCoordinate.latitude, longitude: secondCoordinate.longitude)
        let metres = firstLocation.distance(from: secondLocation)
        guard metres.isFinite else { return nil }
        return metres / 1000.0
    }

    private func coordinate(for session: SessionEntity) -> CLLocationCoordinate2D? {
        let lat = session.sessionLatitude
        let lon = session.sessionLongitude
        if lat != 0.0 || lon != 0.0 {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        if let address = session.address {
            let addrLat = address.latitude
            let addrLon = address.longitude
            if addrLat != 0.0 || addrLon != 0.0 {
                return CLLocationCoordinate2D(latitude: addrLat, longitude: addrLon)
            }
        }

        return nil
    }
}
