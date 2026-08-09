import SwiftUI
import SharedUI

enum InvoiceTemplatePersistenceIntent {
    case createInvoice
    case leaveWorkspace

    func permitsPersistence(hasInvalidInputs: Bool) -> Bool {
        switch self {
        case .createInvoice:
            return !hasInvalidInputs
        case .leaveWorkspace:
            // Invalid exact-value text remains in SceneStorage and has not mutated typed template
            // state. Persist other valid edits so one unfinished field cannot discard them.
            return true
        }
    }
}

/// Mode boundary for invoice and template workflows. Invoice list ownership stays in Feature.Invoices.
struct InvoiceRootView: View {
    @State private var viewModel: InvoiceEditorViewModel
    @State private var editorToolbarState: InvoiceEditorToolbarState
    @State private var commandActions = InvoiceEditorCommandActions()
    @State private var templateSaveState = InvoiceTemplateSaveState.saved
    @State private var templateSaveTracker = InvoiceTemplateSaveTracker()
    @State private var invalidTemplateInputIDs = Set<String>()
    @State private var failedOpeningInvoiceID: UUID?
    @State private var creationRequestState = InvoiceEditorCreationRequestState()
    @State private var isPreparingWorkspaceHandoff = false
    @SceneStorage private var editorInspectorPresented: Bool
    @State private var hasPreparedWorkspace = false
    @SceneStorage("InvoiceEditor.SelectedInvoiceID") private var restoredSelectedInvoiceID = ""
    @SceneStorage("InvoiceTemplateEditor.NumericInputDrafts")
    private var restoredTemplateNumericInputDrafts = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let externalSelection: Binding<UUID?>?
    private let externalDocumentRefreshRevision: Int
    private let onCreateInvoice: (@MainActor () async throws -> Void)?
    private let onOpenInvoices: (@MainActor () -> Void)?
    private let onOpenTemplateEditor: (@MainActor () -> Void)?
    private let onBackToBillingHub: (@MainActor () -> Void)?
    private let mode: InvoiceEditorWorkspaceMode
    private let featureInvoiceCreationIsActive: Bool

    /// Persistence-free template workspace. Preview content and formatting defaults are local.
    init(
        onCreateInvoice: (@MainActor () async throws -> Void)? = nil,
        onOpenInvoices: (@MainActor () -> Void)? = nil,
        featureInvoiceCreationIsActive: Bool = false
    ) {
        _viewModel = State(initialValue: InvoiceEditorViewModel())
        _editorToolbarState = State(initialValue: InvoiceEditorToolbarState())
        _editorInspectorPresented = SceneStorage(
            wrappedValue: true,
            InvoiceEditorWorkspaceMode.template.inspectorSceneStorageKey
        )
        externalSelection = nil
        externalDocumentRefreshRevision = 0
        self.onCreateInvoice = onCreateInvoice
        self.onOpenInvoices = onOpenInvoices
        onOpenTemplateEditor = nil
        onBackToBillingHub = nil
        mode = .template
        self.featureInvoiceCreationIsActive = featureInvoiceCreationIsActive
    }

    init(
        viewModel: InvoiceEditorViewModel,
        externalSelection: Binding<UUID?>,
        externalDocumentRefreshRevision: Int = 0,
        numericInputDrafts: InvoiceNumericInputDraftStore,
        onCreateInvoice: (@MainActor () async throws -> Void)? = nil,
        onOpenTemplateEditor: (@MainActor () -> Void)? = nil,
        onBackToBillingHub: (@MainActor () -> Void)? = nil,
        featureInvoiceCreationIsActive: Bool = false
    ) {
        _viewModel = State(initialValue: viewModel)
        _editorToolbarState = State(
            initialValue: InvoiceEditorToolbarState(numericInputDrafts: numericInputDrafts)
        )
        _editorInspectorPresented = SceneStorage(
            wrappedValue: true,
            InvoiceEditorWorkspaceMode.invoice.inspectorSceneStorageKey
        )
        self.externalSelection = externalSelection
        self.externalDocumentRefreshRevision = externalDocumentRefreshRevision
        self.onCreateInvoice = onCreateInvoice
        onOpenInvoices = nil
        self.onOpenTemplateEditor = onOpenTemplateEditor
        self.onBackToBillingHub = onBackToBillingHub
        mode = .invoice
        self.featureInvoiceCreationIsActive = featureInvoiceCreationIsActive
    }

    var body: some View {
        Group {
            if viewModel.currentInvoice != nil {
                InvoiceEditorView(
                    viewModel: viewModel,
                    toolbarState: editorToolbarState,
                    mode: mode,
                    inspectorPresented: editorInspectorPresentation,
                    templateSaveState: displayedTemplateSaveState,
                    retryTemplateSave: { _ = persistTemplateImmediately() },
                    isCreatingInvoiceFromTemplate: invoiceCreationIsActive,
                    createInvoiceFromTemplate: templateInvoiceCreationAction,
                    openInvoices: openInvoicesAction,
                    openTemplateEditor: openTemplateEditorAction,
                    isPreparingWorkspaceHandoff: isPreparingWorkspaceHandoff,
                    templateInputValidityChange: updateTemplateInputValidity
                )
                .safeAreaInset(edge: .top, spacing: 0) {
                    if onBackToBillingHub != nil {
                        BillingPipelineProgressView(currentStage: pipelineStage)
                            .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                            .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
                            .background(.bar)
                            .overlay(alignment: .bottom) {
                                Divider()
                            }
                    }
                }
            } else if !hasPreparedWorkspace || viewModel.isLoading {
                ProgressView(mode == .template ? "Preparing mock invoice…" : "Opening invoice…")
            } else if mode == .invoice, let openingErrorMessage {
                ContentUnavailableView {
                    Label("Invoice Couldn't Be Opened", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(openingErrorMessage)
                } actions: {
                    Button("Try Again", systemImage: "arrow.clockwise") {
                        Task { await retryOpeningInvoice() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(failedOpeningInvoiceID == nil || viewModel.isLoading)

                    if onBackToBillingHub != nil {
                        Button("Back to Billing Hub", systemImage: "chevron.left") {
                            requestBackToBillingHub()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isPreparingWorkspaceHandoff)
                    }
                }
            } else if mode == .invoice {
                ContentUnavailableView {
                    Label("No Invoice Selected", systemImage: "doc.text")
                } description: {
                    Text("Select an invoice from the list, or create a new one.")
                } actions: {
                    if onCreateInvoice != nil {
                        Button(action: requestInvoiceCreation) {
                            if invoiceCreationIsActive {
                                Label {
                                    Text("Creating Invoice…")
                                } icon: {
                                    ProgressView().controlSize(.small)
                                }
                            } else {
                                Label("New Invoice", systemImage: "plus")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(invoiceCreationIsActive)
                    }
                    if let onOpenTemplateEditor {
                        Button("Edit New-Invoice Template", systemImage: "paintbrush") {
                            onOpenTemplateEditor()
                        }
                        .buttonStyle(.bordered)
                        .help("Open Template Editor without creating or changing an invoice")
                    }
                    if onBackToBillingHub != nil {
                        Button("Back to Billing Hub", systemImage: "chevron.left") {
                            requestBackToBillingHub()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isPreparingWorkspaceHandoff)
                    }
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .toolbar {
            if onBackToBillingHub != nil {
                ToolbarItem(placement: .navigation) {
                    Button {
                        requestBackToBillingHub()
                    } label: {
                        if isPreparingWorkspaceHandoff {
                            Label {
                                Text("Saving Before Returning…")
                            } icon: {
                                ProgressView().controlSize(.small)
                            }
                        } else {
                            Label("Back to Billing Hub", systemImage: "chevron.left")
                        }
                    }
                    .disabled(isPreparingWorkspaceHandoff || viewModel.isBusy)
                    .help("Return to Billing Hub and restore this invoice card")
                    .accessibilityHint(
                        "Saves valid edits, then switches to Billing Hub and focuses this invoice."
                    )
                }
            }
        }
        .task {
            configureCommandActions()
            switch mode {
            case .invoice:
                await prepareInvoiceWorkspace(
                    requestedID: externalSelection?.wrappedValue
                        ?? UUID(uuidString: restoredSelectedInvoiceID)
                )
                // Snapshot acceptance resets per-document validation. Restore surviving session
                // drafts afterward so hidden inspector fields still block destructive transitions.
                restoreInvoiceNumericInputValidity()
            case .template:
                restoreTemplateNumericInputDrafts()
                let defaults = InvoiceTemplatePreferenceStore.loadDefaults()
                templateSaveTracker.markSaved(defaults)
                viewModel.bootstrapMock(defaults: defaults)
            }
            hasPreparedWorkspace = true
            refreshCommandCapabilities()
        }
        .onChange(of: viewModel.selectedInvoiceID) { _, selectedID in
            guard mode == .invoice else { return }
            clearNumericInputDrafts()
            restoredSelectedInvoiceID = selectedID?.uuidString ?? ""
            publishSelection(selectedID)
            refreshCommandCapabilities()
        }
        .onChange(of: commandCapabilities) { _, capabilities in
            applyCommandCapabilities(capabilities)
        }
        .onChange(of: externalSelection?.wrappedValue) { _, requestedID in
            guard mode == .invoice, requestedID != viewModel.selectedInvoiceID else { return }
            Task {
                await viewModel.selectInvoice(id: requestedID)
                guard InvoiceExternalSelectionPublicationPolicy.requestIsCurrent(
                    requestedID: requestedID,
                    externalID: externalSelection?.wrappedValue
                ) else { return }
                if viewModel.currentInvoice != nil {
                    await viewModel.loadClientOptionsIfNeeded()
                    guard InvoiceExternalSelectionPublicationPolicy.requestIsCurrent(
                        requestedID: requestedID,
                        externalID: externalSelection?.wrappedValue
                    ) else { return }
                }
                reconcileInvoiceOpenRequest(requestedID: requestedID)
            }
        }
        .task(id: externalDocumentRefreshTaskID) {
            await reloadOpenInvoiceAfterExternalRefresh()
        }
        .task(id: templatePersistenceDefaults) {
            guard let defaults = templatePersistenceDefaults else { return }
            let requiresSave = templateSaveTracker.requiresSave(defaults)
            guard requiresSave else {
                templateSaveState = InvoiceTemplateSaveRecoveryPolicy.reconciledState(
                    templateSaveState,
                    requiresSave: requiresSave
                )
                return
            }
            templateSaveState = .saving
            do {
                try await Task.sleep(for: .milliseconds(250))
                try Task.checkCancellation()
                if InvoiceTemplatePreferenceStore.save(defaults) {
                    templateSaveTracker.markSaved(defaults)
                    templateSaveState = .saved
                } else {
                    templateSaveState = .failed
                }
            } catch is CancellationError {
                return
            } catch {
                templateSaveState = .failed
            }
        }
        .onDisappear {
            creationRequestState.invalidatePresentation()
            switch mode {
            case .template:
                persistTemplateImmediately(intent: .leaveWorkspace)
            case .invoice:
                viewModel.cancelActiveDocumentAction()
                Task { await viewModel.saveBeforeLeavingWorkspace() }
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                switch templateRecoveryIssue {
                case .invalidInputs:
                    InvoiceTemplateInvalidValuesBanner(
                        reviewFormat: reviewInvalidTemplateInputs
                    )
                case .saveFailure:
                    InvoiceTemplateSaveFailureBanner(
                        retry: { _ = persistTemplateImmediately() },
                        openFormat: revealEditorInspector
                    )
                case nil:
                    EmptyView()
                }
                if let message = rootStatusMessage {
                    let messageID = viewModel.statusMessageID
                    InvoiceEditorStatusBanner(message: message) {
                        viewModel.dismissStatusMessage(id: messageID)
                    }
                }
            }
            .padding()
            .transition(
                reduceMotion
                    ? .opacity
                    : .move(edge: .bottom).combined(with: .opacity)
            )
        }
        .animation(reduceMotion ? nil : .snappy, value: viewModel.statusMessageID)
        .animation(reduceMotion ? nil : .snappy, value: templateRecoveryIssue)
        .onChange(of: templateSaveState) { _, saveState in
            let messageID = viewModel.statusMessageID
            guard InvoiceEditorStatusBanner.shouldDiscardSuppressedMessage(
                viewModel.statusMessage,
                whenTemplateSaveFailed: saveState == .failed
            ) else { return }
            viewModel.dismissStatusMessage(id: messageID)
        }
        .task(id: viewModel.statusMessageID) {
            let messageID = viewModel.statusMessageID
            guard let message = viewModel.statusMessage,
                  InvoiceEditorStatusBanner.shouldAutoDismiss(message)
            else { return }
            do {
                try await Task.sleep(for: .seconds(4))
                try Task.checkCancellation()
            } catch {
                return
            }
            viewModel.dismissStatusMessage(id: messageID)
        }
        .focusedSceneValue(\.invoiceEditorCommandActions, commandActions)
    }

    private var pipelineStage: BillingPipelineStage {
        switch viewModel.status {
        case .draft:
            return .review
        case .readyToSend:
            return .send
        case .sent, .overdue:
            return .payment
        case .paid:
            return .paid
        case .cancelled, .voided:
            return .review
        }
    }

    private func publishSelection(_ selectedID: UUID?) {
        guard mode == .invoice,
              let externalSelection,
              externalSelection.wrappedValue != selectedID
        else { return }
        externalSelection.wrappedValue = selectedID
    }

    private func prepareInvoiceWorkspace(requestedID: UUID?) async {
        failedOpeningInvoiceID = nil
        await viewModel.openForWorkspace(requestedInvoiceID: requestedID)

        if viewModel.currentInvoice != nil {
            await viewModel.loadClientOptions()
        }

        reconcileInvoiceOpenRequest(requestedID: requestedID)
    }

    private func reconcileInvoiceOpenRequest(requestedID: UUID?) {
        failedOpeningInvoiceID = InvoiceWorkspaceOpeningPolicy.failedRequestID(
            requestedID: requestedID,
            openedID: viewModel.selectedInvoiceID,
            hasOpenDocument: viewModel.currentInvoice != nil
        )

        // Re-entry can be blocked by an invalid draft or a failed destination fetch. An existing
        // document must then reclaim list selection; initial open failures keep requested retry ID.
        if InvoiceWorkspaceOpeningPolicy.shouldPublishSelection(
            requestedID: requestedID,
            openedID: viewModel.selectedInvoiceID,
            hasOpenDocument: viewModel.currentInvoice != nil
        ) {
            publishSelection(viewModel.selectedInvoiceID)
        }
    }

    private func retryOpeningInvoice() async {
        guard let failedOpeningInvoiceID else { return }
        await prepareInvoiceWorkspace(requestedID: failedOpeningInvoiceID)
        refreshCommandCapabilities()
    }

    private var externalDocumentRefreshTaskID: InvoiceExternalDocumentRefreshTaskID {
        InvoiceExternalDocumentRefreshTaskID(
            selectedID: externalSelection?.wrappedValue,
            revision: externalDocumentRefreshRevision
        )
    }

    private func reloadOpenInvoiceAfterExternalRefresh() async {
        guard mode == .invoice,
              hasPreparedWorkspace,
              let selectedID = externalSelection?.wrappedValue,
              viewModel.selectedInvoiceID == selectedID,
              viewModel.currentInvoice?.id == selectedID,
              !viewModel.hasUnsavedChanges,
              !viewModel.isBusy
        else { return }

        do {
            try await viewModel.loadInvoice(id: selectedID)
            await viewModel.loadClientOptionsIfNeeded()
        } catch {
            let detail = InvoiceOperationErrorPresentation.detail(
                for: error,
                fallback: "Invoice data could not be refreshed. Try again."
            )
            viewModel.statusMessage = "Failed to refresh invoice: \(detail)"
        }
        refreshCommandCapabilities()
    }

    private var commandCapabilities: InvoiceEditorCommandCapabilities {
        InvoiceEditorCommandCapabilities(
            mode: mode,
            hasInvoice: mode == .invoice && viewModel.selectedInvoiceID != nil,
            hasDocument: viewModel.currentInvoice != nil,
            hasUnsavedChanges: viewModel.hasUnsavedChanges,
            isBusy: viewModel.isBusy || isPreparingWorkspaceHandoff,
            hasRevisionConflict: viewModel.hasRevisionConflict,
            creationIsAvailable: creationIsAvailable,
            zoom: editorToolbarState.zoom,
            fitScale: editorToolbarState.viewport.fitScale
        )
    }

    private var creationIsAvailable: Bool {
        guard !invoiceCreationIsActive else { return false }
        switch mode {
        case .invoice:
            return true
        case .template:
            return hasPreparedWorkspace
                && viewModel.currentInvoice != nil
                && invalidTemplateInputIDs.isEmpty
                && templateSaveState != .saving
        }
    }

    private var openingErrorMessage: String? {
        guard let message = viewModel.statusMessage,
              message.hasPrefix("Failed to load invoice:")
        else { return nil }
        return message
    }

    private var rootStatusMessage: String? {
        guard openingErrorMessage == nil else { return nil }
        return InvoiceEditorStatusBanner.messageForPresentation(
            viewModel.statusMessage,
            whileTemplateSaveFailed: showsTemplateSaveRecovery
        )
    }

    private var templatePersistenceDefaults: InvoiceTemplateDefaults? {
        guard mode == .template, viewModel.currentInvoice != nil else { return nil }
        return InvoiceTemplateDefaults(
            paperSize: viewModel.paperSize,
            pageOrientation: viewModel.pageOrientation,
            configuration: viewModel.templateConfiguration
        )
    }

    private var displayedTemplateSaveState: InvoiceTemplateSaveState {
        invalidTemplateInputIDs.isEmpty ? templateSaveState : .invalid
    }

    private var showsTemplateSaveRecovery: Bool {
        templateRecoveryIssue == .saveFailure
    }

    private var templateRecoveryIssue: InvoiceTemplateSaveRecoveryPolicy.Issue? {
        guard mode == .template else { return nil }
        return InvoiceTemplateSaveRecoveryPolicy.issue(
            saveState: templateSaveState,
            hasInvalidInputs: !invalidTemplateInputIDs.isEmpty
        )
    }

    private func updateTemplateInputValidity(_ inputID: String, _ isInvalid: Bool) {
        if isInvalid {
            invalidTemplateInputIDs.insert(inputID)
        } else {
            invalidTemplateInputIDs.remove(inputID)
        }
    }

    private func clearNumericInputDrafts() {
        for inputID in editorToolbarState.resetNumericInputDrafts() {
            viewModel.updateNumericInputValidity(id: inputID, isInvalid: false)
            invalidTemplateInputIDs.remove(inputID)
        }
    }

    private func restoreInvoiceNumericInputValidity() {
        for inputID in editorToolbarState.numericInputDrafts.inputIDs {
            viewModel.updateNumericInputValidity(id: inputID, isInvalid: true)
        }
    }

    private func restoreTemplateNumericInputDrafts() {
        let store = editorToolbarState.numericInputDrafts
        store.restore(from: restoredTemplateNumericInputDrafts)
        invalidTemplateInputIDs.formUnion(store.inputIDs)
        store.onChange = { snapshot in
            restoredTemplateNumericInputDrafts = snapshot
        }
    }

    @discardableResult
    private func persistTemplateImmediately(
        intent: InvoiceTemplatePersistenceIntent = .createInvoice
    ) -> Bool {
        guard mode == .template else { return true }
        guard hasPreparedWorkspace, let defaults = templatePersistenceDefaults else {
            viewModel.statusMessage = "Template is still preparing. Try creating the invoice again."
            return false
        }
        guard intent.permitsPersistence(
            hasInvalidInputs: !invalidTemplateInputIDs.isEmpty
        ) else { return false }
        let requiresSave = templateSaveTracker.requiresSave(defaults)
        guard requiresSave else {
            templateSaveState = InvoiceTemplateSaveRecoveryPolicy.reconciledState(
                templateSaveState,
                requiresSave: requiresSave
            )
            return true
        }
        if InvoiceTemplatePreferenceStore.save(defaults) {
            templateSaveTracker.markSaved(defaults)
            templateSaveState = .saved
            return true
        } else {
            templateSaveState = .failed
            return false
        }
    }

    private func requestInvoiceCreation() {
        guard let onCreateInvoice,
              !invoiceCreationIsActive,
              mode != .template || persistTemplateImmediately(),
              let requestID = creationRequestState.begin()
        else { return }

        Task { @MainActor in
            defer { creationRequestState.finish(requestID) }
            do {
                try await onCreateInvoice()
            } catch {
                guard creationRequestState.owns(requestID) else { return }
                let detail = InvoiceOperationErrorPresentation.detail(
                    for: error,
                    fallback: "Invoice data could not be created. Try again."
                )
                viewModel.statusMessage = "Invoice couldn't be created. \(detail)"
            }
        }
    }

    private var templateInvoiceCreationAction: (() -> Void)? {
        guard onCreateInvoice != nil else { return nil }
        return { requestInvoiceCreation() }
    }

    private var openInvoicesAction: (@MainActor () -> Void)? {
        guard onOpenInvoices != nil else { return nil }
        return { requestOpenInvoices() }
    }

    private var openTemplateEditorAction: (@MainActor () -> Void)? {
        guard onOpenTemplateEditor != nil else { return nil }
        return { requestOpenTemplateEditor() }
    }

    private func requestOpenInvoices() {
        guard !invoiceCreationIsActive,
              persistTemplateImmediately(intent: .leaveWorkspace)
        else { return }
        onOpenInvoices?()
    }

    private func requestOpenTemplateEditor() {
        guard mode == .invoice,
              !isPreparingWorkspaceHandoff,
              let onOpenTemplateEditor
        else { return }

        isPreparingWorkspaceHandoff = true
        Task { @MainActor in
            defer { isPreparingWorkspaceHandoff = false }
            guard await viewModel.prepareForWorkspaceHandoff() else {
                revealEditorInspector()
                return
            }
            onOpenTemplateEditor()
        }
    }

    private func requestBackToBillingHub() {
        guard mode == .invoice,
              !isPreparingWorkspaceHandoff,
              let onBackToBillingHub
        else { return }

        isPreparingWorkspaceHandoff = true
        Task { @MainActor in
            defer { isPreparingWorkspaceHandoff = false }
            guard await viewModel.prepareForWorkspaceHandoff() else {
                revealEditorInspector()
                return
            }
            onBackToBillingHub()
        }
    }

    private var invoiceCreationIsActive: Bool {
        InvoiceEditorCreationActivityPolicy.isActive(
            localRequest: creationRequestState.isActive,
            featureRequest: featureInvoiceCreationIsActive
        )
    }

    private func configureCommandActions() {
        commandActions.prepareForInvoiceCreation = {
            switch mode {
            case .template:
                return persistTemplateImmediately()
            case .invoice:
                // Feature.Invoices prepares its active session at canonical creation boundary.
                return true
            }
        }
        commandActions.toggleInspector = {
            setEditorInspectorPresented(!editorInspectorPresented)
        }
        commandActions.zoomIn = {
            editorToolbarState.zoom.zoomIn(relativeTo: editorToolbarState.viewport.fitScale)
        }
        commandActions.zoomOut = {
            editorToolbarState.zoom.zoomOut(relativeTo: editorToolbarState.viewport.fitScale)
        }
        commandActions.setActualSize = {
            editorToolbarState.zoom.setActualSize()
        }
        commandActions.fitWidth = {
            editorToolbarState.zoom.setFitWidth()
        }
        guard mode == .invoice else { return }
        commandActions.save = { Task { await viewModel.saveCurrentInvoice() } }
        commandActions.duplicate = { Task { await viewModel.duplicateSelectedInvoice() } }
        commandActions.addLineItem = {
            revealEditorInspector()
            editorToolbarState.requestAddLineItem()
        }
        commandActions.requestDelete = { editorToolbarState.showsDeleteConfirmation = true }
        commandActions.print = { Task { await viewModel.printCurrentInvoice() } }
        commandActions.exportPDF = { Task { await viewModel.exportCurrentInvoicePDF() } }
    }

    private func refreshCommandCapabilities() {
        applyCommandCapabilities(commandCapabilities)
    }

    private func applyCommandCapabilities(_ capabilities: InvoiceEditorCommandCapabilities) {
        commandActions.updateCapabilities(
            canCreate: capabilities.canCreate,
            canSave: capabilities.canSave,
            canDuplicate: capabilities.canDuplicate,
            canDelete: capabilities.canDelete,
            canPrint: capabilities.canPrint,
            canExportPDF: capabilities.canExportPDF,
            canToggleInspector: capabilities.canToggleInspector,
            isInvoiceContext: capabilities.isInvoiceContext,
            canAddLineItem: capabilities.canAddLineItem,
            canZoomIn: capabilities.canZoomIn,
            canZoomOut: capabilities.canZoomOut,
            canSetActualSize: capabilities.canSetActualSize,
            canFitWidth: capabilities.canFitWidth
        )
    }

    /// SwiftUI's AppKit inspector bridge can write presentation state while resolving its own
    /// layout. Coalesce equivalent writes before they reach SceneStorage so preview focus,
    /// validation recovery, and toolbar commands cannot trigger another constraints pass.
    private var editorInspectorPresentation: Binding<Bool> {
        Binding(
            get: { editorInspectorPresented },
            set: setEditorInspectorPresented
        )
    }

    private func revealEditorInspector() {
        setEditorInspectorPresented(true)
    }

    private func reviewInvalidTemplateInputs() {
        editorToolbarState.requestInvalidTemplateInputRecovery()
        revealEditorInspector()
    }

    private func setEditorInspectorPresented(_ requestedValue: Bool) {
        guard let replacement = InvoiceEditorInspectorPresentationPolicy.replacement(
            current: editorInspectorPresented,
            requested: requestedValue
        ) else { return }
        editorInspectorPresented = replacement
    }
}

private struct InvoiceExternalDocumentRefreshTaskID: Equatable {
    let selectedID: UUID?
    let revision: Int
}

private struct InvoiceTemplateInvalidValuesBanner: View {
    let reviewFormat: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("Template has invalid Format values.")
                .font(.callout.weight(.medium))

            Button("Review Format", action: reviewFormat)
                .buttonStyle(.borderless)
                .help("Open Format inspector and review highlighted values")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(.orange.opacity(0.2))
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Template contains invalid Format values")
        .accessibilityHint("Open Format inspector to review highlighted values")
    }
}

private struct InvoiceTemplateSaveFailureBanner: View {
    let retry: () -> Void
    let openFormat: () -> Void
    @AccessibilityFocusState private var isRetryFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            Text("Template changes couldn’t be saved.")
                .font(.callout.weight(.medium))

            Button("Retry", action: retry)
                .buttonStyle(.borderless)
                .accessibilityFocused($isRetryFocused)

            Button("Open Format", action: openFormat)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(.red.opacity(0.16))
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Template save failed")
        .onAppear {
            isRetryFocused = true
            AccessibilityNotification.Announcement("Save failed. Template changes couldn't be saved.").post()
        }
    }
}
