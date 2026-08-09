import PersistenceModels
import SwiftUI
import SharedUI

struct ReadyToSendPanel: View {
    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    let openInvoice: (UUID) -> Void
    @State private var recipients: String = ""
    @State private var cc: String = ""
    @State private var subject: String = "Invoice"
    @State private var message: String = "Please find attached your invoice."
    @State private var attachPDF: Bool = true
    @State private var sendCopy: Bool = true
    @State private var showsMessageOptions = false
    @State private var isSending = false
    @State private var isSendingTest = false
    @State private var isMarkingSent = false
    @State private var showsMarkSentConfirmation = false
    @State private var operationFeedback: String?
    @State private var needsManualSentRecovery = false
    @State private var selfCopyAddress: String?
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) var dismiss

    private enum Field: Hashable {
        case recipients
        case cc
        case subject
        case message
        case manualRecovery
    }

    private var isBusy: Bool { isSending || isSendingTest || isMarkingSent }
    private var recipientIssue: String? {
        BillingHubEmailRecipients.validationMessage(
            for: recipients,
            fieldName: "To",
            required: true
        )
    }
    private var ccIssue: String? {
        BillingHubEmailRecipients.validationMessage(
            for: cc,
            fieldName: "Additional recipients",
            required: false
        )
    }
    private var subjectIssue: String? {
        subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Enter an email subject."
            : nil
    }
    private var canSendEmail: Bool {
        recipientIssue == nil && ccIssue == nil && subjectIssue == nil
    }
    /// Mail has already reported success in this state. Starting another compose would risk a
    /// duplicate invoice email; the only safe next action is persisting the Sent status.
    private var canStartNewSend: Bool {
        canSendEmail && !needsManualSentRecovery
    }
    private var recipientCount: Int {
        var addresses = BillingHubEmailRecipients.parse(recipients)
            + BillingHubEmailRecipients.parse(cc)
        if sendCopy, let selfCopyAddress {
            addresses.append(selfCopyAddress)
        }
        return BillingHubEmailRecipients.unique(addresses).count
    }
    private var deliverySummary: String {
        let recipientLabel = recipientCount == 1 ? "recipient" : "recipients"
        let attachment = attachPDF ? "invoice PDF attached" : "no PDF attachment"
        return String(recipientCount) + " " + recipientLabel + " · " + attachment
    }
    private var recipientReadinessMessage: String {
        let recipientLabel = recipientCount == 1 ? "recipient" : "recipients"
        return "Ready to send to " + String(recipientCount) + " " + recipientLabel + "."
    }

    var body: some View {
        Group {
            Section {
                TextField(text: $recipients) { Text("To") }
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .help("Primary email recipient for the invoice")
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .recipients)
                    .onSubmit { focusedField = .cc }

                TextField(text: $cc) { Text("Additional recipients") }
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .help("Other recipients added to the Mail recipient list")
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .cc)
                    .onSubmit {
                        showsMessageOptions = true
                        focusedField = .subject
                    }

                if let recipientIssue {
                    validationLabel(recipientIssue)
                }
                if let ccIssue {
                    validationLabel(ccIssue)
                }
                if recipientIssue == nil, ccIssue == nil, recipientCount > 0 {
                    Label(
                        recipientReadinessMessage,
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(ColorSystem.Status.success)
                    .accessibilityLabel(recipientReadinessMessage)
                }
            } header: {
                Text("Recipients")
            } footer: {
                Text("Separate multiple addresses with commas, semicolons, or new lines.")
            }

            Section {
                DisclosureGroup(isExpanded: $showsMessageOptions) {
                    TextField(text: $subject) { Text("Subject") }
                        .submitLabel(.next)
                        .help("The subject line of the email")
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .subject)
                        .onSubmit { focusedField = .message }

                    VStack(alignment: .leading) {
                        Text("Message")
                            .font(StyleGuide.Typography.itemSubtitle)
                            .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                        TextEditor(text: $message)
                            .frame(minHeight: 96)
                            .help("Custom message to include in the email body")
                            .focused($focusedField, equals: .message)
                    }

                    Toggle("Attach PDF", isOn: $attachPDF)
                        .toggleStyle(.switch)
                        .help("Include the invoice as a PDF attachment")
                    Toggle(selfCopyLabel, isOn: $sendCopy)
                        .toggleStyle(.switch)
                        .help("Adds your business email as an additional recipient")
                        .disabled(selfCopyAddress == nil)
                } label: {
                    VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingTiny) {
                        Text("Message and Attachments")
                            .font(StyleGuide.Typography.bodyMedium)
                        Text(messageOptionsSummary)
                            .font(StyleGuide.Typography.itemSubtitle)
                            .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                            .lineLimit(2)
                    }
                }

                if let subjectIssue, !showsMessageOptions {
                    validationLabel(subjectIssue)
                }

                if !attachPDF {
                    Label("No invoice PDF will be attached.", systemImage: "paperclip.badge.ellipsis")
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(ColorSystem.Status.warning)
                }

                if selfCopyAddress == nil {
                    Text("Add a valid business email in Settings to send yourself a copy.")
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                }
            }

            Section {
                Label(
                    deliverySummary + ". Mail opens next; this invoice moves to Sent only after Mail confirms delivery.",
                    systemImage: "envelope.open"
                )
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if let operationFeedback {
                sendFeedback(message: operationFeedback)
            }

            Button {
                sendInvoice()
            } label: {
                if isSending {
                    Label {
                        Text("Waiting for Mail…")
                    } icon: {
                        ProgressView().controlSize(.small)
                    }
                } else {
                    Label("Send Invoice", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(!canStartNewSend || isBusy)
            .help(sendInvoiceHelp)
            .accessibilityLabel("Send invoice to recipients")
            .accessibilityHint(sendInvoiceAccessibilityHint)

            Button {
                openInvoice(card.id)
                dismiss()
            } label: {
                Label("Open Invoice", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isBusy)
            .help("Review the full invoice and PDF in the Invoices workspace before sending")
            .accessibilityLabel("Open invoice")
            .accessibilityHint("Opens this invoice in the Invoices workspace.")

            Button {
                showsMarkSentConfirmation = true
            } label: {
                if isMarkingSent {
                    ProgressView().controlSize(.small)
                } else {
                    Label(manualSentTitle, systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(isBusy)
            .tint(needsManualSentRecovery ? ColorSystem.Status.warning : nil)
            .focused($focusedField, equals: .manualRecovery)
            .help(needsManualSentRecovery
                ? "Email was sent but status needs updating. Mark this invoice Sent now."
                : "Change status to Sent without opening Mail or sending a PDF"
            )
            .accessibilityLabel(manualSentTitle)

            if needsManualSentRecovery {
                Label(
                    "Email sent, but status update needs your confirmation.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(ColorSystem.Status.warning)
                .accessibilityElement(children: .combine)
            }

            BillingHubPanelMoreOptionsMenu(isDisabled: isBusy) {
                Button {
                    sendTestInvoice()
                } label: {
                    Label("Send Test", systemImage: "paperplane.circle")
                }
                .disabled(!canStartNewSend)
                .help("Send this exact email without changing the invoice status")
                .accessibilityLabel("Send test email")
                .accessibilityHint("Opens Mail to send this email without marking the invoice as sent.")

                Button {
                    Task {
                        let shouldDismiss = await viewModel.moveInvoiceBackToDraftReview(id: card.id)
                        if shouldDismiss {
                            dismiss()
                        }
                    }
                } label: {
                    Label("Move Back to Draft Review", systemImage: "arrow.uturn.backward")
                }
                .help("Return this invoice to Review Drafts for further edits")
                .accessibilityLabel("Move invoice back to draft review")
            }
        }
        .defaultFocus($focusedField, .recipients)
        .confirmationDialog(
            manualSentConfirmationTitle,
            isPresented: $showsMarkSentConfirmation,
            titleVisibility: .visible
        ) {
            Button(manualSentConfirmationButtonTitle) {
                markSentManually()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(manualSentConfirmationMessage)
        }
        .task {
            guard let invoice = await viewModel.invoice(byId: card.id) else { return }
            if subject == "Invoice" {
                subject = "Invoice \(invoice.invoiceNumber)"
            }
            if recipients.isEmpty,
               let preferred = BillingHubInvoiceEmailPrefill.preferredRecipient(
                billToEmail: invoice.billToEmail,
                clientEmail: invoice.clientEmail
               ) {
                recipients = preferred
            }
            selfCopyAddress = BillingHubEmailRecipients.validSingleAddress(invoice.businessEmail)
            if selfCopyAddress == nil {
                sendCopy = false
            }
        }
    }

    private func validationLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(StyleGuide.Typography.itemSubtitle)
            .foregroundStyle(ColorSystem.Status.error)
            .accessibilityLabel("Email validation error: \(message)")
    }

    private var messageOptionsSummary: String {
        let subjectSummary = subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No subject"
            : subject
        let attachment = attachPDF ? "PDF attached" : "no PDF"
        let copy = sendCopy ? "copy to business email" : "no sender copy"
        return "\(subjectSummary) · \(attachment) · \(copy)"
    }

    private var selfCopyLabel: String {
        if let selfCopyAddress {
            return "Send copy to \(selfCopyAddress)"
        }
        return "Send copy to business email"
    }

    private var manualSentTitle: String {
        needsManualSentRecovery
            ? BillingHubWorkflowCopy.finishMarkingSent
            : BillingHubWorkflowCopy.markSentWithoutEmail
    }

    private var sendInvoiceHelp: String {
        needsManualSentRecovery
            ? "Finish marking this invoice Sent before starting another email"
            : "Open Mail and mark this invoice Sent only after Mail confirms delivery"
    }

    private var sendInvoiceAccessibilityHint: String {
        needsManualSentRecovery
            ? "Disabled because Mail already reported success. Finish marking the invoice Sent to avoid sending it twice."
            : "Opens Mail to send the invoice. The invoice is only marked Sent after the email is actually sent."
    }

    private var manualSentConfirmationTitle: String {
        needsManualSentRecovery
            ? BillingHubWorkflowCopy.finishMarkingSentConfirmationTitle
            : BillingHubWorkflowCopy.markSentConfirmationTitle
    }

    private var manualSentConfirmationButtonTitle: String {
        needsManualSentRecovery
            ? BillingHubWorkflowCopy.finishMarkingSentConfirmationButtonTitle
            : BillingHubWorkflowCopy.markSentConfirmationButtonTitle
    }

    private var manualSentConfirmationMessage: String {
        needsManualSentRecovery
            ? BillingHubWorkflowCopy.finishMarkingSentConfirmationMessage
            : BillingHubWorkflowCopy.markSentConfirmationMessage
    }

    private func sendFeedback(message: String) -> some View {
        let severity = BillingHubBulkFeedbackSeverity.classify(message)
        return Section {
            Label(message, systemImage: severity.symbolName)
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(severity.tint)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private func sendInvoice() {
        guard !isSending, !needsManualSentRecovery else { return }
        operationFeedback = nil
        needsManualSentRecovery = false
        isSending = true
        Task {
            let outcome = await viewModel.sendInvoiceWithOutcome(
                id: card.id,
                recipients: recipients,
                additionalRecipients: cc,
                subject: subject,
                message: message,
                attachPDF: attachPDF,
                sendCopyToSelf: sendCopy
            )
            isSending = false
            operationFeedback = outcome.feedback
            needsManualSentRecovery = outcome.needsManualStatusRecovery
            if outcome.shouldDismiss {
                dismiss()
            } else if outcome.needsManualStatusRecovery {
                focusedField = .manualRecovery
            }
        }
    }

    private func markSentManually() {
        guard !isMarkingSent else { return }
        operationFeedback = nil
        isMarkingSent = true
        Task {
            let shouldDismiss = await viewModel.markInvoiceSentManually(id: card.id)
            isMarkingSent = false
            if shouldDismiss {
                dismiss()
            } else {
                operationFeedback = viewModel.bulkActionFeedback
            }
        }
    }

    private func sendTestInvoice() {
        guard !isSendingTest, !needsManualSentRecovery else { return }
        operationFeedback = nil
        isSendingTest = true
        Task {
            await viewModel.sendTestInvoice(
                id: card.id,
                recipients: recipients,
                cc: cc,
                subject: subject,
                message: message,
                attachPDF: attachPDF
            )
            isSendingTest = false
            operationFeedback = viewModel.bulkActionFeedback
        }
    }
}
