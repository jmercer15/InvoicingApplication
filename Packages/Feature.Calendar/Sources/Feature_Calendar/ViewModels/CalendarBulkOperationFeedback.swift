import Core
import Foundation

struct CalendarBulkOperationProgress: Equatable {
    let action: String
    let completedCount: Int
    let totalCount: Int

    var message: String {
        guard totalCount > 0 else { return action }
        return "\(action) \(completedCount) of \(totalCount)"
    }

    var fractionCompleted: Double {
        guard totalCount > 0 else { return 0 }
        return min(max(Double(completedCount) / Double(totalCount), 0), 1)
    }
}

/// Status-aware progress / result verbs for bulk Change Status.
enum CalendarBulkStatusProgressCopy {
    static func progressAction(for status: SessionStatus?) -> String {
        switch status {
        case .completed: return "Marking Completed"
        case .cancelled: return "Cancelling"
        case .scheduled: return "Marking Scheduled"
        case .noShow: return "Marking No Show"
        case .rescheduled: return "Marking Rescheduled"
        default: return "Updating"
        }
    }

    static func resultAction(for status: SessionStatus?) -> String {
        switch status {
        case .completed: return "Marked Completed"
        case .cancelled: return "Cancelled"
        case .scheduled: return "Marked Scheduled"
        case .noShow: return "Marked No Show"
        case .rescheduled: return "Marked Rescheduled"
        default: return "Updated"
        }
    }
}

struct CalendarBulkOperationFeedback: Equatable {
    enum Severity: Equatable {
        case success
        case warning
        case error
    }

    let message: String
    let severity: Severity
    /// Enables a recovery route when bulk actions intentionally leave invoiced sessions untouched.
    let hasInvoicedSkips: Bool
    /// Invoice cards to focus when the user opens Billing Hub from the recovery action.
    let invoicedInvoiceIDs: [UUID]
    /// Completed sessions ready for Billing Hub handoff (partial Mark Completed path).
    let billingHubHandoffSessionIDs: [UUID]
    /// Compact prepare-stage pipeline + subtitle for partial completion outcomes.
    let offersBillingHubPrepareStep: Bool

    var nextStepSubtitle: String? {
        guard offersBillingHubPrepareStep else { return nil }
        return "Next: prepare in Billing Hub"
    }

    init(
        message: String,
        severity: Severity,
        hasInvoicedSkips: Bool = false,
        invoicedInvoiceIDs: [UUID] = [],
        billingHubHandoffSessionIDs: [UUID] = [],
        offersBillingHubPrepareStep: Bool = false
    ) {
        self.message = message
        self.severity = severity
        self.hasInvoicedSkips = hasInvoicedSkips
        self.invoicedInvoiceIDs = invoicedInvoiceIDs.reduce(into: []) { result, id in
            if !result.contains(id) {
                result.append(id)
            }
        }
        self.billingHubHandoffSessionIDs = billingHubHandoffSessionIDs.reduce(into: []) { result, id in
            if !result.contains(id) {
                result.append(id)
            }
        }
        self.offersBillingHubPrepareStep = offersBillingHubPrepareStep
    }

    static func result(
        action: String,
        succeeded: Int,
        skipped: Int,
        failed: Int,
        invoicedInvoiceIDs: [UUID] = [],
        billingHubHandoffSessionIDs: [UUID] = [],
        offersBillingHubPrepareStep: Bool = false
    ) -> CalendarBulkOperationFeedback {
        var parts: [String] = []
        if succeeded > 0 {
            parts.append("\(action) \(succeeded) session\(succeeded == 1 ? "" : "s").")
        }
        if skipped > 0 {
            parts.append("Skipped \(skipped) already invoiced.")
        }
        if failed > 0 {
            parts.append("Failed \(failed).")
        }

        let severity: Severity
        if succeeded == 0, failed > 0 {
            severity = .error
        } else if skipped > 0 || failed > 0 {
            severity = .warning
        } else {
            severity = .success
        }

        return CalendarBulkOperationFeedback(
            message: parts.isEmpty ? "No sessions changed." : parts.joined(separator: " "),
            severity: severity,
            hasInvoicedSkips: skipped > 0,
            invoicedInvoiceIDs: invoicedInvoiceIDs,
            billingHubHandoffSessionIDs: billingHubHandoffSessionIDs,
            offersBillingHubPrepareStep: offersBillingHubPrepareStep
        )
    }
}

enum CalendarBulkDeleteConfirmationCopy {
    static func title(count: Int) -> String {
        count == 1 ? "Delete Selected Session?" : "Delete \(count) Selected Sessions?"
    }

    static func buttonTitle(count: Int) -> String {
        count == 1 ? "Delete Session" : "Delete \(count) Sessions"
    }

    static func message(count: Int, invoicedCount: Int) -> String {
        var parts = [
            count == 1
                ? "Deleted session cannot be recovered."
                : "Deleted sessions cannot be recovered."
        ]
        if invoicedCount > 0 {
            parts.append(
                invoicedCount == 1
                    ? "1 selected session is linked to an invoice and will be skipped."
                    : "\(invoicedCount) selected sessions are linked to invoices and will be skipped."
            )
        }
        return parts.joined(separator: " ")
    }
}
