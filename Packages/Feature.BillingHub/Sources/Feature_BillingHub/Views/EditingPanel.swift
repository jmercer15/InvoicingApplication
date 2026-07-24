import SwiftUI
import Core
import Data
import SharedUI

public struct EditingPanel: View {
    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    let openInvoice: (UUID) -> Void
    let openSession: (UUID) -> Void
    @State internal var editedService: String = ""
    @State internal var editedClient: String = ""
    @State internal var editedDuration: String = ""
    @State internal var selectedPriority: Priority = .low
    @Environment(\.dismiss) var dismiss
    @FocusState internal var focusedField: Field?
    @State internal var supportLogDraft: SupportLogDraft = SupportLogDraft()
    @State internal var supportLogError: String?
    @State internal var complianceWarnings: [Core.ComplianceIssue] = []
    @State internal var complianceBlockers: [Core.ComplianceIssue] = []
    @State internal var complianceLoadError: String?
    
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
        case serviceType, client, duration
    }

    public var body: some View {
        Form {
            switch card {
            case .session:
                Section("Session Details") { sessionDetailsContent }
                Section("Support Log") { supportLogContent }
                Section("Priority & Status") { priorityStatusContent }
            case .invoice:
                Section("Invoice Details") { invoiceDetailsContent }
                Section("Compliance Checklist") { complianceChecklistContent }
                Section("Status") { invoiceStatusContent }
            }

            Section("Open In Workspace") {
                crossFeatureNavigationContent
            }

            Section {
                panelContent
            } header: {
                Label(subcolumnHeader.title, systemImage: subcolumnHeader.icon)
                    .font(BillingHubTheme.Typography.sectionTitle)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(editingPanelTitle)
        .toolbar {
            AppToolbarSheetBar(
                confirmTitle: "Save",
                onCancel: { dismiss() },
                onConfirm: {
                    saveChanges()
                    dismiss()
                }
            )
        }
        .frame(minWidth: BillingHubTheme.Dimensions.editingPanelMinWidth, minHeight: BillingHubTheme.Dimensions.editingPanelMinHeight)
        .defaultFocus($focusedField, .serviceType)
        .task(id: card.id) {
            await loadComplianceData()
        }
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
    
    private func saveChanges() {
        Task {
            switch card {
            case .session(let data):
                await viewModel.updateSessionDetails(id: data.sessionId, durationString: editedDuration)
            case .invoice(let data):
                await viewModel.updateInvoiceDetails(id: data.invoiceId, clientName: editedClient)
            }
        }
    }
    
    private var editingPanelTitle: String {
        switch card {
        case .session(_): return "Edit Session"
        case .invoice(_): return "Edit Invoice"
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
                GroupedPanel(card: card, viewModel: viewModel)
            case (.invoice, .reviewDrafts):
                ReviewDraftsPanel(card: card, viewModel: viewModel)
            case (.invoice, .readyToSend):
                ReadyToSendPanel(card: card, viewModel: viewModel)
            case (.invoice, .pending):
                PendingPaymentPanel(card: card, viewModel: viewModel)
            case (.invoice, .received):
                PaymentReceivedPanel(card: card, viewModel: viewModel)
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
        case .pending: return ("clock", "Awaiting Payment")
        case .received: return ("checkmark.seal", "Completed")
        }
    }

    internal func statusText(for status: KanbanCardData.WorkflowStatus) -> String {
        switch status {
        case .completed: return "Completed"
        case .grouped: return "Grouped"
        case .readyToInvoice: return "Ready to Invoice"
        case .draftReview: return "Draft Review"
        case .readyToSend: return "Ready to Send"
        case .pendingPayment: return "Pending Payment"
        case .paymentReceived: return "Payment Received"
        }
    }
}
