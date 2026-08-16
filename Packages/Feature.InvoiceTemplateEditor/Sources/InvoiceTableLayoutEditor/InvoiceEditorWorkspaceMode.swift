import Foundation

/// Defines one coherent editor responsibility. Modes never expose controls from the other workflow.
enum InvoiceEditorWorkspaceMode: Equatable, Sendable {
    case invoice
    case template

    var usesPersistedInvoiceData: Bool { self == .invoice }
    var inspectorMode: InvoiceEditorInspectorMode {
        switch self {
        case .invoice: .invoiceData
        case .template: .templateFormatting
        }
    }

    var inspectorSceneStorageKey: String {
        switch self {
        case .invoice: "InvoiceEditor.DataInspectorPresented"
        case .template: "InvoiceTemplateEditor.FormatInspectorPresented"
        }
    }
}

enum InvoiceWorkspaceOpeningPolicy {
    /// Keep list selection stable when opening a requested invoice fails. Publishing `nil`
    /// would discard retry identity and make a transient store error look like user deselection.
    static func shouldPublishSelection(
        requestedID: UUID?,
        openedID: UUID?,
        hasOpenDocument: Bool = false
    ) -> Bool {
        hasOpenDocument || requestedID == nil || openedID == requestedID
    }

    /// Retains retry identity only for a requested invoice that failed before any document
    /// opened. Existing drafts remain recoverable through normal selection reconciliation.
    static func failedRequestID(
        requestedID: UUID?,
        openedID: UUID?,
        hasOpenDocument: Bool
    ) -> UUID? {
        guard let requestedID,
              openedID != requestedID,
              !hasOpenDocument
        else { return nil }
        return requestedID
    }
}

enum InvoiceExternalSelectionPublicationPolicy {
    /// Completion may reconcile list selection only while it still represents
    /// newest request emitted by owning Invoices feature.
    static func requestIsCurrent(requestedID: UUID?, externalID: UUID?) -> Bool {
        requestedID == externalID
    }
}

enum InvoiceEditorCreationActivityPolicy {
    static func isActive(localRequest: Bool, featureRequest: Bool) -> Bool {
        localRequest || featureRequest
    }
}

struct InvoiceEditorCreationRequestState: Equatable {
    private(set) var requestID: UUID?

    var isActive: Bool { requestID != nil }

    mutating func begin() -> UUID? {
        guard requestID == nil else { return nil }
        let requestID = UUID()
        self.requestID = requestID
        return requestID
    }

    func owns(_ requestID: UUID) -> Bool {
        self.requestID == requestID
    }

    mutating func finish(_ requestID: UUID) {
        guard owns(requestID) else { return }
        self.requestID = nil
    }

    /// Stops presentation ownership without cancelling feature-owned persistence.
    /// A late completion must not publish into a later editor presentation.
    mutating func invalidatePresentation() {
        requestID = nil
    }
}

/// Resolved command availability for one editor render state.
///
/// Keeping this value typed and equatable lets `InvoiceRootView` observe one capability source
/// instead of publishing several command refreshes when document, activity, or viewport state
/// changes together.
struct InvoiceEditorCommandCapabilities: Equatable {
    let canCreate: Bool
    let canSave: Bool
    let canDuplicate: Bool
    let canDelete: Bool
    let canPrint: Bool
    let canExportPDF: Bool
    let canToggleInspector: Bool
    let isInvoiceContext: Bool
    let canAddLineItem: Bool
    let canZoomIn: Bool
    let canZoomOut: Bool
    let canSetActualSize: Bool
    let canFitWidth: Bool

    init(
        mode: InvoiceEditorWorkspaceMode,
        hasInvoice: Bool,
        hasDocument: Bool,
        hasUnsavedChanges: Bool,
        isBusy: Bool,
        hasRevisionConflict: Bool,
        creationIsAvailable: Bool = true,
        zoom: InvoiceDocumentPreviewZoom,
        fitScale: CGFloat
    ) {
        let isInvoiceContext = mode == .invoice
        self.canCreate = creationIsAvailable && !isBusy && !hasRevisionConflict
        self.canSave = hasInvoice && hasUnsavedChanges && !isBusy
        self.canDuplicate = hasInvoice && !isBusy
        self.canDelete = hasInvoice && !isBusy
        self.canPrint = hasInvoice && !isBusy && !hasRevisionConflict
        self.canExportPDF = hasInvoice && !isBusy && !hasRevisionConflict
        self.canToggleInspector = mode == .template && hasDocument
        self.isInvoiceContext = isInvoiceContext
        self.canAddLineItem = hasInvoice && !isBusy
        self.canZoomIn = hasDocument && zoom.canZoomIn(relativeTo: fitScale)
        self.canZoomOut = hasDocument && zoom.canZoomOut(relativeTo: fitScale)
        self.canSetActualSize = hasDocument && !zoom.isActualSize(fitScale: fitScale)
        self.canFitWidth = hasDocument && !zoom.isFitWidth
    }
}

enum InvoiceTemplateSaveState: Equatable, Sendable {
    case saved
    case saving
    case failed
    case invalid

    var title: String {
        switch self {
        case .saved: "Saved"
        case .saving: "Saving"
        case .failed: "Save failed"
        case .invalid: "Fix values"
        }
    }

    var systemImage: String {
        switch self {
        case .saved: "checkmark.circle.fill"
        case .saving: "arrow.triangle.2.circlepath"
        case .failed: "exclamationmark.triangle.fill"
        case .invalid: "exclamationmark.triangle.fill"
        }
    }

}

struct InvoiceTemplateSaveTracker: Equatable {
    private(set) var lastSavedDefaults: InvoiceTemplateDefaults?

    func requiresSave(_ defaults: InvoiceTemplateDefaults) -> Bool {
        defaults != lastSavedDefaults
    }

    mutating func markSaved(_ defaults: InvoiceTemplateDefaults) {
        lastSavedDefaults = defaults
    }
}

enum InvoiceTemplateSaveRecoveryPolicy {
    enum Issue: Equatable {
        case invalidInputs
        case saveFailure
    }

    static func issue(
        saveState: InvoiceTemplateSaveState,
        hasInvalidInputs: Bool
    ) -> Issue? {
        if hasInvalidInputs { return .invalidInputs }
        if saveState == .failed { return .saveFailure }
        return nil
    }

    static func showsFailureRecovery(
        saveState: InvoiceTemplateSaveState,
        hasInvalidInputs: Bool
    ) -> Bool {
        issue(
            saveState: saveState,
            hasInvalidInputs: hasInvalidInputs
        ) == .saveFailure
    }

    /// A failed write stops being actionable when current values once again equal the last
    /// persisted defaults. Keeping failure UI in that state offers a retry that has no work.
    static func reconciledState(
        _ state: InvoiceTemplateSaveState,
        requiresSave: Bool
    ) -> InvoiceTemplateSaveState {
        requiresSave ? state : .saved
    }
}
