import SwiftUI
import SharedUI

struct PaymentReceivedPanel: View {
    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    @State private var receiptEmail: String = ""
    @State private var includePDF: Bool = true
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            Section {
                Text("Payment has been received. You can send a receipt or export documents.")
                    .font(StyleGuide.Typography.bodyMedium)
                    .foregroundStyle(BillingHubTheme.Palette.textSecondary)
            }

            Section {
                TextField(text: $receiptEmail) { Text("Send receipt to") }
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)

                Toggle("Attach PDF receipt", isOn: $includePDF)
                    .toggleStyle(.switch)
                    .help("Include a PDF version of the payment receipt")
            } header: {
                Text("Receipt")
            }

            Button("Send Receipt") {
                Task {
                    await viewModel.sendReceipt(id: card.id, recipientEmail: receiptEmail, includePDF: includePDF)
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(receiptEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("Send the payment receipt to the client")
            .accessibilityLabel("Send receipt")
            .accessibilityHint("Sends an email receipt with optional PDF attachment.")

            Button("Export PDF") {
                Task {
                    _ = await viewModel.exportReceiptPDF(id: card.id)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help("Download the receipt as a PDF file")
            .accessibilityLabel("Export receipt PDF")

            Button("Reopen as Sent") {
                Task {
                    await viewModel.reopenInvoiceAsPending(id: card.id)
                    dismiss()
                }
            }
            .buttonStyle(.bordered)
            .tint(ColorSystem.Status.warning)
            .controlSize(.regular)
            .help("Move this invoice back to Sent/Pending when payment needs re-confirmation")
            .accessibilityLabel("Reopen invoice as sent")
        }
        .task {
            if receiptEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                _ = await viewModel.invoice(byId: card.id)
            }
        }
    }
}
