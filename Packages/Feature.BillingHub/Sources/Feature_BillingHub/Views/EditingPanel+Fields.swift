import SwiftUI
import SharedUI

extension EditingPanel {

    /// Read-only: service assignment is edited in Calendar (session) or Invoices (invoice line
    /// items), never here, so this stays a label instead of a TextField that silently discards edits.
    internal var serviceTypeField: some View {
        Group {
            switch card {
            case .session(let sessionData):
                BillingHubAdaptiveLabeledValue(
                    label: "Service Type",
                    value: sessionData.serviceName,
                    help: "Edit the assigned service in Calendar."
                )
            case .invoice(let invoiceData):
                BillingHubAdaptiveLabeledValue(
                    label: "Service Type",
                    value: invoiceData.serviceName,
                    help: "Edit invoice line items in Invoices."
                )
            }
        }
    }
    
    internal var durationAmountRow: some View {
        Group {
            switch card {
            case .session:
                TextField(text: $editedDuration) { Text("Duration") }
                    .submitLabel(.next)
                    .focused($focusedField, equals: .duration)
                    .textFieldStyle(.roundedBorder)
                    .help("The total duration of the session (e.g., 1h 30m)")
            case .invoice(let invoiceData):
                LabeledContent("Amount", value: invoiceData.amount)
                    .monospacedDigit()
                    .help("Edit invoice line items and totals in Invoices workspace")
            }
        }
    }
    
    /// Sessions don't persist a client rename here (client is an assignment, not free text), so
    /// only the invoice's client name field is actually editable.
    internal var clientField: some View {
        Group {
            switch card {
            case .session(let sessionData):
                BillingHubAdaptiveLabeledValue(
                    label: "Client",
                    value: sessionData.clientName,
                    help: "Reassign the client for this session in Calendar."
                )
            case .invoice:
                VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                    TextField(text: $editedClient) { Text("Client Name") }
                        .submitLabel(.done)
                        .focused($focusedField, equals: .client)
                        .textContentType(.name)
                        .textFieldStyle(.roundedBorder)
                        .help("The name of the client associated with this invoice")

                    if editedClient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label("Client name is required.", systemImage: "exclamationmark.circle.fill")
                            .font(StyleGuide.Typography.itemSubtitle)
                            .foregroundStyle(ColorSystem.Status.error)
                    }
                }
            }
        }
    }
}
