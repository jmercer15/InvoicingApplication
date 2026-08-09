import Foundation

/// Receipts must be grounded in payment metadata, not only in an invoice's Paid lane status.
enum BillingHubReceiptReadiness {
    static let missingPaymentDetailsMessage =
        "Record a payment date and payment details before creating a receipt."
    static let paymentNotReceivedMessage =
        "Mark payment as received before creating a receipt."

    static func message(
        paidDate: Date?,
        notes: String?,
        isPaymentReceived: Bool = true
    ) -> String? {
        guard isPaymentReceived else { return paymentNotReceivedMessage }
        guard paidDate != nil,
              let paymentLine = BillingHubPaymentNoteFormatter.paymentLine(from: notes),
              !paymentLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return missingPaymentDetailsMessage
        }
        return nil
    }
}
