import SwiftUI
import Core
import SharedUI

public struct EditingPanel: View {
    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    let openInvoice: (UUID) -> Void
    let openSession: (UUID) -> Void
    @State internal var editedClient: String = ""
    @State internal var editedDuration: String = ""
    @Environment(\.dismiss) var dismiss
    @FocusState internal var focusedField: Field?
    @State internal var supportLogDraft: SupportLogDraft = SupportLogDraft()
    @State internal var supportLogError: String?
    @State internal var complianceWarnings: [Core.ComplianceIssue] = []
    @State internal var complianceBlockers: [Core.ComplianceIssue] = []
    @State internal var complianceLoadError: String?
    @State internal var isLoadingCompliance = false
    @State internal var isSupportLogExpanded = false
    @State private var isSavingDetails = false
    
    public init(
        card: KanbanCardData,
        viewModel: BillingHubViewModel,
        openInvoice: @escaping (UUID) -> Void = { _ in },
        openSession: @escaping (UUID) -> Void = { _ in }
    ) {
        self.card = card
        self.viewModel = viewModel
        self.openInvoice = openInvoice
        self.openSession = openSession
    }
    
    enum Field {
        case client, duration
    }

    public var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
                    BillingPipelineProgressView(
                        currentStage: pipelineStage,
                        accent: card.accentColor
                    )

                    Label(subcolumnHeader.title, systemImage: subcolumnHeader.icon)
                        .font(BillingHubTheme.Typography.sectionTitle)
                        .symbolRenderingMode(.hierarchical)

                    Text(workflowGuidance)
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                }
                .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
            }

            switch card {
            case .session:
                Section("Session Details") { sessionDetailsContent }
                Section("Status") { sessionStatusContent }
                panelContent

                if showsCrossFeatureNavigationSection {
                    Section("Open In Workspace") {
                        crossFeatureNavigationContent
                    }
                }

                supportLogDisclosureSection
            case .invoice:
                Section("Invoice Summary") { invoiceDetailsContent }
                if card.columnType == .reviewDrafts {
                    Section("Compliance Checklist") { complianceChecklistContent }
                }
                Section("Status") { invoiceStatusContent }
                panelContent
            }
        }
        .formStyle(.grouped)
        .navigationTitle(editingPanelTitle)
        .toolbar {
            if usesSessionDetailSaveBar {
                // Session duration edits live here; lane panels own the workflow next-step.
                AppToolbarSheetBar(
                    confirmTitle: "Save Session",
                    onCancel: { dismiss() },
                    onConfirm: {
                        Task {
                            let saved = await persistEdits()
                            if saved {
                                dismiss()
                            }
                        }
                    }
                )
            } else {
                // Invoice workflow actions (Approve / Send / Mark Paid) are the primary exit.
                // Escape/Close discards detail edits; Done persists client-name changes then closes.
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isSavingDetails)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveInvoiceDetails()
                    } label: {
                        BillingHubBusyButtonLabel.progressOrText(
                            isBusy: isSavingDetails,
                            title: "Done"
                        )
                    }
                    .disabled(isSavingDetails || !hasValidInvoiceDetails)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(minWidth: BillingHubTheme.Dimensions.editingPanelMinWidth, minHeight: BillingHubTheme.Dimensions.editingPanelMinHeight)
        .onAppear {
            if case .session = card {
                focusedField = .duration
            }
        }
        .task(id: card.id) {
            await loadComplianceData()
            switch card {
            case .session(let sessionData):
                if editedDuration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    editedDuration = sessionData.duration
                }
            case .invoice(let invoiceData):
                if editedClient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    editedClient = invoiceData.clientName
                }
            }
        }
    }

    /// Session sheets keep Cancel/Save for duration. Invoice sheets use Done so Approve/Send
    /// stay the clear primary actions.
    private var usesSessionDetailSaveBar: Bool {
        if case .session = card { return true }
        return false
    }

    /// Invoice lane panels already expose Open Invoice; session cards still need Calendar jump.
    private var showsCrossFeatureNavigationSection: Bool {
        if case .session = card { return true }
        return false
    }

    @ViewBuilder
    private var crossFeatureNavigationContent: some View {
        switch card {
        case .session(let sessionData):
            Button("Open Session in Calendar") {
                openSession(sessionData.sessionId)
                dismiss()
            }
        case .invoice(let invoiceData):
            Button("Open Invoice in Invoices") {
                openInvoice(invoiceData.invoiceId)
                dismiss()
            }
        }
    }
    
    private func persistEdits() async -> Bool {
        switch card {
        case .session(let data):
            return await viewModel.updateSessionDetails(id: data.sessionId, durationString: editedDuration)
        case .invoice(let data):
            return await viewModel.updateInvoiceDetails(id: data.invoiceId, clientName: editedClient)
        }
    }

    private func saveInvoiceDetails() {
        guard !isSavingDetails, hasValidInvoiceDetails else { return }
        isSavingDetails = true
        Task {
            let saved = await persistEdits()
            isSavingDetails = false
            if saved {
                dismiss()
            }
        }
    }

    private var hasValidInvoiceDetails: Bool {
        guard case .invoice = card else { return true }
        return !editedClient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var editingPanelTitle: String {
        switch card {
        case .session:
            return "Session — \(statusText(for: card.currentWorkflowStatus))"
        case .invoice:
            return "Invoice — \(statusText(for: card.currentWorkflowStatus))"
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        Group {
            switch (card, card.columnType) {
            case (.session, .addTravel):
                BillingHubAddTravelPanel(card: card, viewModel: viewModel)
            case (.session, .completed):
                CompletedPanel(card: card, viewModel: viewModel)
            case (.session, .grouped):
                GroupedPanel(card: card, viewModel: viewModel, openInvoice: openInvoice)
            case (.invoice, .reviewDrafts):
                ReviewDraftsPanel(
                    card: card,
                    viewModel: viewModel,
                    openInvoice: openInvoice,
                    hasComplianceBlockers: !complianceBlockers.isEmpty,
                    complianceBlockerCount: complianceBlockers.count,
                    complianceCheckCompleted: !isLoadingCompliance && complianceLoadError == nil
                )
            case (.invoice, .readyToSend):
                ReadyToSendPanel(card: card, viewModel: viewModel, openInvoice: openInvoice)
            case (.invoice, .pending):
                PendingPaymentPanel(card: card, viewModel: viewModel, openInvoice: openInvoice)
            case (.invoice, .received):
                PaymentReceivedPanel(card: card, viewModel: viewModel, openInvoice: openInvoice)
            default:
                EmptyView()
            }
        }
    }

    private var subcolumnHeader: (icon: String, title: String) {
        switch card.columnType {
        case .addTravel: return ("car", "Travel Charges")
        case .completed: return ("checkmark.circle", "Completed Options")
        case .grouped: return ("rectangle.stack", "Group")
        case .reviewDrafts: return ("doc.text.magnifyingglass", "Review Draft")
        case .readyToSend: return ("paperplane", "Send Invoice")
        case .pending: return ("clock", "Record Payment")
        case .received: return ("checkmark.seal", "Payment Received")
        }
    }

    private var pipelineStage: BillingPipelineStage {
        switch card.columnType {
        case .completed, .grouped, .addTravel:
            return .prepare
        case .reviewDrafts:
            return .review
        case .readyToSend:
            return .send
        case .pending:
            return .payment
        case .received:
            return .paid
        }
    }

    private var workflowGuidance: String {
        switch card.columnType {
        case .completed:
            return "Prepare this completed session for invoicing."
        case .grouped:
            return "Review this batch, then create its draft invoice."
        case .addTravel:
            return "Confirm billable travel before creating the draft."
        case .reviewDrafts:
            return "Resolve compliance issues, review the invoice, then approve it."
        case .readyToSend:
            return "Confirm recipients and send the approved invoice."
        case .pending:
            return "Record payment details when funds arrive."
        case .received:
            return "Send or export the final payment receipt."
        }
    }

    internal func statusText(for status: KanbanCardData.WorkflowStatus) -> String {
        status.recordTitle
    }
}
