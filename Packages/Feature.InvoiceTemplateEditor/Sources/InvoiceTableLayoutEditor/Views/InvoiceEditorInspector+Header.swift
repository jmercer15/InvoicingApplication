import SwiftUI

extension InvoiceEditorInspector {
    // MARK: - Header (document banner)

    var headerSection: some View {
        InvoiceEditorSection(title: "Details", systemImage: "doc.text") {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: InspectorLayout.fieldSpacing) {
                    titleField
                    invoiceNumberField
                    issueDateField
                    dueDateField
                }

                VStack(spacing: InspectorLayout.compactFieldSpacing) {
                    HStack(alignment: .top, spacing: InspectorLayout.fieldSpacing) {
                        titleField
                        invoiceNumberField
                    }
                    HStack(alignment: .top, spacing: InspectorLayout.fieldSpacing) {
                        issueDateField
                        dueDateField
                    }
                }
            }
        }
        .id(InvoiceInspectorSection.header)
    }

    private var titleField: some View {
        InvoiceEditorIconField(systemImage: "textformat", help: "Invoice title") {
            TextField("Invoice title", text: $viewModel.title)
                .focused($focusedTarget, equals: .header)
                .accessibilityLabel("Invoice title")
        }
    }

    private var invoiceNumberField: some View {
        InvoiceEditorIconField(systemImage: "number", help: "Invoice number") {
            TextField("Invoice Number", text: $viewModel.invoiceNumber)
                .focused($focusedTarget, equals: .invoiceNumber)
                .accessibilityLabel("Invoice number")
        }
    }

    private var issueDateField: some View {
        InvoiceEditorIconField(systemImage: "calendar", help: "Issue date") {
            DatePicker(
                "Issued",
                selection: Binding(
                    get: { viewModel.issueDate },
                    set: { viewModel.updateIssueDate($0) }
                ),
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .focused($focusedTarget, equals: .issueDate)
            .accessibilityLabel("Issue Date")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dueDateField: some View {
        InvoiceEditorIconField(systemImage: "calendar.badge.clock", help: "Due date") {
            DatePicker(
                "Due",
                selection: Binding(
                    get: { viewModel.dueDate },
                    set: { viewModel.updateDueDate($0) }
                ),
                in: viewModel.issueDate...,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .focused($focusedTarget, equals: .dueDate)
            .accessibilityLabel("Due Date")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
