import PersistenceModels
import SwiftUI
import SharedUI

struct PendingPaymentPanel: View {
    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    let openInvoice: (UUID) -> Void
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var method: String = "Bank Transfer"
    @State private var reference: String = ""
    @State private var invoiceTotal: Double?
    @State private var isFinalizing = false
    @State private var isSavingNote = false
    @State private var isChangingStatus = false
    @State private var showsMismatchConfirmation = false
    @State private var showsOverdueConfirmation = false
    @State private var showsReturnToReadyConfirmation = false
    @State private var operationFeedback: String?
    @State private var noteIsSaved = false
    @State private var isMarkedOverdue = false
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) var dismiss

    private enum Field: Hashable {
        case amount
        case reference
    }

    private var isBusy: Bool { isFinalizing || isSavingNote || isChangingStatus }
    private var hasValidAmount: Bool { BillingHubPaymentAmount.isValid(amount) }
    private var parsedAmount: Double? { BillingHubPaymentAmount.parsedValue(amount) }
    private var paymentComparison: BillingHubPaymentAmount.Comparison? {
        guard let invoiceTotal else { return nil }
        return BillingHubPaymentAmount.comparison(entered: amount, invoiceTotal: invoiceTotal)
    }
    private var mismatchConfirmation: BillingHubPaymentAmount.MismatchConfirmation? {
        guard let invoiceTotal else { return nil }
        return BillingHubPaymentAmount.mismatchConfirmation(
            entered: amount,
            invoiceTotal: invoiceTotal
        )
    }
    private var mismatchWarning: String? {
        guard let invoiceTotal else { return nil }
        return BillingHubPaymentAmount.mismatchWarning(entered: amount, invoiceTotal: invoiceTotal)
    }
    private var daysOverdue: Int? {
        guard case .invoice(let data) = card else { return nil }
        return data.daysOverdue
    }
    private var isOverdue: Bool {
        guard case .invoice(let data) = card else { return false }
        return data.isOverdue
    }

    var body: some View {
        Group {
            paymentDetailsSection

            if let invoiceTotal {
                Section("Payment Summary") {
                    LabeledContent(
                        "Invoice total",
                        value: BillingHubPaymentAmount.currencyText(invoiceTotal)
                    )
                    if let parsedAmount {
                        LabeledContent(
                            "Amount received",
                            value: BillingHubPaymentAmount.currencyText(parsedAmount)
                        )
                    }
                    BillingHubPaymentComparisonLabel(
                        comparison: paymentComparison,
                        style: .entry
                    )
                }
            } else {
                Section {
                    ProgressView("Loading invoice total…")
                        .controlSize(.small)
                }
            }

            Section {
                Label(
                    paymentActionSummary,
                    systemImage: "info.circle"
                )
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if isOverdue || isMarkedOverdue {
                Section {
                    Label(
                        overdueGuidance,
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(ColorSystem.Status.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                }
            }

            if let operationFeedback {
                BillingHubOperationFeedbackSection(message: operationFeedback)
            }

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
            .help("Open this invoice in the Invoices workspace")
            .accessibilityLabel("Open invoice")

            Button {
                requestFinalizePayment()
            } label: {
                BillingHubBusyButtonLabel.titledProgress(
                    isBusy: isFinalizing,
                    busyTitle: "Recording Payment…",
                    idleTitle: finalizeButtonTitle,
                    systemImage: "checkmark.seal.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(isBusy || !hasValidAmount || invoiceTotal == nil)
            .help(finalizeButtonHelp)
            .accessibilityLabel(finalizeButtonTitle)
            .accessibilityHint(finalizeButtonHint)

            Button {
                saveNote()
            } label: {
                if isSavingNote {
                    BillingHubBusyButtonLabel.titledProgress(
                        isBusy: true,
                        busyTitle: "Saving Note…",
                        idleTitle: "Save Note Only",
                        systemImage: "note.text.badge.plus"
                    )
                } else if noteIsSaved {
                    Label("Payment Note Saved", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Save Note Only", systemImage: "note.text.badge.plus")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(isBusy || !hasValidAmount || invoiceTotal == nil)
            .help("Save these payment details as a note without changing the invoice status")
            .accessibilityLabel("Save payment note only")
            .accessibilityHint("Persists the payment details as a note on the invoice. The invoice status does not change.")

            if noteIsSaved {
                Label(
                    "Details saved. Invoice remains Sent until you record payment received.",
                    systemImage: "info.circle.fill"
                )
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                .accessibilityElement(children: .combine)
            }

            BillingHubPanelMoreOptionsMenu(isDisabled: isBusy) {
                if !isMarkedOverdue {
                    Button {
                        showsOverdueConfirmation = true
                    } label: {
                        Label("Mark as Overdue", systemImage: "exclamationmark.circle")
                    }
                    .help("Move this invoice from Sent to Overdue")
                    .accessibilityLabel("Mark invoice as overdue")
                }

                Button {
                    showsReturnToReadyConfirmation = true
                } label: {
                    Label("Return to Ready to Send", systemImage: "arrow.uturn.backward")
                }
                .help("Return invoice to Ready to Send for delivery corrections")
                .accessibilityLabel("Move invoice back to ready to send")
            }
        }
        .defaultFocus($focusedField, .amount)
        .confirmationDialog(
            mismatchConfirmation?.title ?? "Record Payment?",
            isPresented: $showsMismatchConfirmation,
            titleVisibility: .visible
        ) {
            Button(mismatchConfirmation?.buttonTitle ?? "Record Payment") {
                finalizePayment()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(mismatchConfirmation?.message ?? "")
        }
        .confirmationDialog(
            BillingHubConfirmationCopy.markOverdueTitle,
            isPresented: $showsOverdueConfirmation,
            titleVisibility: .visible
        ) {
            Button(BillingHubConfirmationCopy.markOverdueButtonTitle) {
                changeStatus {
                    await viewModel.markInvoiceOverdue(id: card.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(BillingHubConfirmationCopy.markOverdueMessage)
        }
        .confirmationDialog(
            BillingHubConfirmationCopy.returnToReadyTitle,
            isPresented: $showsReturnToReadyConfirmation,
            titleVisibility: .visible
        ) {
            Button(BillingHubConfirmationCopy.returnToReadyButtonTitle) {
                changeStatus {
                    await viewModel.moveInvoiceBackToReadyToSend(id: card.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(BillingHubConfirmationCopy.returnToReadyMessage)
        }
        .task {
            guard let invoice = await viewModel.invoice(byId: card.id) else {
                operationFeedback = "Invoice could not be loaded."
                return
            }
            invoiceTotal = NSDecimalNumber(decimal: invoice.totalAmount).doubleValue
            isMarkedOverdue = invoice.effectiveStatus == .overdue
            if amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                amount = CurrencyFormatting.editableAmount(invoice.totalAmount)
            }
            if invoice.paidDate != nil {
                date = invoice.paidDate ?? date
            }
        }
    }

    private var paymentDetailsSection: some View {
        Section("Payment Details") {
            TextField("Amount", text: $amount)
                .monospacedDigit()
                .submitLabel(.next)
                .help("Total amount received")
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .amount)
                .onChange(of: amount) { _, _ in noteIsSaved = false }

            if let mismatchWarning {
                Text(mismatchWarning)
                    .font(StyleGuide.Typography.bodyMedium)
                    .foregroundStyle(Color.orange)
                    .accessibilityLabel("Payment amount mismatch warning")
            } else if !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !hasValidAmount {
                Label("Enter an amount greater than zero.", systemImage: "exclamationmark.circle.fill")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(ColorSystem.Status.error)
                    .accessibilityLabel("Invalid payment amount. Enter an amount greater than zero.")
            }

            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .help("The date the payment was received")
                .onChange(of: date) { _, _ in noteIsSaved = false }
            Picker("Method", selection: $method) {
                Text("Bank Transfer").tag("Bank Transfer")
                Text("Card").tag("Card")
                Text("Cash").tag("Cash")
                Text("Cheque").tag("Cheque")
            }
            .pickerStyle(.menu)
            .help("The payment method used by the client")
            .onChange(of: method) { _, _ in noteIsSaved = false }
            TextField("Reference (optional)", text: $reference)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .help("Transaction reference number or notes")
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .reference)
                .onChange(of: reference) { _, _ in noteIsSaved = false }
        }
    }

    private var finalizeButtonTitle: String {
        guard let mismatchConfirmation else { return "Mark Payment Received" }
        return mismatchConfirmation.buttonTitle.replacingOccurrences(of: "Record", with: "Review")
    }

    private var finalizeButtonHelp: String {
        guard mismatchConfirmation != nil else {
            return "Record the payment and move the invoice to Payment Received"
        }
        return "Review the amount difference before recording payment"
    }

    private var finalizeButtonHint: String {
        guard mismatchConfirmation != nil else {
            return "Records the payment date and method, then moves the invoice to Payment Received."
        }
        return "Opens a second confirmation. The invoice moves to Payment Received only after you confirm."
    }

    private var paymentActionSummary: String {
        if mismatchConfirmation != nil {
            return "Amount differs from the invoice total. Review the difference, then confirm before this invoice moves to Payment Received."
        }
        return "Mark Payment Received changes status and enables a receipt. Save Note Only keeps this invoice in Sent."
    }

    private var overdueGuidance: String {
        let timing: String
        if let days = daysOverdue, days > 0 {
            let dayLabel = days == 1 ? "day" : "days"
            timing = String(days) + " " + dayLabel + " past due. "
        } else {
            timing = ""
        }
        if isMarkedOverdue {
            return timing + "This invoice is marked overdue. Record payment when received, or return it to Ready to Send if delivery needs correcting."
        }
        return timing + "Payment is outstanding. Record payment when received, or use More Options to mark overdue or return it to Ready to Send."
    }

    private func requestFinalizePayment() {
        guard !isBusy, hasValidAmount else { return }
        if mismatchConfirmation != nil {
            showsMismatchConfirmation = true
            return
        }
        finalizePayment()
    }

    private func finalizePayment() {
        guard !isBusy, hasValidAmount else { return }
        operationFeedback = nil
        isFinalizing = true
        Task {
            let shouldDismiss = await viewModel.finalizePayment(
                id: card.id,
                amount: amount,
                date: date,
                method: method,
                reference: reference
            )
            isFinalizing = false
            if shouldDismiss {
                dismiss()
            } else {
                operationFeedback = viewModel.bulkActionFeedback
            }
        }
    }

    private func saveNote() {
        guard !isBusy, hasValidAmount else { return }
        operationFeedback = nil
        isSavingNote = true
        Task {
            let shouldDismiss = await viewModel.savePaymentDraft(
                id: card.id,
                amount: amount,
                date: date,
                method: method,
                reference: reference
            )
            isSavingNote = false
            if shouldDismiss {
                noteIsSaved = true
            }
            operationFeedback = viewModel.bulkActionFeedback
        }
    }

    private func changeStatus(
        _ action: @escaping @MainActor () async -> Bool
    ) {
        guard !isBusy else { return }
        operationFeedback = nil
        isChangingStatus = true
        Task {
            let shouldDismiss = await action()
            isChangingStatus = false
            if shouldDismiss {
                dismiss()
            } else {
                operationFeedback = viewModel.bulkActionFeedback
            }
        }
    }
}
