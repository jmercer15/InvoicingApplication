import SwiftUI

extension InvoiceEditorInspector {
    // MARK: - Header (document banner)

    var headerSection: some View {
        Section {
            DisclosureGroup(isExpanded: expansionBinding(for: .header)) {
                TextField("Invoice Number", text: $viewModel.invoiceNumber)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedTarget, equals: .invoiceNumber)
                    .accessibilityLabel("Invoice number")
                TextField("Title", text: $viewModel.title)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedTarget, equals: .header)
                    .accessibilityLabel("Invoice title")
                DatePicker(
                    "Issued",
                    selection: Binding(
                        get: { viewModel.issueDate },
                        set: { viewModel.updateIssueDate($0) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .focused($focusedTarget, equals: .issueDate)
                .accessibilityLabel("Issue Date")
                DatePicker(
                    "Due",
                    selection: Binding(
                        get: { viewModel.dueDate },
                        set: { viewModel.updateDueDate($0) }
                    ),
                    in: viewModel.issueDate...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .focused($focusedTarget, equals: .dueDate)
                .accessibilityLabel("Due Date")
            } label: {
                Label("Header", systemImage: "doc.text")
            }
        } footer: {
            if isExpanded(.header) {
                Text("Title and dates shown in the invoice banner.")
            }
        }
        .id(InvoiceInspectorSection.header)
    }

}
