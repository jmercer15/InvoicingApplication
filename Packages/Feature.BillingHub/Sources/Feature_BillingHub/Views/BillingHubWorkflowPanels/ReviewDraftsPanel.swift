import PersistenceModels
import SwiftUI
import SharedUI

struct ReviewDraftsPanel: View {
    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    let openInvoice: (UUID) -> Void
    /// When true, Approve is disabled — blockers are already listed in the Compliance Checklist above.
    let hasComplianceBlockers: Bool
    /// Used to make the blocked recovery state specific without copying the checklist itself.
    let complianceBlockerCount: Int
    /// False while compliance is loading or unavailable. Approval must fail closed.
    let complianceCheckCompleted: Bool
    @State private var dueDate: Date = Date().addingTimeInterval(7 * 24 * 3600)
    @State private var initialDueDate: Date = Date().addingTimeInterval(7 * 24 * 3600)
    @State private var changeReason: String = ""
    @State private var showsChangeRequest = false
    @State private var showsDiscardReviewInputConfirmation = false
    @State private var isLoadingInvoice = true
    @State private var invoiceLoadFailed = false
    @State private var isApproving = false
    @State private var isRequestingChanges = false
    @State private var actionFeedback: ActionFeedback?
    @FocusState private var focusedControl: FocusedControl?
    @Environment(\.dismiss) var dismiss

    private enum FocusedControl: Hashable {
        case openInvoice
        case changeReason
    }

    private struct ActionFeedback: Equatable {
        enum Tone: Equatable {
            case success
            case error
        }

        let message: String
        let tone: Tone
    }

    private var isBusy: Bool { isApproving || isRequestingChanges }
    private var canRequestChanges: Bool {
        !changeReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var canApprove: Bool {
        !isLoadingInvoice && !invoiceLoadFailed && BillingHubComplianceApprovalPolicy.canApprove(
            isBusy: isBusy,
            hasBlockers: hasComplianceBlockers,
            checkCompleted: complianceCheckCompleted
        )
    }
    private var hasUnsavedReviewInput: Bool {
        !changeReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !Calendar.current.isDate(dueDate, inSameDayAs: initialDueDate)
    }

    var body: some View {
        Group {
            Section {
                VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingTiny) {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .help("Expected date the payment should be received")
                    Text("Saved when you approve this draft.")
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                }
            }

            if isLoadingInvoice {
                HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                    ProgressView().controlSize(.small)
                    Text("Loading saved due date…")
                }
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                .accessibilityElement(children: .combine)
            } else if invoiceLoadFailed {
                Label(
                    "Invoice could not be loaded. Reopen Billing Hub and try again.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(ColorSystem.Status.error)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }

            // Approval advances workflow; opening invoice supports that decision, so it remains secondary.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    openInvoiceButton
                    approveButton
                }

                VStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                    approveButton
                    openInvoiceButton
                }
            }

            if hasComplianceBlockers {
                Label(
                    "\(complianceBlockerCount) compliance blocker\(complianceBlockerCount == 1 ? "" : "s") need changes in the invoice before approval.",
                    systemImage: "xmark.octagon.fill"
                )
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(ColorSystem.Status.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
            } else if !complianceCheckCompleted {
                Text("Complete the compliance check above before approving.")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(ColorSystem.Status.warning)
            }

            if let actionFeedback {
                actionFeedbackView(actionFeedback)
            }

            Section {
                DisclosureGroup(isExpanded: $showsChangeRequest) {
                    TextField(text: $changeReason, axis: .vertical) {
                        Text("What needs changing?")
                    }
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isBusy)
                    .focused($focusedControl, equals: .changeReason)
                    .help("Short note that will be appended to the invoice")

                    Button {
                        requestChanges()
                    } label: {
                        if isRequestingChanges {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Request Changes")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(isBusy || !canRequestChanges)
                    .help("Flag this draft for changes before approval")
                    .accessibilityLabel("Request changes")
                    .accessibilityHint("Adds your note to the invoice and keeps it in Review Drafts.")
                } label: {
                    VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingTiny) {
                        Text("Request Changes")
                            .font(StyleGuide.Typography.bodyMedium)
                        Text("Add a revision note instead of approving.")
                            .font(StyleGuide.Typography.itemSubtitle)
                            .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                    }
                }
            }
        }
        .defaultFocus($focusedControl, .openInvoice)
        .confirmationDialog(
            "Open Invoice and discard review input?",
            isPresented: $showsDiscardReviewInputConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard and Open Invoice", role: .destructive) {
                openInvoiceWorkspace()
            }
            Button("Keep Reviewing", role: .cancel) {}
        } message: {
            Text(discardReviewInputMessage)
        }
        .onChange(of: showsChangeRequest) { _, isExpanded in
            if isExpanded {
                actionFeedback = nil
            }
        }
        .task {
            defer { isLoadingInvoice = false }
            guard let invoice = await viewModel.invoice(byId: card.id) else {
                invoiceLoadFailed = true
                return
            }
            if let existingDueDate = invoice.dueDate {
                dueDate = existingDueDate
                initialDueDate = existingDueDate
            }
        }
    }

    private var openInvoiceButton: some View {
        Button {
            requestOpenInvoice()
        } label: {
            Label(openInvoiceTitle, systemImage: "doc.text.magnifyingglass")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(isBusy)
        .focused($focusedControl, equals: .openInvoice)
        .help(openInvoiceHelp)
        .accessibilityLabel(openInvoiceTitle)
        .accessibilityHint(openInvoiceAccessibilityHint)
    }

    private var openInvoiceTitle: String {
        hasComplianceBlockers ? "Resolve in Invoice" : "Open Invoice"
    }

    private var openInvoiceHelp: String {
        hasComplianceBlockers
            ? "Open the invoice to resolve the listed compliance blockers"
            : "Review the full invoice and PDF in the Invoices workspace"
    }

    private var openInvoiceAccessibilityHint: String {
        hasComplianceBlockers
            ? "Opens this invoice in the Invoices workspace so you can resolve the listed compliance blockers."
            : "Opens this invoice in the Invoices workspace to review line items and the PDF."
    }

    private var discardReviewInputMessage: String {
        let hasUnsavedReason = !changeReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasUnsavedDueDate = !Calendar.current.isDate(dueDate, inSameDayAs: initialDueDate)
        return switch (hasUnsavedDueDate, hasUnsavedReason) {
        case (true, true):
            "The selected due date is saved only on approval, and the change request has not been saved. Both will be lost."
        case (true, false):
            "The selected due date is saved only on approval. It will be lost."
        case (false, true):
            "The change request has not been saved. It will be lost."
        case (false, false):
            "No review input will be lost."
        }
    }

    private func requestOpenInvoice() {
        guard !isBusy else { return }
        if hasUnsavedReviewInput {
            showsDiscardReviewInputConfirmation = true
        } else {
            openInvoiceWorkspace()
        }
    }

    private func openInvoiceWorkspace() {
        openInvoice(card.id)
        dismiss()
    }

    private var approveButton: some View {
        Button {
            approve()
        } label: {
            if isApproving {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity)
            } else {
                Label("Approve", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        .disabled(!canApprove)
        .help(approvalHelp)
        .accessibilityLabel("Approve draft invoice")
        .accessibilityHint(approvalAccessibilityHint)
    }

    private func approve() {
        guard canApprove else { return }
        isApproving = true
        Task {
            let shouldDismiss = await viewModel.approveDraftInvoice(id: card.id, dueDate: dueDate)
            isApproving = false
            if shouldDismiss {
                dismiss()
            } else {
                actionFeedback = ActionFeedback(
                    message: viewModel.bulkActionFeedback ?? "Approval could not be completed. Resolve the issue and try again.",
                    tone: .error
                )
            }
        }
    }

    private var approvalHelp: String {
        if isLoadingInvoice {
            return "Wait for the saved due date to load before approving"
        }
        if invoiceLoadFailed {
            return "Reopen Billing Hub to load this invoice before approving"
        }
        if hasComplianceBlockers {
            return "Resolve compliance blockers before approving"
        }
        if !complianceCheckCompleted {
            return "Wait for or retry the compliance check before approving"
        }
        return "Approve this draft and move it to Ready to Send"
    }

    private var approvalAccessibilityHint: String {
        if isLoadingInvoice {
            return "Disabled while saved invoice details load."
        }
        if invoiceLoadFailed {
            return "Disabled because invoice details could not be loaded."
        }
        if hasComplianceBlockers {
            return "Disabled until compliance blockers listed above are resolved."
        }
        if !complianceCheckCompleted {
            return "Disabled until the compliance check completes successfully."
        }
        return "Saves the due date and moves the invoice to ready to send."
    }

    private func requestChanges() {
        guard !isBusy, canRequestChanges else { return }
        isRequestingChanges = true
        Task {
            let didSave = await viewModel.requestChanges(for: card.id, reason: changeReason)
            isRequestingChanges = false
            if didSave {
                changeReason = ""
                actionFeedback = ActionFeedback(
                    message: "Changes requested. Note saved; this draft remains in Review Drafts.",
                    tone: .success
                )
            } else {
                actionFeedback = ActionFeedback(
                    message: viewModel.bulkActionFeedback ?? "Changes could not be requested. Try again.",
                    tone: .error
                )
            }
        }
    }

    @ViewBuilder
    private func actionFeedbackView(_ feedback: ActionFeedback) -> some View {
        let isSuccess = feedback.tone == .success
        Label(
            feedback.message,
            systemImage: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        )
        .font(StyleGuide.Typography.itemSubtitle)
        .foregroundStyle(isSuccess ? ColorSystem.Status.success : ColorSystem.Status.error)
        .accessibilityElement(children: .combine)
    }
}
