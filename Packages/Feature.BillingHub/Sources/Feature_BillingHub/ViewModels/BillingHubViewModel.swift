import Core
import Data
import Foundation
import Observation
import SwiftData
import SwiftUI

/// The main view model for the Billing Hub feature.
/// Refactored to use `@Observable` for UI state and `@ModelActor` for background logic.
///
/// Further decomposition (toolbar filters vs Kanban chrome vs workflow) is incremental—profile before splitting published fields so lists stay efficient.
@Observable
@MainActor
public final class BillingHubViewModel {
    
    // MARK: - UI State
    public var searchText: String = ""
    public var selectedClientID: UUID?
    public var isLoading: Bool = false
    public var bulkActionFeedback: String?
    public var dataRevision: Int = 0
    public var boardProjection: BillingHubBoardProjection = .empty
    
    
    /// Tracks sort options per column
    public var columnSortOptions: [KanbanCardData.BillingColumnType: ColumnSortOption] = [:]
    
    /// Feedback for bulk actions
    public var lastBulkUndoAction: BulkUndoAction?
    
    // MARK: - Dependencies
    let mainContextReads: BillingHubMainContextReads
    let workflow: BillingHubWorkflowActor
    
    let ndisBillingIntegrationService: NDISBillingIntegrationServiceProtocol
    let complianceValidator: NDISComplianceValidator?

    // MARK: - Initialization
    /// Pass the UI-bound `ModelContext` for this scene (typically SwiftUI’s environment context from
    /// `.modelContainer`, or an explicit manual-save context for Settings/previews) plus the same
    /// backing `ModelContainer`. This type does not resolve `ModelContainer.mainContext` itself.
    public init(
        modelContext: ModelContext,
        modelContainer: ModelContainer,
        ndisBillingIntegrationService: NDISBillingIntegrationServiceProtocol,
        complianceValidator: NDISComplianceValidator? = nil,
        storeChangeMonitor: SwiftDataStoreChangeMonitor? = nil
    ) {
        self.mainContextReads = BillingHubMainContextReads(modelContext: modelContext)
        self.workflow = BillingHubWorkflowActor(modelContainer: modelContainer)

        self.ndisBillingIntegrationService = ndisBillingIntegrationService
        self.complianceValidator = complianceValidator

        SwiftDataStoreChangeMonitor.subscribeToStoreChanges(monitor: storeChangeMonitor) { [weak self] revision in
            self?.dataRevision = revision
        }
    }

    
    // MARK: - Core Logic

    func sessionModelID(for sessionID: UUID) async -> PersistentIdentifier? {
        try? await workflow.persistentModelIDForSession(id: sessionID)
    }

    func invoiceModelID(for invoiceID: UUID) async -> PersistentIdentifier? {
        try? await workflow.persistentModelIDForInvoice(id: invoiceID)
    }

    public func refreshProjection() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let newProjection = try await workflow.fetchProjection(
                searchText: searchText,
                selectedClientID: selectedClientID,
                sortOptions: columnSortOptions
            )
            self.boardProjection = newProjection
        } catch {
            print("Failed to fetch projection: \(error)")
        }
    }

    /// Main-context fetch for relationship traversal (e.g. support logs) that must stay on the UI `ModelContext`.
    func fetchSessionOnMainContext(by sessionID: UUID) -> Session? {
        try? mainContextReads.fetchSession(id: sessionID)
    }

    func fetchInvoiceOnMainContext(by invoiceID: UUID) -> Invoice? {
        try? mainContextReads.fetchInvoice(id: invoiceID)
    }

    func sessionReferences(for sessionIDs: [UUID]) async -> [SessionWorkflowReference] {
        var refs: [SessionWorkflowReference] = []
        refs.reserveCapacity(sessionIDs.count)
        for sessionID in sessionIDs {
            guard let modelID = await sessionModelID(for: sessionID) else { continue }
            refs.append(SessionWorkflowReference(sessionID: sessionID, modelID: modelID))
        }
        return refs
    }
    
    func clientIdForFirstSession(in group: SessionGroup) async -> UUID? {
        guard let first = group.sessions.first, case .session(let card) = first else { return nil }
        return try? await workflow.clientIdForSession(id: card.sessionId)
    }
    
    // MARK: - UI Configuration & Statistics
    
    public struct ClientSummary: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let name: String
        public init(id: UUID, name: String) { self.id = id; self.name = name }
    }
    
    public var hasActiveFilters: Bool { !searchText.isEmpty || selectedClientID != nil }
    
    public var canUndoLastBulkAction: Bool { lastBulkUndoAction != nil }

    // MARK: - Actions

    public func selectClient(withID id: UUID?) {
        selectedClientID = id
        Task { await refreshProjection() }
    }
    
    public func clearFilters() {
        searchText = ""
        selectedClientID = nil
        Task { await refreshProjection() }
    }

    public func undoLastBulkAction() async {
        guard lastBulkUndoAction != nil else { return }
        // ... integration with workflow.undo ...
        lastBulkUndoAction = nil
    }

    public func clearBulkActionFeedback() { bulkActionFeedback = nil }
    
    // MARK: - Workflow Actions
    
    // Workflow, session, invoice, and reordering actions moved to extensions in BillingHubViewModel+Sessions.swift, BillingHubViewModel+Invoices.swift, and BillingHubViewModel+Reordering.swift
}

public struct TravelCalculationBreakdown: Sendable {
    public let labourTotal: Double
    public let nonLabourTotal: Double
    public let grossTotal: Double
    public let billableMinutes: Double
    public let requestedMinutes: Double
    public let totalPerParticipant: Double
}
