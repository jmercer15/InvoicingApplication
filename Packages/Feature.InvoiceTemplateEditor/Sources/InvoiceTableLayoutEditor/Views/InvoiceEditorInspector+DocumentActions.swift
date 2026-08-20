import Core
import Observation
import SharedUI
import SwiftUI

extension InvoiceEditorInspector {
    @ToolbarContentBuilder
    var documentToolbar: some ToolbarContent {
        ToolbarItem(placement: .status) {
            let stage = InvoiceEditorBillingStagePresentation.resolve(viewModel.status)
            let activityState = InvoiceEditorActivityState.resolve(viewModel)
            if activityState.isActive {
                Label {
                    Text(activityState.title)
                } icon: {
                    ProgressView().controlSize(.small)
                }
                .foregroundStyle(.secondary)
            } else if activityState == .conflict {
                Label(activityState.title, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else if activityState == .unsaved {
                Label("Not saved", systemImage: "circle.fill")
                    .foregroundStyle(.orange)
            } else {
                Label(stage.title, systemImage: stage.systemImage)
                    .foregroundStyle(.secondary)
                    .help(stage.guidance)
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await viewModel.saveCurrentInvoice() }
            } label: {
                if viewModel.isSaving {
                    Label {
                        Text("Saving")
                    } icon: {
                        ProgressView().controlSize(.small)
                    }
                } else {
                    Label("Save Invoice", systemImage: "square.and.arrow.down")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasUnsavedChanges || viewModel.isBusy)
            .help(
                viewModel.hasUnsavedChanges
                    ? "Save invoice changes"
                    : "Invoice has no unsaved changes"
            )
        }

        AppToolbarUtilityGroup {
            Button {
                Task { await viewModel.exportCurrentInvoicePDF() }
            } label: {
                Label("Export PDF", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.isBusy || viewModel.hasRevisionConflict)
            .help(
                viewModel.hasRevisionConflict
                    ? "Resolve the invoice conflict before exporting"
                    : "Save valid edits, then export the invoice PDF"
            )

            Menu("More", systemImage: "ellipsis.circle") {
                Button("Duplicate Invoice", systemImage: "doc.on.doc") {
                    Task { await viewModel.duplicateSelectedInvoice() }
                }
                Button("Print", systemImage: "printer") {
                    Task { await viewModel.printCurrentInvoice() }
                }
                .disabled(viewModel.hasRevisionConflict)

                if let openTemplateEditor {
                    Divider()

                    Button("Edit New-Invoice Template", systemImage: "paintbrush") {
                        openTemplateEditor()
                    }
                    .disabled(viewModel.isBusy || isPreparingWorkspaceHandoff)
                }

                Divider()

                Button("Delete Invoice", systemImage: "trash", role: .destructive) {
                    toolbarState.showsDeleteConfirmation = true
                }
            }
            .menuStyle(.borderlessButton)
            .disabled(viewModel.isBusy)
        }
    }
}
