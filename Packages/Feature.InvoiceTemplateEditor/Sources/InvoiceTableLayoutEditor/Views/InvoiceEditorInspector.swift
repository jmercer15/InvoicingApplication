import Observation
import SwiftUI

struct InvoiceEditorInspector: View {
    @Bindable var viewModel: InvoiceEditorViewModel
    @Bindable var toolbarState: InvoiceEditorToolbarState
    let previewInteraction: InvoicePreviewInspectorInteraction
    let mode: InvoiceEditorInspectorMode
    let templateSaveState: InvoiceTemplateSaveState
    let retryTemplateSave: () -> Void
    let isCreatingInvoiceFromTemplate: Bool
    let createInvoiceFromTemplate: (() -> Void)?
    let openInvoices: (@MainActor () -> Void)?
    let openTemplateEditor: (@MainActor () -> Void)?
    let isPreparingWorkspaceHandoff: Bool
    let templateInputValidityChange: (String, Bool) -> Void

    /// The inspector is an accordion: exactly one document path may be open.
    /// `nil` is used only by the explicit Collapse All command.
    /// Line Items opens first because review/edit handoffs are usually about billable content.
    @State var expandedSection: InvoiceInspectorSection? = .lineItems
    /// Nested accordion state for the Line Items path.
    @State var expandedLineItemID: UUID?
    @State var lineItemUndo = InvoiceLineItemUndoCoordinator()
    @State var handledAddLineItemRequestRevision = 0
    @State var activeDeferredFocusLeaseID: UUID?
    @FocusState var focusedTarget: InvoiceInspectorFocusTarget?
    @Environment(\.undoManager) var undoManager
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @ViewBuilder
    var body: some View {
        switch mode {
        case .invoiceData:
            invoiceForm
                .accessibilityLabel("Invoice data inspector")
        case .templateFormatting:
            InvoiceTemplateRibbon(
                viewModel: viewModel,
                toolbarState: toolbarState,
                previewInteraction: previewInteraction,
                saveState: templateSaveState,
                retrySave: retryTemplateSave,
                isCreatingInvoice: isCreatingInvoiceFromTemplate,
                createInvoice: createInvoiceFromTemplate,
                openInvoices: openInvoices,
                inputValidityChange: templateInputValidityChange
            )
            .accessibilityLabel("Invoice template format inspector")
        }
    }

    var invoiceForm: some View {
        ScrollViewReader { proxy in
            Form {
                documentActionsSection
                headerSection
                fromSection
                billedToSection
                forSection
                lineItemsSection
                totalsSection
                paymentDetailsSection
                paymentTermsSection
                validationSection(proxy)
                settingsSection
            }
            .formStyle(.grouped)
            .controlSize(.regular)
            .textFieldStyle(.roundedBorder)
            .toggleStyle(.checkbox)
            .disclosureGroupStyle(InspectorDisclosureGroupStyle())
            .safeAreaInset(edge: .top, spacing: 0) {
                sectionNavigator(proxy)
            }
            .onChange(of: previewInteraction.focusRequest) { _, request in
                guard let request else { return }
                focus(request, proxy: proxy)
            }
            .onChange(of: toolbarState.addLineItemRequestRevision) { _, _ in
                handleAddLineItemRequest()
            }
            .onChange(of: viewModel.selectedInvoiceID) { _, selectedInvoiceID in
                lineItemUndo.activateDocument(
                    id: selectedInvoiceID,
                    undoManager: undoManager
                )
                activeDeferredFocusLeaseID = nil
                expandedLineItemID = nil
                focusedTarget = nil
            }
            .onAppear {
                lineItemUndo.activateDocument(
                    id: viewModel.selectedInvoiceID,
                    undoManager: undoManager
                )
                if let request = previewInteraction.focusRequest {
                    focus(request, proxy: proxy)
                }
                handleAddLineItemRequest()
            }
            .onDisappear {
                activeDeferredFocusLeaseID = nil
                focusedTarget = nil
            }
        }
    }

    var visibleSections: [InvoiceInspectorSection] {
        InvoiceInspectorSection.allCases.filter { section in
            section != .validation || !viewModel.validationErrors.isEmpty
        }
    }

    var motionAnimation: Animation? {
        reduceMotion ? nil : .snappy
    }

    var subtleAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.15)
    }
}
