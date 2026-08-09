struct InvoiceEditorBillingStagePresentation: Equatable {
    let title: String
    let systemImage: String
    let guidance: String

    static func resolve(_ status: InvoiceStatus) -> Self {
        switch status {
        case .draft:
            Self(
                title: "Review Draft",
                systemImage: "pencil.circle",
                guidance: "Review and save invoice details here. Approve the draft in Billing Hub when it is ready."
            )
        case .readyToSend:
            Self(
                title: "Ready to Send",
                systemImage: "checkmark.circle",
                guidance: "This invoice is approved. Send it from Billing Hub so delivery and status stay linked."
            )
        case .sent:
            Self(
                title: "Sent",
                systemImage: "paperplane",
                guidance: "Record payment or move this invoice back to Ready to Send from Billing Hub."
            )
        case .paid:
            Self(
                title: "Payment Received",
                systemImage: "checkmark.circle.fill",
                guidance: "Send or export the payment receipt from Billing Hub."
            )
        case .overdue:
            Self(
                title: "Overdue",
                systemImage: "exclamationmark.circle",
                guidance: "Review payment or return this invoice to Ready to Send from Billing Hub."
            )
        case .cancelled:
            Self(
                title: "Cancelled",
                systemImage: "xmark.circle",
                guidance: "Billing Hub owns invoice lifecycle changes. Document edits here do not reactivate it."
            )
        case .voided:
            Self(
                title: "Voided",
                systemImage: "nosign",
                guidance: "Billing Hub owns invoice lifecycle changes. Document edits here do not reactivate it."
            )
        }
    }
}
