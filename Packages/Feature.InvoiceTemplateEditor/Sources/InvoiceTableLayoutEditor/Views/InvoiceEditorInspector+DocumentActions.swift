import Core
import Observation
import SwiftUI

extension InvoiceEditorInspector {
    var documentActionsSection: some View {
        Section {
            let stage = InvoiceEditorBillingStagePresentation.resolve(viewModel.status)
            LabeledContent("Billing stage") {
                Label(stage.title, systemImage: stage.systemImage)
                    .foregroundStyle(.secondary)
            }

            Text(stage.guidance)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LabeledContent("Changes") {
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
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

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
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(!viewModel.hasUnsavedChanges || viewModel.isBusy)
            .help(
                viewModel.hasUnsavedChanges
                    ? "Save invoice changes"
                    : "Invoice has no unsaved changes"
            )

            Button {
                Task { await viewModel.exportCurrentInvoicePDF() }
            } label: {
                Label("Export Invoice PDF", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(viewModel.isBusy || viewModel.hasRevisionConflict)
            .help(
                viewModel.hasRevisionConflict
                    ? "Resolve the invoice conflict before exporting"
                    : "Save valid edits, then export the invoice PDF"
            )

            HStack {
                Text("Export saves valid edits first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()

                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Duplicate Invoice", systemImage: "doc.on.doc") {
                        Task { await viewModel.duplicateSelectedInvoice() }
                    }
                    Button("Print", systemImage: "printer") {
                        Task { await viewModel.printCurrentInvoice() }
                    }
                    .disabled(viewModel.hasRevisionConflict)

                    Divider()

                    Button("Delete Invoice", systemImage: "trash", role: .destructive) {
                        toolbarState.showsDeleteConfirmation = true
                    }
                }
                .menuStyle(.borderlessButton)
                .disabled(viewModel.isBusy)
            }

            if let openTemplateEditor {
                Button {
                    openTemplateEditor()
                } label: {
                    if isPreparingWorkspaceHandoff {
                        Label {
                            Text("Opening Template Editor…")
                        } icon: {
                            ProgressView().controlSize(.small)
                        }
                    } else {
                        Label("Edit New-Invoice Template", systemImage: "paintbrush")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isBusy || isPreparingWorkspaceHandoff)
                .help("Open Template Editor. Changes apply to newly created invoices only.")
                .accessibilityHint("Opens Template Editor without changing this invoice")
            }
        } header: {
            Label("Invoice", systemImage: "doc.text")
        } footer: {
            Text("Edit document data here. Billing Hub controls approval, delivery, payment, and receipts.")
        }
    }
}
