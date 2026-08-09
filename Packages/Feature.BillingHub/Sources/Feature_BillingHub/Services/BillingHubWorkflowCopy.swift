import Foundation

enum BillingHubWorkflowCopy {
    static let markSentWithoutEmail = "Mark as Sent Without Email"
    static let finishMarkingSent = "Finish Marking as Sent"

    static func bulkMarkSentActionTitle(count: Int) -> String {
        "\(markSentWithoutEmail) (\(count))"
    }

    static let bulkMarkSentProgressAction = "Marking as Sent without email"

    static func bulkMarkSentResult(processed: Int, blocked: Int) -> String {
        let success = "Marked \(invoiceCount(processed)) as Sent without email."
        guard blocked > 0 else { return success }
        return "\(success) \(invoiceCount(blocked)) blocked."
    }

    static func bulkPaymentActionTitle(count: Int) -> String {
        "Mark Payment Received Without Details (\(count))"
    }

    static let bulkPaymentProgressAction = "Marking payment received"

    static func bulkPaymentResult(processed: Int, blocked: Int) -> String {
        let success = "Marked payment received for \(invoiceCount(processed))."
        let missingDetails = "Amount, method, and reference were not recorded."
        guard blocked > 0 else { return "\(success) \(missingDetails)" }
        return "\(success) \(invoiceCount(blocked)) blocked. \(missingDetails)"
    }

    static let markSentConfirmationTitle = "Mark as Sent without sending email?"
    static let markSentConfirmationButtonTitle = "Mark as Sent"
    static let markSentConfirmationMessage =
        "Use this only when the invoice was delivered outside this app. It records today as the sent date and moves the invoice to Sent without opening Mail."

    static let finishMarkingSentConfirmationTitle = "Finish marking invoice as Sent?"
    static let finishMarkingSentConfirmationButtonTitle = "Mark as Sent"
    static let finishMarkingSentConfirmationMessage =
        "Mail reported that this invoice email was sent, but the status update did not finish. This records today as the sent date and moves the invoice to Sent without sending another email."

    private static func invoiceCount(_ count: Int) -> String {
        "\(count) invoice\(count == 1 ? "" : "s")"
    }
}

enum BillingHubInvoiceSendOutcome: Equatable, Sendable {
    case sent(invoiceNumber: String)
    case cancelled
    case failed(String)
    case emailSentStatusPending(String?)

    var feedback: String {
        switch self {
        case .sent(let invoiceNumber):
            "Email sent. Invoice \(invoiceNumber) is now Sent."
        case .cancelled:
            "Invoice send cancelled. Status remains Ready to Send."
        case .failed(let message):
            message
        case .emailSentStatusPending(let detail):
            [
                "Invoice email sent, but status remains Ready to Send.",
                "Choose \(BillingHubWorkflowCopy.finishMarkingSent) to finish.",
                detail
            ]
            .compactMap { $0 }
            .joined(separator: " ")
        }
    }

    var shouldDismiss: Bool {
        if case .sent = self { return true }
        return false
    }

    var needsManualStatusRecovery: Bool {
        if case .emailSentStatusPending = self { return true }
        return false
    }
}

enum BillingHubReceiptSendOutcome: Equatable, Sendable {
    case sent(recipientCount: Int, attachedPDF: Bool)
    case cancelled
    case failed(String)

    var feedback: String {
        switch self {
        case .sent(let recipientCount, let attachedPDF):
            let recipients = recipientCount == 1 ? "recipient" : "recipients"
            let attachment = attachedPDF ? " PDF receipt attached." : " No PDF attached."
            return "Receipt email sent to \(recipientCount) \(recipients).\(attachment) Invoice remains Payment Received."
        case .cancelled:
            return "Receipt send cancelled. Invoice remains Payment Received."
        case .failed(let message):
            return "\(message) Invoice remains Payment Received."
        }
    }
}

enum BillingHubReceiptExportOutcome: Equatable {
    case saved(URL)
    case cancelled
    case failed(String)

    var feedback: String {
        switch self {
        case .saved(let url):
            return "Receipt PDF saved as \(url.lastPathComponent)."
        case .cancelled:
            return "Receipt export cancelled. No file was saved."
        case .failed(let message):
            return message
        }
    }
}

enum BillingHubReceiptEmailCopy {
    static func subject(invoiceNumber: String) -> String {
        "Payment receipt — \(invoiceNumber)"
    }

    static func message(
        invoiceNumber: String,
        paymentSummary: String,
        includesPDF: Bool
    ) -> String {
        var parts = ["Payment receipt for invoice \(invoiceNumber)."]
        if !paymentSummary.isEmpty {
            parts.append(paymentSummary)
        }
        if includesPDF {
            parts.append("A PDF receipt is attached.")
        }
        return parts.joined(separator: "\n\n")
    }
}
