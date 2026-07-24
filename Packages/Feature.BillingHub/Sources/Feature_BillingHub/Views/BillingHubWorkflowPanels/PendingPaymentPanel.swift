import SwiftUI
import SharedUI

struct PendingPaymentPanel: View {
    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var method: String = "Bank Transfer"
    @State private var reference: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            Section {
                TextField(text: $amount) { Text("Amount") }
                    .monospacedDigit()
                    .submitLabel(.next)
                    .help("Total amount received")
                    .textFieldStyle(.roundedBorder)

                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .help("The date the payment was received")
                Picker("Method", selection: $method) {
                    Text("Bank Transfer").tag("Bank Transfer")
                    Text("Card").tag("Card")
                    Text("Cash").tag("Cash")
                    Text("Cheque").tag("Cheque")
                }
                .pickerStyle(.menu)
                .help("The payment method used by the client")
                TextField(text: $reference) { Text("Reference") }
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .help("Transaction reference number or notes")
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Payment Details")
            }

            Button("Mark as Completed") {
                Task {
                    await viewModel.finalizePayment(
                        id: card.id,
                        amount: amount,
                        date: date,
                        method: method,
                        reference: reference
                    )
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .help("Record that payment has been received")
            .accessibilityLabel("Mark invoice as completed")
            .accessibilityHint("Updates the invoice status to completed and clears pending flags.")

            Button("Save Draft") {
                Task {
                    await viewModel.savePaymentDraft(
                        id: card.id,
                        amount: amount,
                        date: date,
                        method: method,
                        reference: reference
                    )
                    dismiss()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help("Save payment details as a draft without finalizing")
            .accessibilityLabel("Save payment draft")

            Button("Mark as Overdue") {
                Task {
                    await viewModel.markInvoiceOverdue(id: card.id)
                    dismiss()
                }
            }
            .buttonStyle(.bordered)
            .tint(ColorSystem.Status.warning)
            .help("Flag this invoice as overdue while keeping it in Payment")
            .accessibilityLabel("Mark invoice as overdue")

            Button("Move Back to Ready to Send") {
                Task {
                    await viewModel.moveInvoiceBackToReadyToSend(id: card.id)
                    dismiss()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help("Return invoice to Ready to Send for delivery corrections")
            .accessibilityLabel("Move invoice back to ready to send")
        }
        .task {
            guard let invoice = await viewModel.invoice(byId: card.id) else { return }
            if amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                amount = String(format: "%.2f", invoice.totalAmount)
            }
            if invoice.paidDate != nil {
                date = invoice.paidDate ?? date
            }
        }
    }
}
