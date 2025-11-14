
// LOCAL VERSION - COMMENTED OUT TO USE PACKAGE VERSION
//
//  BillingHubViewModel.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import Foundation
import SwiftUI
import CoreLocation
import Core

@MainActor
public class BillingHubViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedSession: Session?
    @Published var selectedInvoice: Invoice?
    @Published var searchText: String = ""
    @Published var selectedClientID: UUID? = nil
    @Published private(set) var lastUpdated: Date = Date()

    // Cached properties for sessions and invoices (domain models)
    @Published private var _allSessions: [Session] = []
    @Published private var _allInvoices: [Invoice] = []

    // MARK: - Dependencies
    private let sessionsRepository: SessionsRepository
    private let invoicesRepository: InvoicesRepository
    private let clientsRepository: ClientsRepository
    private let invoiceStatusSequence: [String] = ["draft", "ready", "sent", "paid"]
    
    // MARK: - Computed Properties
    
    /// All sessions grouped by billing status, mapped to KanbanCardData
    var sessionsByStatus: [KanbanCardData.BillingColumnType: [KanbanCardData]] {
        // Map filtered sessions to KanbanCardData once
        let filteredSessions = filteredSessions()
        let kanbanCards = filteredSessions.compactMap(mapSessionToKanbanCard)

        // Group by columnType
        var dict = Dictionary(grouping: kanbanCards, by: { $0.columnType })

        // Sort the Grouped column by a stable groupedPosition stored on Session
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
        let invoices = filteredInvoices()
        let kanbanCards = invoices.compactMap(mapInvoiceToKanbanCard)

        return Dictionary(grouping: kanbanCards, by: { $0.columnType })
    }
    
    /// Grouped sessions organized by groupID for the grouped column
    var groupedSessions: [SessionGroup] {
        let filteredSessions = filteredSessions()
        let groupedSessions = filteredSessions.filter { $0.status == "grouped" }
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
    var filteredSessionsCards: [KanbanCardData] {
        filteredSessions().compactMap(mapSessionToKanbanCard)
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
            guard let clientId = session.clientId else { continue }
            if seen.insert(clientId).inserted {
                // Fetch client name - for now use clientId, will need to fetch or cache
                summaries.append(ClientSummary(id: clientId, name: "Client \(clientId.uuidString.prefix(8))"))
            }
        }

        for invoice in _allInvoices {
            guard let clientId = invoice.clientId else { continue }
            if seen.insert(clientId).inserted {
                // Use snapshotted client name if available, otherwise use ID
                let name = invoice.clientName ?? "Client \(clientId.uuidString.prefix(8))"
                summaries.append(ClientSummary(id: clientId, name: name))
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
    public init(
        sessionsRepository: SessionsRepository,
        invoicesRepository: InvoicesRepository,
        clientsRepository: ClientsRepository
    ) {
        self.sessionsRepository = sessionsRepository
        self.invoicesRepository = invoicesRepository
        self.clientsRepository = clientsRepository
        // Initial fetch when ViewModel is created
        Task {
            await fetchData()
        }
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
    
    /// Updates the billing status of an invoice
    func updateInvoiceStatus(_ invoiceId: UUID, to status: KanbanCardData.BillingColumnType) async {
        guard let targetStatus = invoiceStatusString(for: status) else { return }
        
        do {
            try await invoicesRepository.updateStatus(id: invoiceId, status: targetStatus)
            await fetchData()
        } catch {
            print("❌ [BillingHubViewModel] Error updating invoice status: \(error)")
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
        Task {
            await fetchData()
        }
    }
    
    /// Creates a new invoice from grouped sessions
    func createInvoiceFromSessions(_ sessionIds: [UUID]) async {
        guard let firstSessionId = sessionIds.first else { return }
        
        // Fetch first session to get client ID
        guard let firstSession = try? await sessionsRepository.fetch(byId: firstSessionId),
              let clientId = firstSession.clientId else {
            return
        }
        
        do {
            let invoice = try await invoicesRepository.createFromSessions(sessionIds, clientId: clientId)
            print("✅ [BillingHubViewModel] Created invoice: \(invoice.invoiceNumber)")
            await fetchData()
        } catch {
            print("❌ [BillingHubViewModel] Error creating invoice from sessions: \(error)")
        }
    }
    
    /// Groups sessions for billing
    func groupSessions(_ sessionIds: [UUID]) async {
        // Use repository groupSessions method if available, otherwise update individually
        for sessionId in sessionIds {
            await updateSessionStatus(sessionId, to: .grouped)
        }
    }
    
    /// Assigns services to sessions
    func assignServicesToSessions(_ sessionIds: [UUID]) async {
        for sessionId in sessionIds {
            await updateSessionStatus(sessionId, to: .assignServices)
        }
    }
    
    /// Adds travel charges to sessions
    func addTravelToSessions(_ sessionIds: [UUID]) async {
        for sessionId in sessionIds {
            await updateSessionStatus(sessionId, to: .addTravel)
        }
    }
    
    // MARK: - Private Methods

    private func fetchData() async {
        do {
            _allSessions = try await sessionsRepository.fetchAll()
            _allInvoices = try await invoicesRepository.fetchAll()
            // Ensure grouped positions are normalized based on current order
            await normalizeGroupedPositionsIfNeeded()
            // Note: Invoice position normalization handled by repository
            lastUpdated = Date()
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
                session.title.localizedCaseInsensitiveContains(trimmedQuery) ||
                // Note: Client name lookup would need clientRepository - simplified for now
                session.title.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }

        return sessions
    }

    /// Ensure every session in the Grouped column has a contiguous groupedPosition within its scope
    private func normalizeGroupedPositionsIfNeeded() async {
        var nextIndexByScope: [UUID?: Int32] = [:]
        var updates: [(UUID, Int32)] = []
        
        for session in _allSessions where session.status == "grouped" {
            let scope = session.groupID
            let next = nextIndexByScope[scope] ?? 0
            if session.groupedPosition != next {
                updates.append((session.id, next))
            }
            nextIndexByScope[scope] = next + 1
        }
        
        // Batch update grouped positions
        for (sessionId, position) in updates {
            do {
                try await sessionsRepository.updateGroupedPosition(id: sessionId, position: position)
            } catch {
                print("❌ [BillingHubViewModel] Error updating grouped position: \(error)")
            }
        }
        
        if !updates.isEmpty {
            await fetchData()
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
                invoice.clientName?.localizedCaseInsensitiveContains(trimmedQuery) == true ||
                invoice.invoiceNumber.localizedCaseInsensitiveContains(trimmedQuery)
                // Note: Invoice items would need separate fetch - simplified for now
            }
        }

        invoices.sort { lhs, rhs in
            let leftStatus = canonicalStatus(for: lhs)
            let rightStatus = canonicalStatus(for: rhs)
            if leftStatus == rightStatus {
                return lhs.issueDate > rhs.issueDate
            }
            return leftStatus < rightStatus
        }

        return invoices
    }
    
    /// Maps a Session to a KanbanCardData
    private func mapSessionToKanbanCard(_ session: Session) -> KanbanCardData? {
        let sessionId = session.id
        
        let title = session.title
        // Note: Client name lookup would require fetching client - using placeholder for now
        // In a production app, you'd want to cache client data or fetch it
        let clientName = "Client" // TODO: Fetch client name from repository if needed
        let serviceName = "Service" // TODO: Fetch service name if needed
        let hasIssues = false // TODO: Review items would need separate fetch
        let date = session.startTime?.formatted(date: .abbreviated, time: .omitted) ?? ""
        var duration: String = "-"
        var sessionEndTime: Date? = session.endTime
        
        if let startTime = session.startTime, let endTime = session.endTime {
            let components = Calendar.current.dateComponents([.hour, .minute], from: startTime, to: endTime)
            if let hours = components.hour, let minutes = components.minute {
                let totalMinutes = Double(hours * 60 + minutes)
                if totalMinutes > 0 {
                    duration = String(format: "%.1f", totalMinutes / 60.0) + "h"
                }
            }
        }
        
        let columnType = mapBillingStatus(for: session)
        let workflowStatus = KanbanCardData.workflowStatus(for: columnType)
        let accentColor = KanbanCardData.columnAccentColor(for: columnType)
        let priority = hasIssues ? Priority.high : .low
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
    
    /// Maps an Invoice to a KanbanCardData
    private func mapInvoiceToKanbanCard(_ invoice: Invoice) -> KanbanCardData? {
        let invoiceId = invoice.id
        
        let title = invoice.invoiceNumber.isEmpty ? "Draft Invoice" : "\(invoice.invoiceNumber)"
        let clientName = invoice.clientName ?? "Unknown Client"
        // Note: Invoice items would need separate fetch - using placeholder
        let serviceName = "Multiple Services" // TODO: Fetch first item description if needed
        let date = invoice.issueDate.formatted(date: .abbreviated, time: .omitted)
        let amount = String(format: "$%.2f", invoice.totalAmount)
        
        let columnType = mapBillingStatus(for: invoice)
        let workflowStatus = KanbanCardData.workflowStatus(for: columnType)
        let accentColor = KanbanCardData.columnAccentColor(for: columnType)
        let priority = Priority.medium
        
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
    
    private func mapBillingStatus(for session: Session) -> KanbanCardData.BillingColumnType {
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
    
    private func mapBillingStatus(for invoice: Invoice) -> KanbanCardData.BillingColumnType {
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
    func moveSessionToGrouped(sessionID: UUID) {
        Task {
            await updateSessionStatus(sessionID, to: .grouped)
        }
    }

    /// Pair/group two sessions together within the specified column.
    func groupSessions(sourceID: UUID, targetID: UUID, in column: KanbanCardData.BillingColumnType = .grouped) {
        // Ignore self-drops
        guard sourceID != targetID else { return }
        
        Task {
            guard let source = await fetchSessionFromRepository(byID: sourceID),
                  let target = await fetchSessionFromRepository(byID: targetID) else { return }
            
            // Ensure both are in the desired status
            await updateSessionStatus(targetID, to: column)
            await updateSessionStatus(sourceID, to: column)

            let previousGroup = source.groupID
            // Adopt target's group or create a new group
            let newGroupID: UUID
            if let existingGroup = target.groupID {
                newGroupID = existingGroup
                // Group source with target
                try? await sessionsRepository.groupSessions([sourceID], groupId: existingGroup)
            } else {
                let newGroup = UUID()
                newGroupID = newGroup
                // Create new group with both sessions
                try? await sessionsRepository.groupSessions([sourceID, targetID], groupId: newGroup)
            }
            
            // If source left a previous group that now has only one member, dissolve it
            if let previousGroup, previousGroup != newGroupID {
                await dissolveGroupIfSingleton(groupID: previousGroup)
            }
            if column == .grouped {
                await reindexGroupedScope(newGroupID)
            }
            await fetchData()
        }
    }

    /// Moves a session back to the Completed column
    func moveSessionToCompleted(sessionID: UUID) {
        Task {
            guard let session = await fetchSessionFromRepository(byID: sessionID) else { return }
            // Remove grouping when leaving Grouped
            let previousGroup = session.groupID
            
            if let previousGroup {
                try? await sessionsRepository.ungroupSessions([sessionID])
                await dissolveGroupIfSingleton(groupID: previousGroup)
            }
            
            await updateSessionStatus(sessionID, to: .completed)
        }
    }

    /// Handles dropping a session into the Grouped column background (not onto a card).
    /// If the session came from Completed, moves to grouped. If already grouped and part of a group,
    /// it gets ungrouped (groupID cleared). If that leaves its old group with a singleton, dissolve it.
    func dropIntoGroupedColumn(sessionID: UUID) {
        Task {
            guard let session = await fetchSessionFromRepository(byID: sessionID) else { return }
            let previousGroup = session.groupID

            // Ensure status is grouped
            if session.status != "grouped" {
                await updateSessionStatus(sessionID, to: .grouped)
            }

            // If part of a group, ungroup it
            if let previousGroup {
                try? await sessionsRepository.ungroupSessions([sessionID])
                await dissolveGroupIfSingleton(groupID: previousGroup)
                await fetchData()
            }
        }
    }

    // MARK: - Group maintenance
    /// If a group's remaining membership is a single session, clear its groupID to dissolve the group.
    private func dissolveGroupIfSingleton(groupID: UUID) async {
        // Use in-memory cache
        let cached = _allSessions.filter { $0.groupID == groupID }
        if cached.count <= 1, let last = cached.first {
            do {
                try await sessionsRepository.ungroupSessions([last.id])
            } catch {
                print("❌ [BillingHubViewModel] Error dissolving group: \(error)")
            }
        }
    }

    // MARK: - Optimized operations (async repository-based)
    /// Move to Completed (optimized for performance)
    @discardableResult
    func moveSessionToCompletedSmooth(sessionID: UUID) -> Bool {
        Task {
            guard let session = await fetchSessionFromRepository(byID: sessionID) else { return }
            let previousGroup = session.groupID
            
            await updateSessionStatus(sessionID, to: .completed)
            
            if let previousGroup {
                try? await sessionsRepository.ungroupSessions([sessionID])
                await dissolveGroupIfSingleton(groupID: previousGroup)
                await reindexGroupedScope(previousGroup)
            } else {
                await reindexGroupedScope(nil)
            }
            objectWillChange.send()
        }
        return true
    }

    @discardableResult
    func moveGroupToCompletedSmooth(groupID: UUID) -> Bool {
        Task {
            let members = _allSessions.filter { $0.groupID == groupID }
            guard !members.isEmpty else { return }
            
            let sessionIds = members.map { $0.id }
            try? await sessionsRepository.ungroupSessions(sessionIds)
            
            for sessionId in sessionIds {
                await updateSessionStatus(sessionId, to: .completed)
            }
            
            await reindexGroupedScope(groupID)
            await reindexGroupedScope(nil)
            objectWillChange.send()
        }
        return true
    }

    /// Background drop into a column
    func dropIntoColumnSmooth(sessionID: UUID, column: KanbanCardData.BillingColumnType) -> Bool {
        Task {
            guard let session = await fetchSessionFromRepository(byID: sessionID) else { return }
            guard let desiredStatus = statusString(for: column) else { return }

            let previousGroup = session.groupID

            if session.status != desiredStatus {
                await updateSessionStatus(sessionID, to: column)
            }

            if let previousGroup {
                try? await sessionsRepository.ungroupSessions([sessionID])
                await dissolveGroupIfSingleton(groupID: previousGroup)
                if column == .grouped { await reindexGroupedScope(previousGroup) }
            }

            if column == .grouped {
                await reindexGroupedScope(nil)
            }
            objectWillChange.send()
        }
        return true
    }

    /// Convenience wrapper
    @discardableResult
    func dropIntoGroupedColumnSmooth(sessionID: UUID) -> Bool {
        return dropIntoColumnSmooth(sessionID: sessionID, column: .grouped)
    }

    @discardableResult
    func moveGroupSmooth(groupID: UUID, to column: KanbanCardData.BillingColumnType) -> Bool {
        Task {
            guard let desiredStatus = statusString(for: column) else { return }
            let members = _allSessions.filter { $0.groupID == groupID }
            guard !members.isEmpty else { return }

            let sessionIds = members.map { $0.id }
            for sessionId in sessionIds {
                await updateSessionStatus(sessionId, to: column)
            }

            await reindexGroupedScope(groupID)
            await reindexGroupedScope(nil)
            objectWillChange.send()
        }
        return true
    }

    /// Group sessions together (async repository-based)
    func groupSessionsSmooth(sourceID: UUID, targetID: UUID, in column: KanbanCardData.BillingColumnType = .grouped) -> Bool {
        Task {
            guard sourceID != targetID else { return }
            guard let source = await fetchSessionFromRepository(byID: sourceID),
                  let target = await fetchSessionFromRepository(byID: targetID) else { return }
            
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
            
            // Check if session is already in the target group
            if session.groupID == groupID { return }
            
            // Validate that all sessions in the group have the same client
            let targetGroupMembers = _allSessions.filter { $0.groupID == groupID }
            if !targetGroupMembers.isEmpty {
                guard let firstClientId = targetGroupMembers.first?.clientId,
                      session.clientId == firstClientId else {
                    return // Different client, cannot group
                }
            }
            
            let previousGroup = session.groupID
            
            // Group session
            try? await sessionsRepository.groupSessions([sessionID], groupId: groupID)
            
            if let previousGroup {
                await dissolveGroupIfSingleton(groupID: previousGroup)
                await reindexGroupedScope(previousGroup)
            }
            
            await reindexGroupedScope(groupID)
            objectWillChange.send()
        }
        return true
    }
    
    /// Check if a session can be added to a group (same client only)
    func canAddSessionToGroup(sessionID: UUID, groupID: UUID) -> Bool {
        guard let session = fetchSession(byID: sessionID) else { return false }
        
        let targetGroupMembers = _allSessions.filter { $0.groupID == groupID }
        if targetGroupMembers.isEmpty {
            return true
        }
        
        guard let firstClientId = targetGroupMembers.first?.clientId else { return true }
        return session.clientId == firstClientId
    }

    @discardableResult
    func ungroupGroupSmooth(groupID: UUID) -> Bool {
        Task {
            let members = _allSessions.filter { $0.groupID == groupID }
            guard !members.isEmpty else { return }
            
            let sessionIds = members.map { $0.id }
            try? await sessionsRepository.ungroupSessions(sessionIds)
            
            await reindexGroupedScope(groupID)
            await reindexGroupedScope(nil)
            objectWillChange.send()
        }
        return true
    }

    /// Reassign contiguous groupedPosition values for a given Grouped scope
    private func reindexGroupedScope(_ groupID: UUID?) async {
        let items = _allSessions.filter { $0.status == "grouped" && $0.groupID == groupID }
        for (idx, session) in items.enumerated() {
            do {
                try await sessionsRepository.updateGroupedPosition(id: session.id, position: Int32(idx))
            } catch {
                print("❌ [BillingHubViewModel] Error updating grouped position: \(error)")
            }
        }
    }

    // MARK: - Reordering within Preparing Sessions
    /// Reorder within the Completed subcolumn (and also handles moving in from other columns first).
    /// Places the `sourceID` session just before `beforeTargetID` if provided, otherwise appends to end of Completed.
    /// Returns true when the operation succeeded and UI should accept the drop.
    @discardableResult
    func reorderInCompleted(sourceID: UUID, beforeTargetID: UUID?) -> Bool {
        Task {
            guard let source = await fetchSessionFromRepository(byID: sourceID) else { return }

            // If source isn't completed yet, move it first
            if source.status != "completed" {
                await updateSessionStatus(sourceID, to: .completed)
            }

            // Note: Reordering is handled by repository's reorderSessions method
            // For now, we accept the drop and let the repository handle the ordering
            // UI will refresh after fetchData()
            await fetchData()
            objectWillChange.send()
        }
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
        Task {
            guard let source = await fetchSessionFromRepository(byID: sourceID),
                  let desiredStatus = statusString(for: column) else { return }

            if source.status != desiredStatus {
                await updateSessionStatus(sourceID, to: column)
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
                    if let scopeGroupID {
                        try? await sessionsRepository.groupSessions([sourceID], groupId: scopeGroupID)
                    } else {
                        try? await sessionsRepository.ungroupSessions([sourceID])
                    }
                    if let previousGroup, previousGroup != scopeGroupID {
                        await dissolveGroupIfSingleton(groupID: previousGroup)
                    }
                }
            } else if let previousGroup {
                try? await sessionsRepository.ungroupSessions([sourceID])
            }

            // Use repository reorder method
            try? await sessionsRepository.reorderSessions([sourceID], in: scopeGroupID)

            if supportsGrouping && column == .grouped {
                await reindexGroupedScope(scopeGroupID)
                if let previousGroup, previousGroup != scopeGroupID {
                    await reindexGroupedScope(previousGroup)
                }
            }

            await fetchData()
            objectWillChange.send()
        }
        return true
    }

    @discardableResult
    func reorderInvoices(in column: KanbanCardData.BillingColumnType, sourceID: UUID, beforeTargetID: UUID?) -> Bool {
        Task {
            guard let targetStatus = invoiceStatusString(for: column) else { return }
            
            // Update invoice status if needed
            if let invoice = _allInvoices.first(where: { $0.id == sourceID }) {
                if invoice.status != targetStatus {
                    await updateInvoiceStatus(sourceID, to: column)
                }
                
                // Note: Invoice ordering is handled by repository
                // The repository maintains order based on status and issueDate
                await fetchData()
                objectWillChange.send()
            }
        }
        return true
    }

    private func fetchInvoice(byID id: UUID) -> Invoice? {
        return _allInvoices.first(where: { $0.id == id })
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

    private func canonicalStatus(for invoice: Invoice) -> String {
        invoice.status ?? "draft"
    }

    // Note: Invoice ordering is handled by repository based on status and issueDate
    // No need for manual billingOrder management with domain models

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
        // Note: Travel rate info requires fetching client service data
        // For now, return nil - this would need repository access to ClientService/NDISItem
        // TODO: Implement travel rate lookup via repository if needed
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
}
