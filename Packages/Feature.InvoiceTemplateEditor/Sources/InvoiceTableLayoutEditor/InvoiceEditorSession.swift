import Foundation
import SwiftData

public enum InvoiceEditorMutation: Equatable, Sendable {
    case inserted(UUID)
    case updated(UUID)
    case deleted(UUID)
}

/// Opaque ownership granted while Feature.Invoices commits deletion of currently open invoice.
public struct InvoiceEditorDeletionLease: Equatable, Sendable {
    let token: UUID
    let invoiceID: UUID
}

enum InvoiceEditorSessionDocumentError: LocalizedError, Equatable {
    case editorBusy
    case activeDraftCouldNotBeSaved
    case selectionChanged

    var errorDescription: String? {
        switch self {
        case .editorBusy:
            "Open invoice is busy. Wait for its current action to finish and try again."
        case .activeDraftCouldNotBeSaved:
            "Open invoice has unsaved errors. Fix them before creating its PDF."
        case .selectionChanged:
            "Open invoice changed while its PDF was being prepared. Try again."
        }
    }
}

/// Per-workspace editor lifetime. Feature.Invoices owns one session so an in-progress draft
/// survives temporary navigation to another application feature.
@MainActor
public final class InvoiceEditorSession {
    let viewModel: InvoiceEditorViewModel
    let numericInputDrafts = InvoiceNumericInputDraftStore()
    private let modelContainer: ModelContainer
    private var mutationHandler: ((InvoiceEditorMutation) -> Void)?

    /// Minimal draft state exposed to owning features for safe destructive workflows.
    /// Feature.Invoices must not reach into editor implementation details, but it does need
    /// to warn when deleting rows would also discard the currently open draft.
    public var selectedInvoiceID: UUID? { viewModel.selectedInvoiceID }
    public var hasUnsavedChanges: Bool { viewModel.hasUnsavedChanges }

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        viewModel = InvoiceEditorViewModel(
            actor: InvoiceModelActor(modelContainer: modelContainer)
        )
        viewModel.mutationHandler = { [weak self] mutation in
            self?.mutationHandler?(mutation)
        }
    }

    public func setMutationHandler(_ handler: @escaping (InvoiceEditorMutation) -> Void) {
        mutationHandler = handler
    }

    /// Waits for active editor work, then prevents new draft mutations while owning feature
    /// commits deletion. Nil means none of requested invoices is currently open.
    public func prepareForDeletingInvoices(
        _ invoiceIDs: Set<UUID>
    ) async -> InvoiceEditorDeletionLease? {
        await viewModel.prepareForOwningDeletion(invoiceIDs: invoiceIDs)
    }

    /// Closes leased draft after persistence commit succeeds, including already-removed rows.
    public func completeDeletingInvoices(
        _ lease: InvoiceEditorDeletionLease?,
        deletedInvoiceIDs: Set<UUID>
    ) {
        guard let lease else { return }
        viewModel.completeOwningDeletion(
            lease: lease,
            deletedInvoiceIDs: deletedInvoiceIDs
        )
    }

    /// Releases lifecycle ownership without changing draft after persistence rollback/failure.
    public func cancelDeletingInvoices(_ lease: InvoiceEditorDeletionLease?) {
        guard let lease else { return }
        viewModel.cancelOwningDeletion(lease: lease)
    }

    /// Saves active draft before owning Invoices feature creates another record.
    /// False keeps creation transactional when draft cannot be committed.
    public func prepareForInvoiceCreation() async -> Bool {
        await viewModel.prepareForFeatureOwnedInvoiceCreation()
    }

    /// Generates through active editor when requested invoice is open, so bulk workflows never
    /// export stale persisted data. Other invoices use isolated actor-backed document generation.
    public func temporaryPDF(invoiceID: UUID) async throws -> InvoiceTemporaryPDF {
        guard viewModel.selectedInvoiceID == invoiceID else {
            return try await InvoiceEditorStore.temporaryPDF(
                invoiceID: invoiceID,
                in: modelContainer
            )
        }

        guard !viewModel.isBusy else {
            throw InvoiceEditorSessionDocumentError.editorBusy
        }

        if viewModel.hasUnsavedChanges {
            await viewModel.saveCurrentInvoice(successMessage: "Invoice saved before creating PDF.")
            guard !viewModel.hasUnsavedChanges else {
                throw InvoiceEditorSessionDocumentError.activeDraftCouldNotBeSaved
            }
        }

        try Task.checkCancellation()
        guard viewModel.selectedInvoiceID == invoiceID else {
            throw InvoiceEditorSessionDocumentError.selectionChanged
        }
        await Task.yield()
        try Task.checkCancellation()
        return try InvoicePDFRenderer.temporaryPDF(viewModel: viewModel)
    }
}
