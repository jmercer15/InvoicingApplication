import AppKit
import Core
import PersistenceModels
import Foundation
import InvoiceTableLayoutEditor
import SwiftData
import UniformTypeIdentifiers

/// Outcome of a draft-invoice creation attempt, surfaced so callers can decide whether to dismiss
/// their panel (only on total failure should it stay open) and can show `failedSessions` reasons.
public struct DraftInvoiceCreationOutcome: Sendable {
    public let invoiceID: UUID?
    public let successfulSessionsCount: Int
    public let failedSessions: [Core.NDISBillingIssue]
    public let warnings: [String]

    public var didCreateInvoice: Bool { invoiceID != nil }

    public init(
        invoiceID: UUID?,
        successfulSessionsCount: Int,
        failedSessions: [Core.NDISBillingIssue],
        warnings: [String] = []
    ) {
        self.invoiceID = invoiceID
        self.successfulSessionsCount = successfulSessionsCount
        self.failedSessions = failedSessions
        self.warnings = warnings
    }
}

@MainActor
protocol BillingHubInvoiceOrchestrating: AnyObject {
    @discardableResult
    func moveInvoice(_ id: UUID, to column: KanbanCardData.BillingColumnType) async -> MoveResult?
    func createDraftInvoicesForGroupedSessions(from projection: BillingHubBoardProjection) async
    func createDraftInvoice(fromGroupID groupID: UUID) async -> DraftInvoiceCreationOutcome?
    @discardableResult
    func createInvoiceFromSessions(_ sessionIDs: [UUID]) async -> DraftInvoiceCreationOutcome?
    func markReadyToSendInvoicesSent(from projection: BillingHubBoardProjection) async
    func completeAllPendingInvoices(from projection: BillingHubBoardProjection) async
    @discardableResult
    func updateInvoiceDetails(id: UUID, clientName: String) async -> Bool
    func fetchComplianceChecklist(for id: UUID) async throws -> Core.ComplianceValidationResult?
    @discardableResult
    func approveDraftInvoice(id: UUID, dueDate: Date) async -> Bool
    @discardableResult
    func requestChanges(for id: UUID, reason: String) async -> Bool
    func invoice(byId id: UUID) async -> Invoice?
    func updateInvoiceStatus(_ id: UUID, to column: KanbanCardData.BillingColumnType) async
    @discardableResult
    func markInvoiceSentManually(id: UUID) async -> Bool
    @discardableResult
    func sendInvoice(id: UUID, recipients: String, cc: String, subject: String, message: String, attachPDF: Bool, sendCopyToSelf: Bool) async -> Bool
    func sendTestInvoice(id: UUID, recipients: String, cc: String, subject: String, message: String, attachPDF: Bool) async
    func moveInvoiceBackToDraftReview(id: UUID) async -> Bool
    @discardableResult
    func finalizePayment(id: UUID, amount: String, date: Date, method: String, reference: String) async -> Bool
    @discardableResult
    func savePaymentDraft(id: UUID, amount: String, date: Date, method: String, reference: String) async -> Bool
    @discardableResult
    func markInvoiceOverdue(id: UUID) async -> Bool
    @discardableResult
    func moveInvoiceBackToReadyToSend(id: UUID) async -> Bool
    @discardableResult
    func reopenInvoiceAsPending(id: UUID) async -> Bool
    @discardableResult
    func sendReceipt(id: UUID, recipientEmail: String, includePDF: Bool) async -> Bool
    func exportReceiptPDF(id: UUID) async -> URL?
    func sendInvoiceWithOutcome(
        id: UUID,
        recipients: String,
        additionalRecipients: String,
        subject: String,
        message: String,
        attachPDF: Bool,
        sendCopyToSelf: Bool
    ) async -> BillingHubInvoiceSendOutcome
    func sendReceiptWithOutcome(
        id: UUID,
        recipientEmail: String,
        includePDF: Bool
    ) async -> BillingHubReceiptSendOutcome
    func exportReceiptPDFWithOutcome(id: UUID) async -> BillingHubReceiptExportOutcome
}

@MainActor
protocol BillingHubInvoiceCoordinatorHost: AnyObject {
    var bulkActionFeedback: String? { get set }
    var bulkProgress: BillingHubBulkProgressState { get }
    var isLoading: Bool { get set }
    var lastBulkUndoAction: BulkUndoAction? { get set }
    var invoiceEditorSession: InvoiceEditorSession? { get set }
    var activeMailComposers: [BillingHubMailComposer] { get set }
    var pendingBulkPaymentReceivedConfirm: Bool { get set }

    func invoiceModelID(for invoiceID: UUID) async -> PersistentIdentifier?
    func fetchInvoiceOnMainContext(by invoiceID: UUID) -> Invoice?
    func sessionReferences(for sessionIDs: [UUID]) async -> [SessionWorkflowReference]
    func clientIdForFirstSession(in group: SessionGroup) async -> UUID?
}

@MainActor
final class BillingHubInvoiceCoordinator: BillingHubInvoiceOrchestrating {
    private unowned let host: BillingHubInvoiceCoordinatorHost
    let workflow: BillingHubWorkflowActor
    let modelContainer: ModelContainer
    let ndisBillingIntegrationService: NDISBillingIntegrationServiceProtocol
    let complianceValidator: (any ComplianceValidating)?

    init(
        host: BillingHubInvoiceCoordinatorHost,
        workflow: BillingHubWorkflowActor,
        modelContainer: ModelContainer,
        ndisBillingIntegrationService: NDISBillingIntegrationServiceProtocol,
        complianceValidator: (any ComplianceValidating)?
    ) {
        self.host = host
        self.workflow = workflow
        self.modelContainer = modelContainer
        self.ndisBillingIntegrationService = ndisBillingIntegrationService
        self.complianceValidator = complianceValidator
    }



    @discardableResult
    public func moveInvoice(_ id: UUID, to column: KanbanCardData.BillingColumnType) async -> MoveResult? {
        guard let modelID = await host.invoiceModelID(for: id) else { return nil }
        do {
            let result = try await workflow.moveInvoice(modelID: modelID, to: column, complianceValidator: complianceValidator)
            switch result {
            case .successWithComplianceWarnings:
                host.bulkActionFeedback = BillingHubBoardCopy.movedInvoiceWithComplianceWarnings(
                    to: column
                )
            case .blocked(let message):
                host.bulkActionFeedback = message
            case .invalidTransition, .notFound, .clientMismatch:
                host.bulkActionFeedback = result.description
            case .success:
                host.bulkActionFeedback = BillingHubBoardCopy.movedRecord(
                    "Invoice",
                    to: column
                )
            }
            return result
        } catch {
            host.bulkActionFeedback = "Invoice could not be moved. \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Draft Creation

    public func createDraftInvoicesForGroupedSessions(from projection: BillingHubBoardProjection) async {
        guard !host.bulkProgress.isCreatingDrafts else {
            host.bulkActionFeedback = "Draft creation already in progress."
            return
        }
        let groups = projection.groupedSessions
        guard !groups.isEmpty else { return }
        host.bulkProgress.isCreatingDrafts = true
        host.isLoading = true
        host.bulkActionFeedback = nil
        let total = groups.count
        host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
            action: "Creating drafts",
            completedCount: 0,
            totalCount: total
        )
        defer {
            host.bulkProgress.isCreatingDrafts = false
            host.isLoading = false
            host.bulkProgress.bulkActionProgress = nil
        }

        var created = 0
        var failedSessionCount = 0
        var firstFailureReason: String?
        var firstWarning: String?
        for (index, group) in groups.enumerated() {
            guard let clientId = await host.clientIdForFirstSession(in: group) else {
                host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
                    action: "Creating drafts",
                    completedCount: index + 1,
                    totalCount: total
                )
                continue
            }
            let sessionReferences = await host.sessionReferences(for: group.sessions.map(\.id))
            guard !sessionReferences.isEmpty else {
                host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
                    action: "Creating drafts",
                    completedCount: index + 1,
                    totalCount: total
                )
                continue
            }
            do {
                let report = try await workflow.createDraftInvoices(
                    sessions: sessionReferences,
                    clientID: clientId,
                    ndisService: ndisBillingIntegrationService
                )
                if report.invoice != nil { created += 1 }
                if !report.failedSessions.isEmpty {
                    failedSessionCount += report.failedSessions.count
                    if firstFailureReason == nil {
                        firstFailureReason = report.failedSessions.first.map { "\($0.sessionTitle): \($0.reason)" }
                    }
                }
                if firstWarning == nil, let warning = report.warnings.first {
                    firstWarning = warning
                }
            } catch {
                failedSessionCount += sessionReferences.count
                if firstFailureReason == nil {
                    firstFailureReason = error.localizedDescription
                }
            }
            host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
                action: "Creating drafts",
                completedCount: index + 1,
                totalCount: total
            )
        }

        if created > 0 {
            var message = "Created \(created) draft invoice\(created == 1 ? "" : "s")."
            if failedSessionCount > 0 {
                message += " \(failedSessionCount) session\(failedSessionCount == 1 ? "" : "s") skipped\(firstFailureReason.map { " (\($0))" } ?? "")."
            }
            if let firstWarning {
                message += " Warning: \(firstWarning)"
            }
            host.bulkActionFeedback = message
        } else if failedSessionCount > 0 {
            host.bulkActionFeedback = "No draft invoices could be created.\(firstFailureReason.map { " \($0)" } ?? "")"
        }
    }

    /// Creates one draft invoice from every session currently in a group. Returns `nil` when the
    /// group could not be resolved at all (caller should treat this the same as a total failure).
    public func createDraftInvoice(fromGroupID groupID: UUID) async -> DraftInvoiceCreationOutcome? {
        let sessionReferences: [SessionWorkflowReference]
        do {
            sessionReferences = try await workflow.sessionWorkflowReferencesForGroup(groupID: groupID)
        } catch {
            host.bulkActionFeedback = "Could not load sessions for this group. \(error.localizedDescription)"
            return nil
        }
        let sessionIDs = sessionReferences.map(\.sessionID)
        guard !sessionIDs.isEmpty else {
            host.bulkActionFeedback = "This group has no sessions to invoice."
            return nil
        }
        return await createInvoiceFromSessions(sessionIDs)
    }

    /// Idempotent, in-flight-safe draft creation for an explicit set of sessions. Always sets
    /// `bulkActionFeedback` (success, partial success, or total failure) so the outcome is visible
    /// even if the caller keeps its panel open. Shares `isCreatingDrafts` with bulk create.
    @discardableResult
    public func createInvoiceFromSessions(_ sessionIDs: [UUID]) async -> DraftInvoiceCreationOutcome? {
        guard !host.bulkProgress.isCreatingDrafts else {
            host.bulkActionFeedback = "Draft creation already in progress."
            return nil
        }
        host.bulkProgress.isCreatingDrafts = true
        host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
            action: "Creating draft",
            completedCount: 0,
            totalCount: 1
        )
        defer {
            host.bulkProgress.isCreatingDrafts = false
            host.bulkProgress.bulkActionProgress = nil
        }

        let sessionReferences = await host.sessionReferences(for: sessionIDs)
        guard !sessionReferences.isEmpty else {
            host.bulkActionFeedback = "Selected sessions could not be found."
            return nil
        }

        var clientIDs: Set<UUID> = []
        for sessionID in sessionIDs {
            if let clientID = try? await workflow.clientIdForSession(id: sessionID) {
                clientIDs.insert(clientID)
            }
        }
        guard clientIDs.count == 1, let clientID = clientIDs.first else {
            host.bulkActionFeedback = clientIDs.isEmpty
                ? "Could not resolve a client for the selected sessions."
                : "Sessions must belong to the same client before creating a draft invoice."
            return DraftInvoiceCreationOutcome(
                invoiceID: nil,
                successfulSessionsCount: 0,
                failedSessions: sessionIDs.map {
                    Core.NDISBillingIssue(sessionId: $0, sessionTitle: "Session", reason: "Mixed or missing client")
                }
            )
        }

        do {
            let report = try await workflow.createDraftInvoices(
                sessions: sessionReferences,
                clientID: clientID,
                ndisService: ndisBillingIntegrationService
            )
            let outcome = DraftInvoiceCreationOutcome(
                invoiceID: report.invoice?.id,
                successfulSessionsCount: report.successfulSessionsCount,
                failedSessions: report.failedSessions,
                warnings: report.warnings
            )
            host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
                action: "Creating draft",
                completedCount: 1,
                totalCount: 1
            )
            host.bulkActionFeedback = Self.feedbackMessage(for: outcome)
            return outcome
        } catch {
            host.bulkActionFeedback = "Draft invoice could not be created. \(error.localizedDescription)"
            return nil
        }
    }

    private static func feedbackMessage(for outcome: DraftInvoiceCreationOutcome) -> String {
        let reasons = outcome.failedSessions.map { "\($0.sessionTitle): \($0.reason)" }.joined(separator: "; ")
        let warningText = outcome.warnings.joined(separator: "; ")
        if outcome.didCreateInvoice {
            var message = "Created draft invoice for \(outcome.successfulSessionsCount) session\(outcome.successfulSessionsCount == 1 ? "" : "s")."
            if !outcome.failedSessions.isEmpty {
                message += " \(outcome.failedSessions.count) skipped — \(reasons)"
            }
            if !warningText.isEmpty {
                message += " Warning: \(warningText)"
            }
            return message
        }
        return reasons.isEmpty ? "Draft invoice could not be created." : "Draft invoice could not be created. \(reasons)"
    }

    // MARK: - Bulk Status Actions

    /// Bulk "Mark Sent" for the Ready to Send column. This only flips status + `sentDate`; it is
    /// deliberately not a bulk-email action (there is no multi-Mail-compose automation). Use the
    /// per-invoice Send in `ReadyToSendPanel` to actually email a PDF.
    public func markReadyToSendInvoicesSent(from projection: BillingHubBoardProjection) async {
        guard !host.bulkProgress.isBulkProcessing else { return }
        let invoices = projection.invoicesByStatus[.readyToSend] ?? []
        guard !invoices.isEmpty else { return }
        host.bulkProgress.isBulkProcessing = true
        host.bulkActionFeedback = nil
        let total = invoices.count
        host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
            action: BillingHubWorkflowCopy.bulkMarkSentProgressAction,
            completedCount: 0,
            totalCount: total
        )
        defer {
            host.bulkProgress.isBulkProcessing = false
            host.bulkProgress.bulkActionProgress = nil
        }

        let ids = invoices.map(\.id)
        let snapshots = invoiceSnapshots(for: ids)
        do {
            if let validator = complianceValidator {
                let results = try await validator.validateBulkInvoices(invoiceIds: ids, action: .bulkSendReady)
                let allowed = ids.filter { !(results[$0]?.isBlocked ?? true) }
                var blockedCount = ids.count - allowed.count
                var allowedModelIDs: [PersistentIdentifier] = []
                for (index, invoiceId) in allowed.enumerated() {
                    if let mid = await host.invoiceModelID(for: invoiceId) { allowedModelIDs.append(mid) }
                    host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
                        action: BillingHubWorkflowCopy.bulkMarkSentProgressAction,
                        completedCount: index + 1,
                        totalCount: total
                    )
                }
                blockedCount += allowed.count - allowedModelIDs.count
                let processedCount: Int
                if allowedModelIDs.isEmpty {
                    processedCount = 0
                } else {
                    processedCount = try await workflow.bulkUpdateInvoices(modelIDs: allowedModelIDs, targetStatus: .pending) { invoice in
                        invoice.sentDate = Date()
                    }
                }
                host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
                    action: BillingHubWorkflowCopy.bulkMarkSentProgressAction,
                    completedCount: total,
                    totalCount: total
                )
                if processedCount > 0 {
                    host.lastBulkUndoAction = BulkUndoAction(
                        label: BillingHubWorkflowCopy.markSentWithoutEmail,
                        snapshots: snapshots.filter { allowed.contains($0.id) }
                    )
                }
                if processedCount > 0 || blockedCount > 0 {
                    host.bulkActionFeedback = BillingHubWorkflowCopy.bulkMarkSentResult(
                        processed: processedCount,
                        blocked: blockedCount
                    )
                }
            } else {
                var modelIDs: [PersistentIdentifier] = []
                for (index, invoiceId) in ids.enumerated() {
                    if let mid = await host.invoiceModelID(for: invoiceId) { modelIDs.append(mid) }
                    host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
                        action: BillingHubWorkflowCopy.bulkMarkSentProgressAction,
                        completedCount: index + 1,
                        totalCount: total
                    )
                }
                let count = try await workflow.bulkUpdateInvoices(modelIDs: modelIDs, targetStatus: .pending) { invoice in
                    invoice.sentDate = Date()
                }
                host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
                    action: BillingHubWorkflowCopy.bulkMarkSentProgressAction,
                    completedCount: total,
                    totalCount: total
                )
                if count > 0 {
                    host.lastBulkUndoAction = BulkUndoAction(
                        label: BillingHubWorkflowCopy.markSentWithoutEmail,
                        snapshots: snapshots
                    )
                    host.bulkActionFeedback = BillingHubWorkflowCopy.bulkMarkSentResult(
                        processed: count,
                        blocked: 0
                    )
                }
            }
        } catch {
            host.bulkActionFeedback = "\(BillingHubWorkflowCopy.markSentWithoutEmail) failed. \(error.localizedDescription)"
        }
    }

    public func completeAllPendingInvoices(from projection: BillingHubBoardProjection) async {
        guard !host.bulkProgress.isBulkProcessing else { return }
        host.pendingBulkPaymentReceivedConfirm = false
        let invoices = projection.invoicesByStatus[.pending] ?? []
        guard !invoices.isEmpty else { return }
        host.bulkProgress.isBulkProcessing = true
        host.bulkActionFeedback = nil
        let total = invoices.count
        host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
            action: BillingHubWorkflowCopy.bulkPaymentProgressAction,
            completedCount: 0,
            totalCount: total
        )
        defer {
            host.bulkProgress.isBulkProcessing = false
            host.bulkProgress.bulkActionProgress = nil
        }

        let ids = invoices.map(\.id)
        let snapshots = invoiceSnapshots(for: ids)
        do {
            if let validator = complianceValidator {
                let results = try await validator.validateBulkInvoices(invoiceIds: ids, action: .bulkCompletePending)
                let allowed = ids.filter { !(results[$0]?.isBlocked ?? true) }
                var blockedCount = ids.count - allowed.count
                var allowedModelIDs: [PersistentIdentifier] = []
                for (index, invoiceId) in allowed.enumerated() {
                    if let mid = await host.invoiceModelID(for: invoiceId) { allowedModelIDs.append(mid) }
                    host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
                        action: BillingHubWorkflowCopy.bulkPaymentProgressAction,
                        completedCount: index + 1,
                        totalCount: total
                    )
                }
                blockedCount += allowed.count - allowedModelIDs.count
                let processedCount: Int
                if allowedModelIDs.isEmpty {
                    processedCount = 0
                } else {
                    processedCount = try await workflow.bulkUpdateInvoices(modelIDs: allowedModelIDs, targetStatus: .received) { invoice in
                        if invoice.paidDate == nil { invoice.paidDate = Date() }
                    }
                }
                host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
                    action: BillingHubWorkflowCopy.bulkPaymentProgressAction,
                    completedCount: total,
                    totalCount: total
                )
                if processedCount > 0 {
                    host.lastBulkUndoAction = BulkUndoAction(
                        label: "Mark Payment Received Without Details",
                        snapshots: snapshots.filter { allowed.contains($0.id) }
                    )
                }
                if processedCount > 0 || blockedCount > 0 {
                    host.bulkActionFeedback = BillingHubWorkflowCopy.bulkPaymentResult(
                        processed: processedCount,
                        blocked: blockedCount
                    )
                }
            } else {
                var modelIDs: [PersistentIdentifier] = []
                for (index, invoiceId) in ids.enumerated() {
                    if let mid = await host.invoiceModelID(for: invoiceId) { modelIDs.append(mid) }
                    host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
                        action: BillingHubWorkflowCopy.bulkPaymentProgressAction,
                        completedCount: index + 1,
                        totalCount: total
                    )
                }
                let count = try await workflow.bulkUpdateInvoices(modelIDs: modelIDs, targetStatus: .received) { invoice in
                    if invoice.paidDate == nil { invoice.paidDate = Date() }
                }
                host.bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
                    action: BillingHubWorkflowCopy.bulkPaymentProgressAction,
                    completedCount: total,
                    totalCount: total
                )
                if count > 0 {
                    host.lastBulkUndoAction = BulkUndoAction(
                        label: "Mark Payment Received Without Details",
                        snapshots: snapshots
                    )
                    host.bulkActionFeedback = BillingHubWorkflowCopy.bulkPaymentResult(
                        processed: count,
                        blocked: 0
                    )
                }
            }
        } catch {
            host.bulkActionFeedback = "Mark Payment Received Without Details failed. \(error.localizedDescription)"
        }
    }

    private func invoiceSnapshots(for ids: [UUID]) -> [InvoiceWorkflowSnapshot] {
        ids.compactMap { id in
            guard let invoice = host.fetchInvoiceOnMainContext(by: id) else { return nil }
            return InvoiceWorkflowSnapshot(
                id: invoice.id,
                status: invoice.status?.rawValue ?? "",
                sentDate: invoice.sentDate,
                paidDate: invoice.paidDate,
                notes: invoice.notes
            )
        }
    }

    @discardableResult
    public func updateInvoiceDetails(id: UUID, clientName: String) async -> Bool {
        guard let modelID = await host.invoiceModelID(for: id) else {
            host.bulkActionFeedback = "Invoice could not be found."
            return false
        }
        do {
            try await workflow.updateInvoiceDetails(modelID: modelID, clientName: clientName)
            return true
        } catch {
            host.bulkActionFeedback = "Invoice details could not be saved. \(error.localizedDescription)"
            return false
        }
    }

    public func fetchComplianceChecklist(for id: UUID) async throws -> Core.ComplianceValidationResult? {
        guard let complianceValidator else { return nil }
        return try await complianceValidator.validateInvoiceTransition(
            invoiceId: id,
            action: .approveDraft
        )
    }

    // MARK: - Review Drafts

    /// Writes the approved due date onto the invoice before moving it to Ready to Send.
    /// - Returns: `true` when the invoice actually moved (panel may dismiss). Blocked / failed keep the sheet open.
    @discardableResult
    public func approveDraftInvoice(id: UUID, dueDate: Date) async -> Bool {
        guard let modelID = await host.invoiceModelID(for: id) else { return false }
        do {
            let result = try await workflow.approveDraftInvoice(
                modelID: modelID,
                dueDate: dueDate,
                complianceValidator: complianceValidator
            )
            switch result {
            case .successWithComplianceWarnings:
                host.bulkActionFeedback = BillingHubBoardCopy.movedInvoiceWithComplianceWarnings(
                    to: .readyToSend
                )
            case .success:
                host.bulkActionFeedback = BillingHubBoardCopy.movedRecord("Invoice", to: .readyToSend)
            case .blocked(let message):
                host.bulkActionFeedback = message
            case .invalidTransition, .notFound, .clientMismatch:
                host.bulkActionFeedback = result.description
            }
            return result.isSuccess
        } catch {
            host.bulkActionFeedback = "Draft could not be approved. \(error.localizedDescription)"
            return false
        }
    }

    /// Flags a draft as needing revisions with a real note + feedback, instead of a silent no-op.
    /// The invoice already lives in Review Drafts, so this doesn't need a column move.
    /// - Returns: `true` when the note was saved (panel may dismiss).
    @discardableResult
    public func requestChanges(for id: UUID, reason: String) async -> Bool {
        guard let modelID = await host.invoiceModelID(for: id) else {
            host.bulkActionFeedback = "Invoice could not be found."
            return false
        }
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty else {
            host.bulkActionFeedback = "Add a short note about what needs changing."
            return false
        }
        let stamp = Date().formatted(.dateTime.day().month().year().hour().minute())
        let noteLine = "Changes requested \(stamp): \(trimmedReason)"
        do {
            try await workflow.updateInvoice(modelID: modelID) { invoice in
                let existing = invoice.notes ?? ""
                invoice.notes = existing.isEmpty ? noteLine : existing + "\n" + noteLine
            }
            host.bulkActionFeedback = "Marked for changes. Invoice stays in Review Drafts."
            return true
        } catch {
            host.bulkActionFeedback = "Could not flag invoice for changes. \(error.localizedDescription)"
            return false
        }
    }

    public func invoice(byId id: UUID) async -> Invoice? {
        host.fetchInvoiceOnMainContext(by: id)
    }

    public func updateInvoiceStatus(_ id: UUID, to column: KanbanCardData.BillingColumnType) async {
        await moveInvoice(id, to: column)
    }

    // MARK: - Ready to Send

    /// Manual fallback for delivery that happened outside the app. Unlike `sendInvoice`, this
    /// never composes an email — it just records that the invoice was sent.
    /// - Returns: `true` when status was updated (panel may dismiss).
    @discardableResult
    public func markInvoiceSentManually(id: UUID) async -> Bool {
        guard let modelID = await host.invoiceModelID(for: id) else {
            host.bulkActionFeedback = "Invoice could not be found."
            return false
        }
        do {
            let count = try await workflow.bulkUpdateInvoices(modelIDs: [modelID], targetStatus: .pending) { invoice in
                invoice.sentDate = Date()
            }
            guard count > 0 else {
                host.bulkActionFeedback = "Invoice could not be marked sent."
                return false
            }
            host.bulkActionFeedback = "Invoice marked sent."
            return true
        } catch {
            host.bulkActionFeedback = "Invoice could not be marked sent. \(error.localizedDescription)"
            return false
        }
    }

    /// Builds the invoice PDF (when requested), hands off to Mail via `NSSharingService`, and only
    /// advances the invoice to Pending + `sentDate` once the share genuinely completes. Cancelling
    /// the Mail compose window leaves the invoice untouched.
    /// - Returns: `true` when the panel should dismiss (Mail completed **and** status write
    ///   succeeded). Cancel / Mail failure / status-write failure keep the compose form open.
    @discardableResult
    public func sendInvoice(
        id: UUID,
        recipients: String,
        cc: String,
        subject: String,
        message: String,
        attachPDF: Bool,
        sendCopyToSelf: Bool
    ) async -> Bool {
        let outcome = await sendInvoiceWithOutcome(
            id: id,
            recipients: recipients,
            additionalRecipients: cc,
            subject: subject,
            message: message,
            attachPDF: attachPDF,
            sendCopyToSelf: sendCopyToSelf
        )
        return outcome.shouldDismiss
    }

    func sendInvoiceWithOutcome(
        id: UUID,
        recipients: String,
        additionalRecipients: String,
        subject: String,
        message: String,
        attachPDF: Bool,
        sendCopyToSelf: Bool
    ) async -> BillingHubInvoiceSendOutcome {
        guard let invoice = host.fetchInvoiceOnMainContext(by: id) else {
            return publishInvoiceSendOutcome(.failed("Invoice could not be found."))
        }
        let invalidAddresses = BillingHubEmailRecipients.invalidAddresses(in: recipients)
            + BillingHubEmailRecipients.invalidAddresses(in: additionalRecipients)
        guard invalidAddresses.isEmpty else {
            return publishInvoiceSendOutcome(
                readyToSendFailure("Fix invalid email addresses before sending.")
            )
        }
        guard !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return publishInvoiceSendOutcome(
                readyToSendFailure("Add an email subject before sending.")
            )
        }

        var addresses = BillingHubEmailRecipients.parse(recipients)
            + BillingHubEmailRecipients.parse(additionalRecipients)
        if sendCopyToSelf {
            guard let businessEmail = BillingHubEmailRecipients.validSingleAddress(invoice.businessEmail) else {
                return publishInvoiceSendOutcome(
                    readyToSendFailure("Add a valid business email before sending yourself a copy.")
                )
            }
            addresses.append(businessEmail)
        }
        addresses = BillingHubEmailRecipients.unique(addresses)
        guard !addresses.isEmpty else {
            return publishInvoiceSendOutcome(
                readyToSendFailure("Add at least one recipient before sending.")
            )
        }
        guard let service = NSSharingService(named: .composeEmail) else {
            return publishInvoiceSendOutcome(
                readyToSendFailure("No email app is configured on this Mac.")
            )
        }
        service.recipients = addresses
        service.subject = subject

        var items: [Any] = [message as NSString]
        var temporaryPDF: InvoiceTemporaryPDF?
        if attachPDF {
            do {
                let pdf = try await temporaryPDFDocument(invoiceID: id, presentation: .invoice)
                temporaryPDF = pdf
                items.append(pdf.url as NSURL)
            } catch {
                return publishInvoiceSendOutcome(
                    readyToSendFailure(
                        "Invoice PDF could not be created. \(error.localizedDescription)"
                    )
                )
            }
        }

        let outcome = await performMailShare(service: service, items: items, temporaryPDF: temporaryPDF)
        switch outcome {
        case .completed:
            guard let modelID = await host.invoiceModelID(for: id) else {
                return publishInvoiceSendOutcome(.emailSentStatusPending(nil))
            }
            do {
                let count = try await workflow.bulkUpdateInvoices(modelIDs: [modelID], targetStatus: .pending) { invoice in
                    invoice.sentDate = Date()
                }
                guard count > 0 else {
                    return publishInvoiceSendOutcome(.emailSentStatusPending(nil))
                }
                return publishInvoiceSendOutcome(.sent(invoiceNumber: invoice.invoiceNumber))
            } catch {
                return publishInvoiceSendOutcome(
                    .emailSentStatusPending(error.localizedDescription)
                )
            }
        case .cancelled:
            return publishInvoiceSendOutcome(.cancelled)
        case .failed(let failureMessage):
            return publishInvoiceSendOutcome(readyToSendFailure(failureMessage))
        }
    }

    /// Same Mail compose as `sendInvoice`, but never changes invoice status regardless of outcome.
    public func sendTestInvoice(
        id: UUID,
        recipients: String,
        cc: String,
        subject: String,
        message: String,
        attachPDF: Bool
    ) async {
        guard host.fetchInvoiceOnMainContext(by: id) != nil else {
            host.bulkActionFeedback = "Invoice could not be found."
            return
        }
        let invalidAddresses = BillingHubEmailRecipients.invalidAddresses(in: recipients)
            + BillingHubEmailRecipients.invalidAddresses(in: cc)
        guard invalidAddresses.isEmpty else {
            host.bulkActionFeedback = "Fix invalid email addresses before sending a test."
            return
        }
        let addresses = BillingHubEmailRecipients.parse(recipients) + BillingHubEmailRecipients.parse(cc)
        guard !addresses.isEmpty else {
            host.bulkActionFeedback = "Add at least one recipient before sending a test."
            return
        }
        guard let service = NSSharingService(named: .composeEmail) else {
            host.bulkActionFeedback = "No email app is configured on this Mac."
            return
        }
        service.recipients = addresses
        service.subject = "[Test] \(subject)"

        var items: [Any] = [message as NSString]
        var temporaryPDF: InvoiceTemporaryPDF?
        if attachPDF {
            do {
                let pdf = try await temporaryPDFDocument(invoiceID: id, presentation: .invoice)
                temporaryPDF = pdf
                items.append(pdf.url as NSURL)
            } catch {
                host.bulkActionFeedback = "Test PDF could not be created. \(error.localizedDescription)"
                return
            }
        }

        let outcome = await performMailShare(service: service, items: items, temporaryPDF: temporaryPDF)
        switch outcome {
        case .completed:
            host.bulkActionFeedback = "Test email sent. Invoice status unchanged."
        case .cancelled:
            host.bulkActionFeedback = "Test email cancelled."
        case .failed(let failureMessage):
            host.bulkActionFeedback = failureMessage
        }
        // Status intentionally never changes for a test send.
    }

    public func moveInvoiceBackToDraftReview(id: UUID) async -> Bool {
        let result = await moveInvoice(id, to: .reviewDrafts)
        return result?.isSuccess == true
    }

    // MARK: - Pending Payment

    /// Records the payment (paid date + a `Payment: …` note line) and moves the invoice to
    /// Payment Received. Amount mismatch vs invoice total emits warning feedback but still allows
    /// finalize (partial / overpayment OK).
    /// - Returns: `true` when payment was recorded (panel may dismiss).
    @discardableResult
    public func finalizePayment(id: UUID, amount: String, date: Date, method: String, reference: String) async -> Bool {
        guard BillingHubPaymentAmount.isValid(amount) else {
            host.bulkActionFeedback = "Enter a payment amount greater than zero."
            return false
        }
        guard let modelID = await host.invoiceModelID(for: id) else {
            host.bulkActionFeedback = "Invoice could not be found."
            return false
        }
        guard let invoice = host.fetchInvoiceOnMainContext(by: id) else {
            host.bulkActionFeedback = "Invoice could not be found."
            return false
        }
        let amountMismatchWarning = BillingHubPaymentAmount.mismatchWarning(
            entered: amount,
            invoiceTotal: NSDecimalNumber(decimal: invoice.totalAmount).doubleValue
        )
        let updatedNotes = BillingHubPaymentNoteFormatter.applyingPaymentLine(
            amount: amount, date: date, method: method, reference: reference, to: invoice.notes
        )
        do {
            let count = try await workflow.bulkUpdateInvoices(modelIDs: [modelID], targetStatus: .received) { invoice in
                invoice.paidDate = date
                invoice.notes = updatedNotes
            }
            guard count > 0 else {
                host.bulkActionFeedback = "Payment could not be recorded. Invoice could not be found."
                return false
            }
            if let amountMismatchWarning {
                host.bulkActionFeedback = "Payment recorded. \(amountMismatchWarning)"
            } else {
                host.bulkActionFeedback = "Payment recorded."
            }
            return true
        } catch {
            host.bulkActionFeedback = "Payment could not be recorded. \(error.localizedDescription)"
            return false
        }
    }

    /// Persists the payment details as a note line only — no status change. Useful for recording
    /// a partial or unconfirmed payment without prematurely marking the invoice Completed.
    /// - Returns: `true` when the note was saved (panel may dismiss).
    @discardableResult
    public func savePaymentDraft(id: UUID, amount: String, date: Date, method: String, reference: String) async -> Bool {
        guard BillingHubPaymentAmount.isValid(amount) else {
            host.bulkActionFeedback = "Enter a payment amount greater than zero."
            return false
        }
        guard let modelID = await host.invoiceModelID(for: id) else {
            host.bulkActionFeedback = "Invoice could not be found."
            return false
        }
        guard let invoice = host.fetchInvoiceOnMainContext(by: id) else {
            host.bulkActionFeedback = "Invoice could not be found."
            return false
        }
        let updatedNotes = BillingHubPaymentNoteFormatter.applyingPaymentLine(
            amount: amount, date: date, method: method, reference: reference, to: invoice.notes
        )
        do {
            let didUpdate = try await workflow.updateInvoice(modelID: modelID) { invoice in
                invoice.notes = updatedNotes
            }
            guard didUpdate else {
                host.bulkActionFeedback = "Payment note could not be saved. Invoice could not be found."
                return false
            }
            host.bulkActionFeedback = "Payment details saved as a note. Status unchanged."
            return true
        } catch {
            host.bulkActionFeedback = "Payment note could not be saved. \(error.localizedDescription)"
            return false
        }
    }

    /// Writes `InvoiceStatus.overdue` directly (not a `BillingStatus` column transition).
    /// - Returns: `true` when the overdue flag was written (panel may dismiss).
    @discardableResult
    public func markInvoiceOverdue(id: UUID) async -> Bool {
        guard let modelID = await host.invoiceModelID(for: id) else {
            host.bulkActionFeedback = "Invoice could not be found."
            return false
        }
        do {
            let didUpdate = try await workflow.markInvoiceOverdue(modelID: modelID)
            host.bulkActionFeedback = didUpdate ? "Invoice marked overdue." : "Invoice could not be found."
            return didUpdate
        } catch {
            host.bulkActionFeedback = "Invoice could not be marked overdue. \(error.localizedDescription)"
            return false
        }
    }

    /// - Returns: `true` when the invoice actually moved (panel may dismiss).
    @discardableResult
    public func moveInvoiceBackToReadyToSend(id: UUID) async -> Bool {
        let result = await moveInvoice(id, to: .readyToSend)
        return result?.isSuccess == true
    }

    /// Atomically moves a received invoice back to Sent/Pending, clears `paidDate`, and strips the
    /// `Payment:` note line. Other invoice notes and the original sent date remain unchanged.
    /// - Returns: `true` when the invoice actually moved (panel may dismiss).
    @discardableResult
    public func reopenInvoiceAsPending(id: UUID) async -> Bool {
        guard let modelID = await host.invoiceModelID(for: id),
              let invoice = host.fetchInvoiceOnMainContext(by: id) else {
            host.bulkActionFeedback = "Invoice could not be found."
            return false
        }
        guard invoice.effectiveStatus == .received else {
            host.bulkActionFeedback = "Only invoices with payment received can be reopened as Sent."
            return false
        }
        let cleanedNotes = BillingHubPaymentNoteFormatter.removingPaymentLine(from: invoice.notes)
        do {
            let count = try await workflow.bulkUpdateInvoices(
                modelIDs: [modelID],
                targetStatus: .pending
            ) { invoice in
                invoice.paidDate = nil
                invoice.notes = cleanedNotes
            }
            guard count > 0 else {
                host.bulkActionFeedback = "Invoice could not be reopened."
                return false
            }
            host.bulkActionFeedback = "Invoice reopened as Sent. Paid date and payment details cleared."
            return true
        } catch {
            host.bulkActionFeedback = "Invoice could not be reopened. \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Payment Received

    /// Builds an honest receipt email and returns a typed Mail outcome. Invoice status never changes.
    @discardableResult
    func sendReceiptWithOutcome(
        id: UUID,
        recipientEmail: String,
        includePDF: Bool
    ) async -> BillingHubReceiptSendOutcome {
        guard let invoice = host.fetchInvoiceOnMainContext(by: id) else {
            return publishReceiptSendOutcome(.failed("Invoice could not be found."))
        }
        if let message = BillingHubReceiptReadiness.message(
            paidDate: invoice.paidDate,
            notes: invoice.notes,
            isPaymentReceived: invoice.effectiveStatus == .received
        ) {
            return publishReceiptSendOutcome(.failed(message))
        }
        guard BillingHubEmailRecipients.invalidAddresses(in: recipientEmail).isEmpty else {
            return publishReceiptSendOutcome(
                .failed("Fix invalid receipt email addresses before sending.")
            )
        }
        let addresses = BillingHubEmailRecipients.unique(
            BillingHubEmailRecipients.parse(recipientEmail)
        )
        guard !addresses.isEmpty else {
            return publishReceiptSendOutcome(.failed("Add a recipient before sending the receipt."))
        }
        guard let service = NSSharingService(named: .composeEmail) else {
            return publishReceiptSendOutcome(.failed("No email app is configured on this Mac."))
        }
        service.recipients = addresses
        service.subject = BillingHubReceiptEmailCopy.subject(
            invoiceNumber: invoice.invoiceNumber
        )

        let summary = InvoicePDFPresentation.receiptSummary(
            paidDate: invoice.paidDate,
            notes: invoice.notes
        )
        let message = BillingHubReceiptEmailCopy.message(
            invoiceNumber: invoice.invoiceNumber,
            paymentSummary: summary,
            includesPDF: includePDF
        )
        var items: [Any] = [message as NSString]
        var temporaryPDF: InvoiceTemporaryPDF?
        if includePDF {
            do {
                let presentation = receiptPresentation(for: invoice)
                let pdf = try await temporaryPDFDocument(invoiceID: id, presentation: presentation)
                temporaryPDF = pdf
                items.append(pdf.url as NSURL)
            } catch {
                return publishReceiptSendOutcome(
                    .failed("Receipt PDF could not be created. \(error.localizedDescription)")
                )
            }
        }

        let outcome = await performMailShare(service: service, items: items, temporaryPDF: temporaryPDF)
        switch outcome {
        case .completed:
            return publishReceiptSendOutcome(
                .sent(recipientCount: addresses.count, attachedPDF: includePDF)
            )
        case .cancelled:
            return publishReceiptSendOutcome(.cancelled)
        case .failed(let failureMessage):
            return publishReceiptSendOutcome(.failed(failureMessage))
        }
    }

    /// Compatibility wrapper for call sites that only need success/failure.
    @discardableResult
    public func sendReceipt(id: UUID, recipientEmail: String, includePDF: Bool) async -> Bool {
        if case .sent = await sendReceiptWithOutcome(
            id: id,
            recipientEmail: recipientEmail,
            includePDF: includePDF
        ) {
            return true
        }
        return false
    }

    func exportReceiptPDFWithOutcome(id: UUID) async -> BillingHubReceiptExportOutcome {
        guard let invoice = host.fetchInvoiceOnMainContext(by: id) else {
            return publishReceiptExportOutcome(.failed("Invoice could not be found."))
        }
        if let message = BillingHubReceiptReadiness.message(
            paidDate: invoice.paidDate,
            notes: invoice.notes,
            isPaymentReceived: invoice.effectiveStatus == .received
        ) {
            return publishReceiptExportOutcome(.failed(message))
        }

        let pdf: InvoiceTemporaryPDF
        do {
            let presentation = receiptPresentation(for: invoice)
            pdf = try await temporaryPDFDocument(invoiceID: id, presentation: presentation)
        } catch {
            return publishReceiptExportOutcome(
                .failed("Receipt PDF could not be created. \(error.localizedDescription)")
            )
        }

        defer { pdf.discard() }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = pdf.url.lastPathComponent
        guard savePanel.runModal() == .OK, let destination = savePanel.url else {
            return publishReceiptExportOutcome(.cancelled)
        }

        do {
            try InvoicePDFFileWriter.write(source: pdf.url, to: destination)
            return publishReceiptExportOutcome(.saved(destination))
        } catch {
            return publishReceiptExportOutcome(
                .failed("Receipt PDF could not be saved. \(error.localizedDescription)")
            )
        }
    }

    public func exportReceiptPDF(id: UUID) async -> URL? {
        if case .saved(let url) = await exportReceiptPDFWithOutcome(id: id) {
            return url
        }
        return nil
    }

    // MARK: - PDF resolution

    private func receiptPresentation(for invoice: Invoice) -> InvoicePDFPresentation {
        .receipt(
            paymentSummary: InvoicePDFPresentation.receiptSummary(
                paidDate: invoice.paidDate,
                notes: invoice.notes
            )
        )
    }

    /// Prefers the open editor session draft when that invoice is selected; otherwise store path.
    private func temporaryPDFDocument(
        invoiceID: UUID,
        presentation: InvoicePDFPresentation
    ) async throws -> InvoiceTemporaryPDF {
        if let session = host.invoiceEditorSession {
            return try await session.temporaryPDF(invoiceID: invoiceID, presentation: presentation)
        }
        return try await InvoiceEditorStore.temporaryPDF(
            invoiceID: invoiceID,
            in: modelContainer,
            presentation: presentation
        )
    }

    // MARK: - Mail hand-off

    /// Presents the Mail compose sheet and suspends until the share completes, is cancelled, or
    /// fails. The composer is retained on `self` for the duration so it survives panel dismissal.
    private func performMailShare(
        service: NSSharingService,
        items: [Any],
        temporaryPDF: InvoiceTemporaryPDF?
    ) async -> BillingHubMailOutcome {
        let session = BillingHubMailShareSession()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let composer = BillingHubMailComposer(service: service, temporaryPDF: temporaryPDF) { [weak self] outcome in
                    if let self, let composer = session.composer {
                        host.activeMailComposers.removeAll { $0 === composer }
                    }
                    continuation.resume(returning: outcome)
                }
                session.composer = composer
                host.activeMailComposers.append(composer)
                composer.perform(with: items)
            }
        } onCancel: {
            Task { @MainActor in session.cancel() }
        }
    }

    private func publishInvoiceSendOutcome(
        _ outcome: BillingHubInvoiceSendOutcome
    ) -> BillingHubInvoiceSendOutcome {
        host.bulkActionFeedback = outcome.feedback
        return outcome
    }

    private func publishReceiptSendOutcome(
        _ outcome: BillingHubReceiptSendOutcome
    ) -> BillingHubReceiptSendOutcome {
        host.bulkActionFeedback = outcome.feedback
        return outcome
    }

    private func publishReceiptExportOutcome(
        _ outcome: BillingHubReceiptExportOutcome
    ) -> BillingHubReceiptExportOutcome {
        host.bulkActionFeedback = outcome.feedback
        return outcome
    }

    private func readyToSendFailure(_ message: String) -> BillingHubInvoiceSendOutcome {
        .failed("\(message) Invoice remains Ready to Send.")
    }
}
