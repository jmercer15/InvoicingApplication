import SwiftUI
import SharedUI

struct ReadyToSendPanel: View {
    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    @State private var recipients: String = ""
    @State private var cc: String = ""
    @State private var subject: String = "Invoice"
    @State private var message: String = "Please find attached your invoice."
    @State private var attachPDF: Bool = true
    @State private var sendCopy: Bool = true
    @State private var scheduleSend: Bool = false
    @State private var scheduleDate: Date = Date().addingTimeInterval(3600)
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            Section {
                TextField(text: $recipients) { Text("To") }
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .help("Primary email recipient for the invoice")
                    .textFieldStyle(.roundedBorder)

                TextField(text: $cc) { Text("Cc") }
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .help("Additional email recipients to copy on the message")
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Recipients")
            }

            Section {
                TextField(text: $subject) { Text("Subject") }
                    .submitLabel(.next)
                    .help("The subject line of the email")
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                VStack(alignment: .leading) {
                    Text("Message").font(StyleGuide.Typography.itemSubtitle).foregroundStyle(BillingHubTheme.Palette.textSecondary)
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                        .help("Custom message to include in the email body")
                }
            } header: {
                Text("Message Content")
            }

            Section {
                Toggle("Attach PDF", isOn: $attachPDF)
                    .toggleStyle(.switch)
                    .help("Include the invoice as a PDF attachment")
                Toggle("Send copy to myself", isOn: $sendCopy)
                    .toggleStyle(.switch)
                    .help("Send a BCC of this message to your account email")
                Toggle("Schedule send", isOn: $scheduleSend)
                    .toggleStyle(.switch)
                    .help("Delay sending this message to a specific time")
                if scheduleSend {
                    DatePicker("Send Date", selection: $scheduleDate)
                        .datePickerStyle(.compact)
                        .help("Select the date and time to send this invoice")
                }
            }

            Button("Send") {
                Task {
                    await viewModel.sendInvoice(id: card.id, recipients: recipients, subject: subject, message: message)
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(recipients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send invoice to recipients")
            .accessibilityHint("Finalizes the invoice and sends it via email.")

            Button("Mark as Sent (Manual)") {
                Task {
                    await viewModel.updateInvoiceStatus(card.id, to: .pending)
                    dismiss()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help("Move invoice to Sent when delivery happens outside this app")
            .accessibilityLabel("Mark invoice as sent manually")

            Button("Send Test") {
                Task {
                    await viewModel.sendTestInvoice(id: card.id, recipients: recipients, subject: subject, message: message)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help("Send a copy to yourself to preview the layout")
            .accessibilityLabel("Send test email")
            .accessibilityHint("Sends a preview of the invoice to your own email address.")

            Button("Move Back to Draft Review") {
                Task {
                    await viewModel.moveInvoiceBackToDraftReview(id: card.id)
                    dismiss()
                }
            }
            .buttonStyle(.bordered)
            .tint(ColorSystem.Status.warning)
            .controlSize(.regular)
            .help("Return this invoice to Review Drafts for further edits")
            .accessibilityLabel("Move invoice back to draft review")
        }
        .task {
            guard let invoice = await viewModel.invoice(byId: card.id) else { return }
            if subject == "Invoice" {
                subject = "Invoice \(invoice.invoiceNumber)"
            }
        }
    }
}
