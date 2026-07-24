enum InvoiceEditorActivityState: Equatable, Sendable {
    case opening
    case saving
    case preparingDocument
    case updating
    case conflict
    case unsaved
    case saved

    static func resolve(
        isLoading: Bool,
        isSaving: Bool,
        isGeneratingDocument: Bool,
        isPerformingLifecycleOperation: Bool,
        hasRevisionConflict: Bool,
        hasUnsavedChanges: Bool
    ) -> Self {
        if isLoading { return .opening }
        if isSaving { return .saving }
        if isGeneratingDocument { return .preparingDocument }
        if isPerformingLifecycleOperation { return .updating }
        if hasRevisionConflict { return .conflict }
        if hasUnsavedChanges { return .unsaved }
        return .saved
    }

    @MainActor
    static func resolve(_ viewModel: InvoiceEditorViewModel) -> Self {
        resolve(
            isLoading: viewModel.isLoading,
            isSaving: viewModel.isSaving,
            isGeneratingDocument: viewModel.isGeneratingDocument,
            isPerformingLifecycleOperation: viewModel.isPerformingLifecycleOperation,
            hasRevisionConflict: viewModel.hasRevisionConflict,
            hasUnsavedChanges: viewModel.hasUnsavedChanges
        )
    }

    var title: String {
        switch self {
        case .opening: "Opening…"
        case .saving: "Saving…"
        case .preparingDocument: "Preparing document…"
        case .updating: "Updating…"
        case .conflict: "Needs attention"
        case .unsaved: "Unsaved changes"
        case .saved: "Saved"
        }
    }

    var isActive: Bool {
        switch self {
        case .opening, .saving, .preparingDocument, .updating: true
        case .conflict, .unsaved, .saved: false
        }
    }
}

struct InvoiceEditorProgressPresentation: Equatable, Sendable {
    let title: String
    let allowsCancellation: Bool

    static func resolve(
        mode: InvoiceEditorWorkspaceMode,
        templateSaveState: InvoiceTemplateSaveState,
        isCreatingInvoiceFromTemplate: Bool,
        invoiceActivity: InvoiceEditorActivityState,
        canCancelDocumentAction: Bool
    ) -> Self? {
        switch mode {
        case .template:
            if isCreatingInvoiceFromTemplate {
                return Self(title: "Creating invoice…", allowsCancellation: false)
            }
            if templateSaveState == .saving {
                return Self(title: "Saving template…", allowsCancellation: false)
            }
            return nil

        case .invoice:
            guard invoiceActivity.isActive else { return nil }
            return Self(
                title: invoiceActivity.title,
                allowsCancellation:
                    invoiceActivity == .preparingDocument && canCancelDocumentAction
            )
        }
    }
}
