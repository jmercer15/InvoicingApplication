import SwiftUI
import SharedUI

/// In-flight n-of-m progress for Billing Hub bulk board actions.
public struct BillingHubBulkActionProgress: Equatable, Sendable {
    public let action: String
    public let completedCount: Int
    public let totalCount: Int

    public init(action: String, completedCount: Int, totalCount: Int) {
        self.action = action
        self.completedCount = completedCount
        self.totalCount = totalCount
    }

    public var message: String {
        guard totalCount > 0 else { return action }
        return "\(action) \(completedCount) of \(totalCount)"
    }

    public var fractionCompleted: Double {
        guard totalCount > 0 else { return 0 }
        return min(max(Double(completedCount) / Double(totalCount), 0), 1)
    }
}

/// Visual severity for the Billing Hub toolbar feedback pill. Derived from message copy so
/// existing `bulkActionFeedback = "…"` call sites stay string-based.
enum BillingHubBulkFeedbackSeverity: Equatable {
    case success
    case warning
    case error

    var symbolName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: return BillingHubTheme.Columns.payment
        case .warning: return Color.orange
        case .error: return Color.red
        }
    }

    /// Classifies Hub feedback strings by common failure / partial-success phrasing.
    static func classify(_ message: String) -> BillingHubBulkFeedbackSeverity {
        let lower = message.lowercased()
        // Partial success / caution before generic failure phrases ("could not" also appears in
        // "sent, but the status could not be updated").
        if lower.contains("blocked")
            || lower.contains("partial")
            || lower.contains("warning")
            || lower.contains("status unchanged")
            || lower.contains("status remains ready to send")
            || lower.contains("marked for changes")
            || lower.contains("but the status")
            || lower.contains("differs")
            || lower.contains("mismatch")
            || lower.contains("partial payment")
            || lower.contains("outstanding")
            || lower.contains("overpayment")
            || lower.contains("cancelled")
            || lower.contains("already in progress")
        {
            return .warning
        }
        if lower.contains("could not")
            || lower.contains("failed")
            || lower.contains("no email")
            || lower.contains("add at least")
            || lower.contains("add a recipient")
            || lower.contains("no draft")
            || lower.contains("no completed")
            || lower.contains("no sessions")
            || lower.contains("invalid email")
        {
            return .error
        }
        return .success
    }
}

/// In-panel operation result row (send / payment / receipt feedback).
struct BillingHubOperationFeedbackSection: View {
    let message: String

    var body: some View {
        let severity = BillingHubBulkFeedbackSeverity.classify(message)
        Section {
            Label(message, systemImage: severity.symbolName)
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(severity.tint)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}

/// Feedback when queued Calendar/Invoices focus ids are absent after a Hub projection refresh.
enum BillingHubFocusMissFeedback {
    static func message(hasActiveFilters: Bool) -> String {
        if hasActiveFilters {
            return "Could not find that item on the board. Try Clear filters."
        }
        return "Could not find that item on the board."
    }
}

enum BillingHubInvoiceEmailPrefill {
    /// Prefer bill-to (accounts) email when present; fall back to client email.
    static func preferredRecipient(billToEmail: String?, clientEmail: String?) -> String? {
        let candidates = [billToEmail, clientEmail]
        for candidate in candidates {
            guard let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else { continue }
            return trimmed
        }
        return nil
    }
}
