import SwiftUI

enum InvoiceEditorDeleteCopy {
    static func message(invoiceNumber: String?, discardsUnsavedChanges: Bool) -> String {
        let subject = invoiceNumber.flatMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } ?? "the selected invoice"
        let draftWarning = discardsUnsavedChanges
            ? " Unsaved changes to this invoice will also be discarded."
            : ""
        return "This permanently deletes \(subject) and all of its line items.\(draftWarning)"
    }
}

enum InvoiceEditorInspectorPresentationPolicy {
    static func replacement(current: Bool, requested: Bool) -> Bool? {
        current == requested ? nil : requested
    }
}

struct InvoiceEditorView: View {
    @Bindable var viewModel: InvoiceEditorViewModel
    @Bindable var toolbarState: InvoiceEditorToolbarState
    let mode: InvoiceEditorWorkspaceMode
    @Binding var inspectorPresented: Bool
    let templateSaveState: InvoiceTemplateSaveState
    let retryTemplateSave: () -> Void
    let isCreatingInvoiceFromTemplate: Bool
    let createInvoiceFromTemplate: (() -> Void)?
    let openInvoices: (@MainActor () -> Void)?
    let openTemplateEditor: (@MainActor () -> Void)?
    let isPreparingWorkspaceHandoff: Bool
    let templateInputValidityChange: (String, Bool) -> Void
    @State private var previewInteraction: InvoicePreviewInspectorInteraction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        viewModel: InvoiceEditorViewModel,
        toolbarState: InvoiceEditorToolbarState,
        mode: InvoiceEditorWorkspaceMode,
        inspectorPresented: Binding<Bool>,
        templateSaveState: InvoiceTemplateSaveState,
        retryTemplateSave: @escaping () -> Void,
        isCreatingInvoiceFromTemplate: Bool,
        createInvoiceFromTemplate: (() -> Void)?,
        openInvoices: (@MainActor () -> Void)?,
        openTemplateEditor: (@MainActor () -> Void)?,
        isPreparingWorkspaceHandoff: Bool,
        templateInputValidityChange: @escaping (String, Bool) -> Void
    ) {
        self.viewModel = viewModel
        self.toolbarState = toolbarState
        self.mode = mode
        self._inspectorPresented = inspectorPresented
        self.templateSaveState = templateSaveState
        self.retryTemplateSave = retryTemplateSave
        self.isCreatingInvoiceFromTemplate = isCreatingInvoiceFromTemplate
        self.createInvoiceFromTemplate = createInvoiceFromTemplate
        self.openInvoices = openInvoices
        self.openTemplateEditor = openTemplateEditor
        self.isPreparingWorkspaceHandoff = isPreparingWorkspaceHandoff
        self.templateInputValidityChange = templateInputValidityChange
        _previewInteraction = State(
            initialValue: InvoicePreviewInspectorInteraction(
                mode: mode == .invoice ? .invoiceData : .templateFormatting
            )
        )
    }

    var body: some View {
        InvoiceDocumentPreview(
            viewModel: viewModel,
            zoom: $toolbarState.zoom,
            viewport: toolbarState.viewport,
            inspectorInteraction: previewInteraction
        )
        .inspector(isPresented: $inspectorPresented) {
            InvoiceEditorInspector(
                viewModel: viewModel,
                toolbarState: toolbarState,
                previewInteraction: previewInteraction,
                mode: mode.inspectorMode,
                templateSaveState: templateSaveState,
                retryTemplateSave: retryTemplateSave,
                isCreatingInvoiceFromTemplate: isCreatingInvoiceFromTemplate,
                createInvoiceFromTemplate: createInvoiceFromTemplate,
                openInvoices: openInvoices,
                openTemplateEditor: openTemplateEditor,
                isPreparingWorkspaceHandoff: isPreparingWorkspaceHandoff,
                templateInputValidityChange: templateInputValidityChange
            )
            .inspectorColumnWidth(
                min: 300,
                ideal: 360,
                max: 520
            )
            .disabled(viewModel.isBusy)
        }
        .navigationTitle(
            mode == .template
                ? "Invoice Template"
                : (viewModel.invoiceNumber.isEmpty ? "Invoice" : viewModel.invoiceNumber)
        )
        .navigationSubtitle(navigationSubtitle)
        .overlay(alignment: .topLeading) {
            if let progressPresentation {
                InvoiceEditorProgressOverlay(
                    presentation: progressPresentation,
                    cancel: viewModel.cancelActiveDocumentAction
                )
                .padding(12)
                .transition(.opacity)
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.16),
            value: progressPresentation
        )
        .onChange(of: previewInteraction.focusRequest) { _, request in
            if request != nil {
                revealInspector()
            }
        }
        .onChange(of: previewInteraction.formatInspectorRevealRevision) { _, _ in
            guard mode == .template else { return }
            revealInspector()
        }
        .onChange(of: viewModel.validationRecoveryRequestRevision) { _, _ in
            guard mode == .invoice else { return }
            revealInspector()
            if let target = viewModel.validationIssues.lazy.compactMap(\.target).first {
                previewInteraction.select(target)
            }
        }
        .alert("Delete this invoice?", isPresented: $toolbarState.showsDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteSelectedInvoice() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(InvoiceEditorDeleteCopy.message(
                invoiceNumber: viewModel.currentInvoice?.invoiceNumber,
                discardsUnsavedChanges: viewModel.hasUnsavedChanges
            ))
        }
        .confirmationDialog(
            viewModel.revisionConflictTitle,
            isPresented: Binding(
                get: { viewModel.hasRevisionConflict },
                set: { isPresented in
                    if !isPresented {
                        viewModel.keepEditingAfterRevisionConflict()
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if viewModel.hasUnsavedChanges {
                Button("Save Draft as New Invoice") {
                    resolveRevisionConflict(.saveDraftAsNew)
                }
            }
            if viewModel.revisionConflictCanReload {
                Button("Discard Draft and Reload Latest", role: .destructive) {
                    resolveRevisionConflict(.reloadLatest)
                }
            } else {
                Button("Discard Draft and Close Invoice", role: .destructive) {
                    resolveRevisionConflict(.closeDeleted)
                }
            }
            Button("Keep Editing", role: .cancel) {
                viewModel.keepEditingAfterRevisionConflict()
            }
        } message: {
            Text(viewModel.revisionConflictMessage)
        }
        .confirmationDialog(
            viewModel.pendingDiscardTransitionTitle,
            isPresented: Binding(
                get: { viewModel.hasPendingDiscardTransition },
                set: { isPresented in
                    if !isPresented {
                        viewModel.keepEditingAfterBlockedTransition()
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) {
                guard let transition =
                    viewModel.prepareToDiscardDraftAndContinueTransition()
                else { return }
                Task { await viewModel.continueDiscardedTransition(transition) }
            }
            Button("Keep Editing", role: .cancel) {
                viewModel.keepEditingAfterBlockedTransition()
            }
        } message: {
            Text(viewModel.pendingDiscardTransitionMessage)
        }
    }

    private var navigationSubtitle: String {
        switch mode {
        case .template:
            let style = viewModel.matchingTemplatePreset?.displayName ?? "Custom"
            return "\(style) · Mock preview · \(templateSaveState.title)"
        case .invoice:
            return InvoiceEditorActivityState.resolve(viewModel).title
        }
    }

    private var progressPresentation: InvoiceEditorProgressPresentation? {
        InvoiceEditorProgressPresentation.resolve(
            mode: mode,
            templateSaveState: templateSaveState,
            isCreatingInvoiceFromTemplate: isCreatingInvoiceFromTemplate,
            invoiceActivity: InvoiceEditorActivityState.resolve(viewModel),
            canCancelDocumentAction: viewModel.documentActionCancellation.isInstalled
        )
    }

    private func resolveRevisionConflict(_ resolution: InvoiceRevisionConflictResolution) {
        guard let capturedResolution =
            viewModel.beginRevisionConflictResolution(resolution)
        else { return }
        Task {
            await viewModel.continueRevisionConflictResolution(capturedResolution)
        }
    }

    private func revealInspector() {
        guard InvoiceEditorInspectorPresentationPolicy.replacement(
            current: inspectorPresented,
            requested: true
        ) != nil else { return }
        inspectorPresented = true
    }
}

private struct InvoiceEditorProgressOverlay: View {
    let presentation: InvoiceEditorProgressPresentation
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .accessibilityHidden(true)

            Text(presentation.title)
                .font(.callout.weight(.medium))

            if presentation.allowsCancellation {
                Button("Cancel", action: cancel)
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.cancelAction)
                    .help("Cancel document export")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(.secondary.opacity(0.2))
        }
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            presentation.allowsCancellation
                ? "\(presentation.title), cancellation available"
                : presentation.title
        )
    }
}

struct InvoiceEditorStatusBanner: View {
    let message: String
    let dismiss: () -> Void

    enum Tone: Equatable {
        case error
        case success
        case informational
    }

    static func tone(for message: String) -> Tone {
        if message.hasPrefix("Failed")
            || message.hasPrefix("Save failed")
            || message.hasPrefix("Fix")
            || message.hasPrefix("Review")
            || message.hasPrefix("Save or fix")
            || message.hasPrefix("Enter valid")
            || message.hasPrefix("Invoice couldn't")
            || message.hasPrefix("Invoice could not")
            || message.hasPrefix("Template couldn't")
            || message.hasPrefix("Template could not")
            || message.contains("couldn't be saved")
            || message.contains("could not be saved")
            || message.contains(" is required.")
            || message.contains(" cannot ")
            || message.contains(" could not ")
            || message.contains(" was deleted in another window")
            || message.hasPrefix("Duplicate ")
        {
            return .error
        }

        if message.hasPrefix("Invoice saved")
            || message.hasPrefix("Changes saved")
            || message.hasPrefix("Saved your draft")
            || message.hasPrefix("Created new invoice")
            || message.hasPrefix("Loaded ")
            || message.hasPrefix("Applied ")
            || message.hasPrefix("Template reset")
            || message.hasPrefix("Reloaded ")
            || message.hasPrefix("Invoice duplicated")
            || message.hasPrefix("Invoice deleted")
            || message.hasPrefix("Exported ")
            || message.hasPrefix("Invoice sent to printer")
        {
            return .success
        }

        return .informational
    }

    static func isError(_ message: String) -> Bool {
        tone(for: message) == .error
    }

    static func shouldAutoDismiss(_ message: String) -> Bool {
        tone(for: message) != .error
    }

    static func messageForPresentation(
        _ message: String?,
        whileTemplateSaveFailed: Bool
    ) -> String? {
        guard let message else { return nil }
        if whileTemplateSaveFailed, tone(for: message) != .error {
            return nil
        }
        return message
    }

    static func shouldDiscardSuppressedMessage(
        _ message: String?,
        whenTemplateSaveFailed: Bool
    ) -> Bool {
        guard whenTemplateSaveFailed, let message else { return false }
        return tone(for: message) != .error
    }

    private var tone: Tone {
        Self.tone(for: message)
    }

    private var systemImage: String {
        switch tone {
        case .error: "exclamationmark.triangle.fill"
        case .success: "checkmark.circle.fill"
        case .informational: "info.circle.fill"
        }
    }

    private var tint: Color {
        switch tone {
        case .error: .red
        case .success: .green
        case .informational: .blue
        }
    }

    private var accessibilityPrefix: String {
        switch tone {
        case .error: "Error"
        case .success: "Success"
        case .informational: "Status"
        }
    }

    @AccessibilityFocusState private var isBannerFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(message)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .accessibilityLabel("\(accessibilityPrefix): \(message)")

            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .frame(minWidth: 28, minHeight: 28)
            .accessibilityLabel("Dismiss status message")
            .help("Dismiss")
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(tint.opacity(0.16))
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .textSelection(.enabled)
        .accessibilityElement(children: .contain)
        .accessibilityFocused($isBannerFocused)
        .onAppear {
            if Self.isError(message) {
                isBannerFocused = true
                let announcement = message.hasPrefix("Save failed") || message.hasPrefix("Failed to save")
                    ? message
                    : "Save failed. \(message)"
                AccessibilityNotification.Announcement(announcement).post()
            }
        }
        .onChange(of: message) { _, newMessage in
            if Self.isError(newMessage) {
                isBannerFocused = true
                let announcement = newMessage.hasPrefix("Save failed") || newMessage.hasPrefix("Failed to save")
                    ? newMessage
                    : "Save failed. \(newMessage)"
                AccessibilityNotification.Announcement(announcement).post()
            }
        }
    }
}
