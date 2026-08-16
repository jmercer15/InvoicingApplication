import SwiftUI

struct InvoiceRootToolbarContent: ToolbarContent {
    let showsBackToBillingHub: Bool
    let isPreparingWorkspaceHandoff: Bool
    let isDocumentBusy: Bool
    let onBackToBillingHub: () -> Void

    var body: some ToolbarContent {
        if showsBackToBillingHub {
            ToolbarItem(placement: .navigation) {
                Button(action: onBackToBillingHub) {
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
                .disabled(isPreparingWorkspaceHandoff || isDocumentBusy)
                .help("Return to Billing Hub and restore this invoice card")
                .accessibilityHint(
                    "Saves valid edits, then switches to Billing Hub and focuses this invoice."
                )
            }
        }
    }
}

@MainActor
enum InvoiceRootCommandConfigurator {
    static func install(
        actions: InvoiceEditorCommandActions,
        mode: InvoiceEditorWorkspaceMode,
        viewModel: InvoiceEditorViewModel,
        toolbarState: InvoiceEditorToolbarState,
        prepareTemplateForCreation: @escaping () -> Bool,
        toggleInspector: @escaping () -> Void,
        revealInspector: @escaping () -> Void
    ) {
        actions.prepareForInvoiceCreation = {
            mode == .template ? prepareTemplateForCreation() : true
        }
        actions.toggleInspector = toggleInspector
        actions.zoomIn = {
            toolbarState.zoom.zoomIn(relativeTo: toolbarState.viewport.fitScale)
        }
        actions.zoomOut = {
            toolbarState.zoom.zoomOut(relativeTo: toolbarState.viewport.fitScale)
        }
        actions.setActualSize = {
            toolbarState.zoom.setActualSize()
        }
        actions.fitWidth = {
            toolbarState.zoom.setFitWidth()
        }

        guard mode == .invoice else { return }
        actions.save = { Task { await viewModel.saveCurrentInvoice() } }
        actions.duplicate = { Task { await viewModel.duplicateSelectedInvoice() } }
        actions.addLineItem = {
            revealInspector()
            toolbarState.requestAddLineItem()
        }
        actions.requestDelete = { toolbarState.showsDeleteConfirmation = true }
        actions.print = { Task { await viewModel.printCurrentInvoice() } }
        actions.exportPDF = { Task { await viewModel.exportCurrentInvoicePDF() } }
    }

    static func apply(
        _ capabilities: InvoiceEditorCommandCapabilities,
        to actions: InvoiceEditorCommandActions
    ) {
        actions.updateCapabilities(
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
}
