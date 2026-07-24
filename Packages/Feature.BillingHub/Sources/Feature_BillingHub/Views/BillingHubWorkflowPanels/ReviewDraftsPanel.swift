import SwiftUI

struct ReviewDraftsPanel: View {
    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    @State private var dueDate: Date = Date().addingTimeInterval(7 * 24 * 3600)
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            Section {
                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .help("Expected date the payment should be received")
            }

            Button("Approve Draft") {
                Task {
                    await viewModel.approveDraftInvoice(id: card.id, dueDate: dueDate)
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .help("Approve this draft and move it to Ready to Send")
            .accessibilityLabel("Approve draft invoice")
            .accessibilityHint("Changes the invoice status to ready to send.")

            Button("Request Changes") {
                Task {
                    await viewModel.requestChanges(for: card.id)
                    dismiss()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help("Flag this draft for changes before approval")
            .accessibilityLabel("Request changes")
            .accessibilityHint("Flags the draft as needing revisions.")
        }
        .task {
            if let invoice = await viewModel.invoice(byId: card.id), let existingDueDate = invoice.dueDate {
                dueDate = existingDueDate
            }
        }
    }
}
