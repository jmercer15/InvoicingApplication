import PersistenceModels
import SwiftUI
import SharedUI

struct PaymentReceivedPanel: View {
    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    let openInvoice: (UUID) -> Void
    @State private var receiptEmail: String = ""
    @State private var includePDF: Bool = true
    @State private var isSendingReceipt = false
    @State private var isExporting = false
    @State private var isReopening = false
    @State private var showsReopenConfirmation = false
    @State private var showsReceiptResendConfirmation = false
    @State private var invoiceTotal: Double?
    @State private var paidDate: Date?
    @State private var paymentLine: String?
    @State private var isLoadingInvoice = true
    @State private var operationFeedback: String?
    @State private var receiptWasSent = false
    @FocusState private var receiptEmailFocused: Bool
    @Environment(\.dismiss) var dismiss

    private var isBusy: Bool { isSendingReceipt || isExporting || isReopening }
    private var recipientIssue: String? {
        guard !isLoadingInvoice else { return nil }
        return BillingHubEmailRecipients.validationMessage(
            for: receiptEmail,
            fieldName: "Receipt recipient",
            required: true
        )
    }
    private var receiptRecipientCount: Int {
        BillingHubEmailRecipients.unique(
            BillingHubEmailRecipients.parse(receiptEmail)
        ).count
    }
    private var receiptDeliverySummary: String {
        let recipientLabel = receiptRecipientCount == 1 ? "recipient" : "recipients"
        let attachment = includePDF ? "PDF receipt attached" : "no PDF attachment"
        return String(receiptRecipientCount) + " " + recipientLabel + " · " + attachment
    }
    private var paymentComparison: BillingHubPaymentAmount.Comparison? {
        guard let invoiceTotal,
              let recordedAmount = BillingHubPaymentNoteFormatter.recordedAmount(
                from: paymentLine
              )
        else { return nil }
        return BillingHubPaymentAmount.comparison(
            entered: String(recordedAmount),
            invoiceTotal: invoiceTotal
        )
    }
    /// A receipt must identify an actual payment, not merely an invoice that was moved to the
    /// paid lane without payment metadata.
    private var hasReceiptPaymentDetails: Bool {
        BillingHubReceiptReadiness.message(
            paidDate: paidDate,
            notes: paymentLine
        ) == nil
    }
    private var canDeliverReceipt: Bool {
        !isLoadingInvoice && invoiceTotal != nil && hasReceiptPaymentDetails
    }

    var body: some View {
        Group {
            Section {
                if isLoadingInvoice {
                    Label("Payment Received", systemImage: "checkmark.seal")
                        .font(StyleGuide.Typography.bodyMedium)
                        .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                } else if paymentComparison?.isMismatch == true {
                    Label(
                        "Payment Recorded · Balance to Review",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(StyleGuide.Typography.bodyMedium)
                    .foregroundStyle(ColorSystem.Status.warning)
                } else if paidDate != nil {
                    Label("Paid · Receipt Ready", systemImage: "checkmark.seal.fill")
                        .font(StyleGuide.Typography.bodyMedium)
                        .foregroundStyle(ColorSystem.Status.success)
                } else {
                    Label(
                        "Payment Received · Details Incomplete",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(StyleGuide.Typography.bodyMedium)
                    .foregroundStyle(ColorSystem.Status.warning)
                }

                if isReopening {
                    ProgressView("Reopening invoice as Sent…")
                        .controlSize(.small)
                        .accessibilityLabel("Reopening invoice as Sent")
                }
            }

            Section("Payment Summary") {
                if isLoadingInvoice {
                    ProgressView("Loading payment details…")
                        .controlSize(.small)
                } else if let invoiceTotal {
                    LabeledContent(
                        "Invoice total",
                        value: BillingHubPaymentAmount.currencyText(invoiceTotal)
                    )
                    if let paidDate {
                        LabeledContent(
                            "Paid on",
                            value: paidDate.formatted(.dateTime.day().month().year())
                        )
                    } else {
                        missingDetailLabel("Paid date is missing.")
                    }

                    if let paymentLine {
                        Text(paymentLine)
                            .font(StyleGuide.Typography.itemSubtitle)
                            .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    } else {
                        missingDetailLabel(
                            "Amount, method, and reference were not recorded. Reopen as Sent to record complete payment details before sending a receipt."
                        )
                    }

                    paymentComparisonLabel
                } else {
                    missingDetailLabel("Invoice payment details could not be loaded.")
                }
            }

            Section {
                TextField(text: $receiptEmail) { Text("Send receipt to") }
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .focused($receiptEmailFocused)
                    .disabled(isBusy)
                    .onChange(of: receiptEmail) { _, _ in
                        receiptWasSent = false
                    }

                if let recipientIssue {
                    Label(recipientIssue, systemImage: "exclamationmark.circle.fill")
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(ColorSystem.Status.error)
                        .accessibilityLabel("Email validation error: \(recipientIssue)")
                }

                if recipientIssue == nil, receiptRecipientCount > 0 {
                    Label(
                        "Receipt ready for " + String(receiptRecipientCount) + " "
                            + (receiptRecipientCount == 1 ? "recipient." : "recipients."),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(ColorSystem.Status.success)
                    .accessibilityLabel("Receipt recipient check passed. " + String(receiptRecipientCount) + " recipients.")
                }

                Toggle("Attach PDF receipt", isOn: $includePDF)
                    .toggleStyle(.switch)
                    .disabled(isBusy)
                    .help("Include a PDF version of the payment receipt")
                    .onChange(of: includePDF) { _, _ in
                        receiptWasSent = false
                    }

                Label(
                    receiptDeliverySummary + ". Mail includes the payment summary; this invoice stays in Payment Received.",
                    systemImage: "info.circle"
                )
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Receipt")
            }

            if let operationFeedback {
                receiptFeedback(operationFeedback)
            }

            if !isLoadingInvoice && !hasReceiptPaymentDetails {
                Button {
                    showsReopenConfirmation = true
                } label: {
                    Label("Reopen as Sent to Add Payment Details", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isBusy)
                .help("Return this invoice to Sent and clear incomplete payment metadata before recording it again")
                .accessibilityHint("Moves the invoice back to Sent so you can record amount, date, method, and reference before creating a receipt.")
            }

            Button {
                requestSendReceipt()
            } label: {
                if isSendingReceipt {
                    Label {
                        Text("Opening Mail…")
                    } icon: {
                        ProgressView().controlSize(.small)
                    }
                } else if receiptWasSent {
                    Label("Send Receipt Again", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Send Receipt", systemImage: "envelope.badge")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(recipientIssue != nil || isBusy || !canDeliverReceipt)
            .help(receiptSendHelp)
            .accessibilityLabel(receiptSendTitle)
            .accessibilityHint(receiptSendAccessibilityHint)

            Button {
                exportReceipt()
            } label: {
                if isExporting {
                    Label {
                        Text("Preparing Receipt…")
                    } icon: {
                        ProgressView().controlSize(.small)
                    }
                } else {
                    Label("Export Receipt PDF", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(isBusy || !canDeliverReceipt)
            .help(receiptExportHelp)
            .accessibilityLabel("Export receipt PDF")
            .accessibilityHint("Opens a save panel to export the receipt as a PDF.")

            Button {
                openInvoice(card.id)
                dismiss()
            } label: {
                Label("Open Invoice", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(isBusy)
            .help("Open this invoice in the Invoices workspace")
            .accessibilityLabel("Open invoice")

            if hasReceiptPaymentDetails {
                BillingHubPanelMoreOptionsMenu(isDisabled: isBusy) {
                    Button {
                        showsReopenConfirmation = true
                    } label: {
                        Label("Reopen as Sent", systemImage: "arrow.uturn.backward")
                    }
                    .help("Move this invoice back to Sent and clear its recorded payment metadata")
                    .accessibilityLabel("Reopen invoice as sent")
                }
            }
        }
        .defaultFocus($receiptEmailFocused, true)
        .confirmationDialog(
            "Send receipt again?",
            isPresented: $showsReceiptResendConfirmation,
            titleVisibility: .visible
        ) {
            Button("Send Again") {
                sendReceipt()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A receipt was already sent. Send another to \(receiptDeliverySummary)?")
        }
        .confirmationDialog(
            BillingHubConfirmationCopy.reopenPaymentTitle,
            isPresented: $showsReopenConfirmation,
            titleVisibility: .visible
        ) {
            Button(BillingHubConfirmationCopy.reopenPaymentButtonTitle, role: .destructive) {
                reopenAsSent()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(BillingHubConfirmationCopy.reopenPaymentMessage)
        }
        .task {
            guard let invoice = await viewModel.invoice(byId: card.id) else {
                isLoadingInvoice = false
                operationFeedback = "Invoice could not be loaded."
                return
            }
            invoiceTotal = NSDecimalNumber(decimal: invoice.totalAmount).doubleValue
            paidDate = invoice.paidDate
            paymentLine = BillingHubPaymentNoteFormatter.paymentLine(from: invoice.notes)
            isLoadingInvoice = false

            guard receiptEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let preferred = BillingHubInvoiceEmailPrefill.preferredRecipient(
                    billToEmail: invoice.billToEmail,
                    clientEmail: invoice.clientEmail
                  ) else { return }
            receiptEmail = preferred
        }
    }

    private func missingDetailLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(StyleGuide.Typography.itemSubtitle)
            .foregroundStyle(ColorSystem.Status.warning)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var receiptSendTitle: String {
        receiptWasSent ? "Send receipt again" : "Send receipt"
    }

    private var receiptSendHelp: String {
        guard hasReceiptPaymentDetails else {
            return "Record complete payment details before sending a receipt"
        }
        return receiptWasSent
            ? "Confirm before sending another receipt"
            : "Open Mail with this receipt. Payment status stays unchanged."
    }

    private var receiptSendAccessibilityHint: String {
        guard hasReceiptPaymentDetails else {
            return "Disabled until a payment date and payment details are recorded. Reopen as Sent to add them."
        }
        return receiptWasSent
            ? "A receipt was already sent. Opens confirmation before another receipt is sent."
            : "Opens Mail with the payment summary and selected receipt attachment. Invoice remains Payment Received."
    }

    private var receiptExportHelp: String {
        hasReceiptPaymentDetails
            ? "Save the receipt as a PDF file"
            : "Record complete payment details before exporting a receipt"
    }

    @ViewBuilder
    private var paymentComparisonLabel: some View {
        switch paymentComparison {
        case .underpayment(let difference):
            Label(
                "Partial payment · \(BillingHubPaymentAmount.currencyText(difference)) remains outstanding.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(StyleGuide.Typography.itemSubtitle)
            .foregroundStyle(ColorSystem.Status.warning)
        case .overpayment(let difference):
            Label(
                "Overpayment recorded · \(BillingHubPaymentAmount.currencyText(difference)) above invoice total.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(StyleGuide.Typography.itemSubtitle)
            .foregroundStyle(ColorSystem.Status.warning)
        case .matches, nil:
            EmptyView()
        }
    }

    private func receiptFeedback(_ message: String) -> some View {
        let severity = BillingHubBulkFeedbackSeverity.classify(message)
        return Section {
            Label(message, systemImage: severity.symbolName)
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(severity.tint)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private func sendReceipt() {
        guard !isBusy, hasReceiptPaymentDetails else { return }
        operationFeedback = nil
        isSendingReceipt = true
        Task {
            let outcome = await viewModel.sendReceiptWithOutcome(
                id: card.id,
                recipientEmail: receiptEmail,
                includePDF: includePDF
            )
            isSendingReceipt = false
            operationFeedback = outcome.feedback
            if case .sent = outcome {
                receiptWasSent = true
            }
        }
    }

    private func requestSendReceipt() {
        guard !isBusy else { return }
        if receiptWasSent {
            showsReceiptResendConfirmation = true
        } else {
            sendReceipt()
        }
    }

    private func exportReceipt() {
        guard !isBusy, hasReceiptPaymentDetails else { return }
        operationFeedback = nil
        isExporting = true
        Task {
            let outcome = await viewModel.exportReceiptPDFWithOutcome(id: card.id)
            isExporting = false
            operationFeedback = outcome.feedback
        }
    }

    private func reopenAsSent() {
        guard !isBusy else { return }
        operationFeedback = nil
        isReopening = true
        Task {
            let shouldDismiss = await viewModel.reopenInvoiceAsPending(id: card.id)
            isReopening = false
            if shouldDismiss {
                dismiss()
            } else {
                operationFeedback = viewModel.bulkActionFeedback
            }
        }
    }
}
