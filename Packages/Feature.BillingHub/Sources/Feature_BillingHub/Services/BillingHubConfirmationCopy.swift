enum BillingHubConfirmationCopy {
    static func bulkPaymentTitle(count: Int) -> String {
        count == 1
            ? "Mark Payment Received Without Details?"
            : "Mark Payment Received for \(count) Invoices?"
    }

    static func bulkPaymentButtonTitle(count: Int) -> String {
        count == 1 ? "Mark Received Without Details" : "Mark \(count) Received Without Details"
    }

    static func bulkPaymentMessage(count: Int) -> String {
        let subject = count == 1 ? "This invoice" : "These \(count) invoices"
        return "\(subject) will move from Sent to Payment Received and receive today’s paid date. Amount, method, and reference will remain blank. You can undo this batch afterward."
    }

    static let reopenPaymentTitle = "Reopen as Sent and clear payment details?"
    static let reopenPaymentButtonTitle = "Reopen and Clear Payment"
    static let reopenPaymentMessage =
        "This moves the invoice from Payment Received back to Sent. It clears the paid date and saved Payment note; other invoice notes remain unchanged."

    static let markOverdueTitle = "Mark this invoice Overdue?"
    static let markOverdueButtonTitle = "Mark Overdue"
    static let markOverdueMessage =
        "This moves the invoice from Sent to Overdue. Sent date and saved payment notes remain unchanged."

    static let returnToReadyTitle = "Return to Ready to Send?"
    static let returnToReadyButtonTitle = "Return to Ready"
    static let returnToReadyMessage =
        "This clears the sent date and moves the invoice back to Ready to Send. It will no longer be tracked as payment outstanding or overdue. Saved invoice and payment notes remain unchanged."
}
