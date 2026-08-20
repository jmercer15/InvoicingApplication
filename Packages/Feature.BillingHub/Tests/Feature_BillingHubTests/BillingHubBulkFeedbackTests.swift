import Foundation
import Testing
import CoreTesting
@testable import Feature_BillingHub

@Suite(.tags(.integration))
struct BillingHubBulkFeedbackTests {
    @Test func bulkActionProgressBuildsNOfMCopyAndClampsFraction() {
        let progress = BillingHubBulkActionProgress(
            action: "Moving to Grouped",
            completedCount: 2,
            totalCount: 5
        )
        #expect(progress.message == "Moving to Grouped 2 of 5")
        #expect(
            BillingHubBulkActionProgress(action: "Creating drafts", completedCount: 9, totalCount: 4)
                .fractionCompleted == 1
        )
        #expect(
            BillingHubBulkActionProgress(action: "Creating drafts", completedCount: -1, totalCount: 4)
                .fractionCompleted == 0
        )
    }

    @Test func severityClassifiesErrors() {
        #expect(BillingHubBulkFeedbackSeverity.classify("Invoice could not be found.") == .error)
        #expect(BillingHubBulkFeedbackSeverity.classify("No email app is configured on this Mac.") == .error)
        #expect(BillingHubBulkFeedbackSeverity.classify("Add at least one recipient before sending.") == .error)
        #expect(BillingHubBulkFeedbackSeverity.classify("Fix invalid email addresses before sending.") == .error)
    }

    @Test func severityClassifiesWarnings() {
        #expect(
            BillingHubBulkFeedbackSeverity.classify(
                "Marked 2 invoices as Sent without email. 1 invoice blocked."
            ) == .warning
        )
        #expect(
            BillingHubBulkFeedbackSeverity.classify("Payment details saved as a note. Status unchanged.") == .warning
        )
        #expect(
            BillingHubBulkFeedbackSeverity.classify(
                "Invoice email sent, but the status could not be updated."
            ) == .warning
        )
    }

    @Test func receiptReadinessRequiresBothDateAndTaggedPaymentDetails() {
        let paidDate = Date(timeIntervalSince1970: 0)
        let paymentLine = BillingHubPaymentNoteFormatter.applyingPaymentLine(
            amount: "100",
            date: paidDate,
            method: "Cash",
            reference: "",
            to: nil
        )

        #expect(
            BillingHubReceiptReadiness.message(paidDate: nil, notes: paymentLine)
                == BillingHubReceiptReadiness.missingPaymentDetailsMessage
        )
        #expect(
            BillingHubReceiptReadiness.message(paidDate: paidDate, notes: nil)
                == BillingHubReceiptReadiness.missingPaymentDetailsMessage
        )
        #expect(BillingHubReceiptReadiness.message(paidDate: paidDate, notes: paymentLine) == nil)
        #expect(
            BillingHubReceiptReadiness.message(
                paidDate: paidDate,
                notes: paymentLine,
                isPaymentReceived: false
            ) == BillingHubReceiptReadiness.paymentNotReceivedMessage
        )
    }

    @Test func emailRecipientsParseSupportedSeparators() {
        #expect(
            BillingHubEmailRecipients.parse(
                "accounts@example.com; client@example.org, \nteam@example.net"
            ) == ["accounts@example.com", "client@example.org", "team@example.net"]
        )
    }

    @Test func emailRecipientsRejectMalformedAddresses() {
        #expect(
            BillingHubEmailRecipients.invalidAddresses(
                in: "valid@example.com, missing-domain@example, two@@example.com"
            ) == ["missing-domain@example", "two@@example.com"]
        )
        #expect(
            BillingHubEmailRecipients.validationMessage(for: "bad-address", fieldName: "To", required: true)
                == "To contains an invalid email address: bad-address"
        )
    }

    @Test func emailRecipientsValidateSelfCopyAndDeduplicateCaseInsensitively() {
        #expect(BillingHubEmailRecipients.validSingleAddress(" Business@Example.com ") == "Business@Example.com")
        #expect(BillingHubEmailRecipients.validSingleAddress("one@example.com; two@example.com") == nil)
        #expect(
            BillingHubEmailRecipients.unique([
                "accounts@example.com", "ACCOUNTS@example.com", "client@example.com",
            ]) == ["accounts@example.com", "client@example.com"]
        )
    }

    @Test func optionalEmailListAllowsEmptyButRequiredListDoesNot() {
        #expect(BillingHubEmailRecipients.validationMessage(for: " ", fieldName: "Cc", required: false) == nil)
        #expect(
            BillingHubEmailRecipients.validationMessage(for: " ", fieldName: "To", required: true)
                == "Enter at least one recipient email address."
        )
    }
}
