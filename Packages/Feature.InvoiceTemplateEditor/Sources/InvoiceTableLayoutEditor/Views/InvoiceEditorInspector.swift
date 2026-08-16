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
                .accessibilityLabel("Invoice editing controls")
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
            ScrollView {
                LazyVStack(alignment: .center, spacing: 0) {
                    InvoiceEditorDocumentPage {
                        headerSection

                        ViewThatFits(in: .horizontal) {
                            IntrinsicPartyRowLayout(spacing: 0, expandsToFillWidth: true) {
                                fromSection.frame(minWidth: 210)
                                billedToSection.frame(minWidth: 210)
                                forSection.frame(minWidth: 210)
                            }

                            VStack(spacing: 0) {
                                fromSection
                                billedToSection
                                forSection
                            }
                        }

                        lineItemsSection

                        ViewThatFits(in: .horizontal) {
                            IntrinsicPartyRowLayout(spacing: 0, expandsToFillWidth: true) {
                                paymentDetailsSection.frame(minWidth: 360)
                                totalsSection.frame(minWidth: 360)
                            }

                            VStack(spacing: 0) {
                                paymentDetailsSection
                                totalsSection
                            }
                        }

                        paymentTermsSection
                    }

                    validationSection(proxy)
                        .frame(maxWidth: .infinity)
                        .frame(maxWidth: InspectorLayout.documentMaxWidth)
                }
                .padding(.vertical, InspectorLayout.editorVerticalPadding)
                .frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .controlSize(.small)
            .textFieldStyle(.roundedBorder)
            .toggleStyle(.checkbox)
            .toolbar {
                documentToolbar
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

    var motionAnimation: Animation? {
        reduceMotion ? nil : .snappy
    }
}
