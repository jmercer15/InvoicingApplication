import Core
import PersistenceModels
import DataInterfaces
import Foundation
import InvoiceTableLayoutEditor
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
    /// Isolated from board observation — see `bulkProgress`.
    public let bulkProgress = BillingHubBulkProgressState()
    /// Board refresh failure. Existing projection stays visible when available so users never lose context.
    public var projectionLoadError: String?
    public var dataRevision: Int = 0
    public var boardProjection: BillingHubBoardProjection = .empty
    
    
    /// Tracks sort options per column
    public var columnSortOptions: [KanbanCardData.BillingColumnType: ColumnSortOption] = [:]
    
    /// Feedback for bulk actions
    public var bulkActionFeedback: String?
    public var lastBulkUndoAction: BulkUndoAction?

    /// Staged confirm when Hub would mutate a session already linked to an invoice.
    public var pendingInvoicedSessionAction: BillingHubInvoicedSessionAction?

    /// Confirmation gate for bulk Mark Payment Received (details omitted).
    public var pendingBulkPaymentReceivedConfirm: Bool = false

    /// Session/invoice card ids queued from Calendar nudge or Invoices "Back to Billing Hub".
    /// Consumed when the board projection contains a matching card (select + open sheet).
    public var pendingFocusCardIDs: [UUID] = []

    /// Settle attempts after `queueFocus` while projection still lacks a matching card.
    /// First miss keeps ids and refreshes; second miss reports and clears.
    public var focusAttempts: Int = 0

    public enum FocusSettleResult: Equatable, Sendable {
        case idle
        case focused(UUID)
        case retryNeeded
        case missed
    }

    /// Last presented / selected card — stamped when navigating to Invoices so return can restore.
    public var presentedCardID: UUID?
    public var selectedCardID: UUID?
    
    // MARK: - Dependencies
    let mainContextReads: BillingHubMainContextReads
    let workflow: BillingHubWorkflowActor
    let modelContainer: ModelContainer
    
    let ndisBillingIntegrationService: NDISBillingIntegrationServiceProtocol
    let complianceValidator: (any ComplianceValidating)?
    private(set) var invoiceCoordinator: BillingHubInvoiceOrchestrating!
    /// When set, Hub send/receipt/export prefer the live editor draft PDF for the open invoice.
    public weak var invoiceEditorSession: InvoiceEditorSession?

    /// Retains in-flight Mail compose hand-offs so they survive panel dismissal until the share
    /// genuinely completes, is cancelled, or fails. Entries remove themselves once finished.
    var activeMailComposers: [BillingHubMailComposer] = []

    var projectionRefreshTask: Task<Void, Never>?
    var projectionRefreshGeneration: UInt64 = 0

    /// Stable kanban action bundles — rebuilt only when sort options change (P-P1-4).
    private(set) var kanbanBoardActions: KanbanBoardActions!
    private(set) var kanbanCardActions: KanbanCardActions!
    private var kanbanActionsSortKey: KanbanActionsSortKey?

    private struct KanbanActionsSortKey: Equatable {
        let revision: Int
        let sortOptions: [KanbanCardData.BillingColumnType: ColumnSortOption]
    }

    // MARK: - Initialization
    /// Pass the UI-bound `ModelContext` for this scene (typically SwiftUI’s environment context from
    /// `.modelContainer`, or an explicit manual-save context for Settings/previews) plus the same
    /// backing `ModelContainer`. This type does not resolve `ModelContainer.mainContext` itself.
    public init(
        modelContext: ModelContext,
        modelContainer: ModelContainer,
        ndisBillingIntegrationService: NDISBillingIntegrationServiceProtocol,
        complianceValidator: (any ComplianceValidating)? = nil,
        storeChangeMonitor: (any StoreChangeMonitoring)? = nil,
        invoiceEditorSession: InvoiceEditorSession? = nil
    ) {
        self.mainContextReads = BillingHubMainContextReads(modelContext: modelContext)
        self.workflow = BillingHubWorkflowActor(modelContainer: modelContainer)
        self.modelContainer = modelContainer

        self.ndisBillingIntegrationService = ndisBillingIntegrationService
        self.complianceValidator = complianceValidator
        self.invoiceEditorSession = invoiceEditorSession
        self.invoiceCoordinator = BillingHubInvoiceCoordinator(
            host: self,
            workflow: workflow,
            modelContainer: modelContainer,
            ndisBillingIntegrationService: ndisBillingIntegrationService,
            complianceValidator: complianceValidator
        )

        StoreChangeMonitoringSubscription.subscribe(monitor: storeChangeMonitor) { [weak self] revision in
            self?.dataRevision = revision
        }

        kanbanBoardActions = Self.makeKanbanBoardActions(viewModel: self)
        kanbanCardActions = Self.makeKanbanCardActions(viewModel: self)
        kanbanActionsSortKey = KanbanActionsSortKey(revision: dataRevision, sortOptions: columnSortOptions)
    }

    func kanbanBoardActionsForCurrentSortOptions() -> KanbanBoardActions {
        let key = KanbanActionsSortKey(revision: dataRevision, sortOptions: columnSortOptions)
        if key == kanbanActionsSortKey, let kanbanBoardActions {
            return kanbanBoardActions
        }
        let actions = Self.makeKanbanBoardActions(viewModel: self)
        kanbanBoardActions = actions
        kanbanActionsSortKey = key
        return actions
    }

    func kanbanCardActionsForCurrentSortOptions() -> KanbanCardActions {
        _ = kanbanBoardActionsForCurrentSortOptions()
        return kanbanCardActions
    }

    private static func makeKanbanBoardActions(viewModel: BillingHubViewModel) -> KanbanBoardActions {
        KanbanBoardActions(
            formattedTotal: { [weak viewModel] column, projection in
                viewModel?.formattedTotal(for: column, in: projection)
            },
            sortOption: { [weak viewModel] column in
                viewModel?.sortOption(for: column)
            },
            setSortOption: { [weak viewModel] option, column in
                viewModel?.setSortOption(option, for: column)
            },
            reorderInvoices: { [weak viewModel] column, sourceID, beforeTargetID, projection in
                viewModel?.reorderInvoices(
                    in: column,
                    sourceID: sourceID,
                    beforeTargetID: beforeTargetID,
                    projection: projection
                )
            },
            moveSession: { [weak viewModel] sourceID, column in
                await viewModel?.moveSession(sourceID, to: column)
            },
            moveInvoice: { [weak viewModel] sourceID, column in
                await viewModel?.moveInvoice(sourceID, to: column)
            },
            addSessionToGroup: { [weak viewModel] sessionID, groupID in
                _ = await viewModel?.addSessionToGroup(sessionID: sessionID, groupID: groupID)
            },
            canAddSessionToGroup: { [weak viewModel] sessionID, groupID in
                viewModel?.canAddSessionToGroup(sourceID: sessionID, groupID: groupID) ?? false
            },
            groupSessionsSmooth: { [weak viewModel] sourceID, targetID in
                _ = await viewModel?.groupSessionsSmooth(sourceID: sourceID, targetID: targetID)
            }
        )
    }

    private static func makeKanbanCardActions(viewModel: BillingHubViewModel) -> KanbanCardActions {
        KanbanCardActions(
            nextColumn: { [weak viewModel] card in
                viewModel?.nextColumn(for: card)
            },
            advanceCard: { [weak viewModel] card in
                guard let viewModel else { return }
                _ = await viewModel.advanceCard(card)
            }
        )
    }

    
    // MARK: - Core Logic

    func sessionModelID(for sessionID: UUID) async -> PersistentIdentifier? {
        try? await workflow.persistentModelIDForSession(id: sessionID)
    }

    func sessionModelIDs(for sessionIDs: [UUID]) async -> [UUID: PersistentIdentifier] {
        (try? await workflow.persistentModelIDsForSessions(ids: sessionIDs)) ?? [:]
    }

    func invoiceModelID(for invoiceID: UUID) async -> PersistentIdentifier? {
        try? await workflow.persistentModelIDForInvoice(id: invoiceID)
    }

    public func refreshProjection() async {
        projectionRefreshTask?.cancel()
        projectionRefreshGeneration &+= 1
        let generation = projectionRefreshGeneration

        let task = Task { @MainActor in
            guard await Task.waitUnlessCancelled(for: .milliseconds(32)) else { return }
            guard !Task.isCancelled, self.projectionRefreshGeneration == generation else { return }

            self.isLoading = true
            self.projectionLoadError = nil
            defer {
                if self.projectionRefreshGeneration == generation {
                    self.isLoading = false
                }
            }

            do {
                try Task.checkCancellation()
                let newProjection = try await self.workflow.fetchProjection(
                    searchText: self.searchText,
                    selectedClientID: self.selectedClientID,
                    sortOptions: self.columnSortOptions
                )
                guard self.projectionRefreshGeneration == generation else { return }
                self.boardProjection = newProjection
            } catch is CancellationError {
                return
            } catch {
                guard self.projectionRefreshGeneration == generation else { return }
                self.projectionLoadError = "Billing work couldn’t refresh. Check the data store, then try again."
            }
        }
        projectionRefreshTask = task
        await task.value
    }

    /// Coalesced refresh for filter changes and retry actions without awaiting completion.
    public func scheduleProjectionRefresh() {
        Task { await refreshProjection() }
    }

    public func clearProjectionLoadError() {
        projectionLoadError = nil
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

    // MARK: - Focus / return continuity

    /// Queue Hub card focus from Calendar completion nudge (session ids) or Invoices back chip.
    public func queueFocus(cardIDs: [UUID]) {
        let unique = (pendingFocusCardIDs + cardIDs).reduce(into: [UUID]()) { result, id in
            if !result.contains(id) { result.append(id) }
        }
        guard !unique.isEmpty else { return }
        pendingFocusCardIDs = unique
        focusAttempts = 0
    }

    /// First pending focus id that exists on the current board; clears consumed ids.
    /// Prefers Completed-column session cards when multiple ids are queued.
    /// Unmatched ids stay pending until settle exhausts attempts via `settlePendingFocus`.
    public func consumeFocusCardID(from projection: BillingHubBoardProjection) -> UUID? {
        guard !pendingFocusCardIDs.isEmpty else { return nil }

        let completedIDs = Set((projection.sessionsByStatus[.completed] ?? []).map(\.id))
        if let completedMatch = pendingFocusCardIDs.first(where: { completedIDs.contains($0) }) {
            pendingFocusCardIDs.removeAll { $0 == completedMatch }
            return completedMatch
        }

        if let anyMatch = pendingFocusCardIDs.first(where: { projection.card(for: $0) != nil }) {
            pendingFocusCardIDs.removeAll { $0 == anyMatch }
            return anyMatch
        }

        return nil
    }

    /// After projection is idle: consume match, or keep pending for one settle refresh, then miss.
    public func settlePendingFocus(from projection: BillingHubBoardProjection) -> FocusSettleResult {
        guard !pendingFocusCardIDs.isEmpty else { return .idle }
        if let cardID = consumeFocusCardID(from: projection) {
            focusAttempts = 0
            return .focused(cardID)
        }
        focusAttempts += 1
        if focusAttempts < 2 {
            return .retryNeeded
        }
        reportFocusMissIfNeeded()
        return .missed
    }

    /// After a board refresh, clear stale focus ids that still have no matching card and surface feedback.
    public func reportFocusMissIfNeeded() {
        guard !pendingFocusCardIDs.isEmpty else { return }
        pendingFocusCardIDs = []
        focusAttempts = 0
        bulkActionFeedback = BillingHubFocusMissFeedback.message(hasActiveFilters: hasActiveFilters)
    }

    // MARK: - Actions

    public func selectClient(withID id: UUID?) {
        selectedClientID = id
        scheduleProjectionRefresh()
    }
    
    public func clearFilters() {
        searchText = ""
        selectedClientID = nil
        scheduleProjectionRefresh()
    }

    /// Returns `true` and stages a confirmation when the session already has an invoice.
    /// Caller should return early; `perform` runs only after the user confirms.
    @discardableResult
    public func requireInvoiceConfirmation(
        for sessionID: UUID,
        message: String,
        confirmTitle: String = "Continue",
        perform: @escaping () async -> Void
    ) -> Bool {
        guard let session = fetchSessionOnMainContext(by: sessionID), session.invoice != nil else {
            return false
        }
        pendingInvoicedSessionAction = BillingHubInvoicedSessionAction(
            message: message,
            confirmTitle: confirmTitle,
            perform: perform
        )
        return true
    }

    public func confirmPendingInvoicedSessionAction() {
        guard let action = pendingInvoicedSessionAction else { return }
        pendingInvoicedSessionAction = nil
        Task {
            await action.perform()
            if bulkActionFeedback == nil {
                bulkActionFeedback = "Invoiced session change applied."
            }
        }
    }

    public func cancelPendingInvoicedSessionAction() {
        pendingInvoicedSessionAction = nil
    }

    public func requestBulkMarkPaymentReceived() {
        pendingBulkPaymentReceivedConfirm = true
    }

    public func cancelBulkMarkPaymentReceived() {
        pendingBulkPaymentReceivedConfirm = false
    }

    public func undoLastBulkAction() async {
        guard let action = lastBulkUndoAction else { return }
        lastBulkUndoAction = nil
        do {
            if !action.snapshots.isEmpty {
                try await workflow.restoreInvoices(from: action.snapshots)
            }
            if !action.sessionSnapshots.isEmpty {
                try await workflow.restoreSessions(from: action.sessionSnapshots)
            }
            bulkActionFeedback = "Undid \(action.label)."
        } catch {
            bulkActionFeedback = "Could not undo \(action.label). \(error.localizedDescription)"
        }
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
    public let labourPerParticipant: Double
    public let nonLabourPerParticipant: Double
    /// Amount persisted for the selected `chargeType` (via `TravelChargePricingMath`).
    public let chargeAmount: Double
}
