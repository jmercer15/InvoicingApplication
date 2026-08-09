import Foundation
import Core

public enum BillingTransitionRules {
    public static func isValidSessionTransition(from: BillingStatus, to: BillingStatus) -> Bool {
        switch (from, to) {
        case (.completed, .grouped), (.completed, .addTravel): return true
        case (.grouped, .completed): return true
        case (.addTravel, .completed): return true
        case (.grouped, .grouped): return true // Peer reorder within Grouped (positions unused today)
        default: return from == to
        }
    }

    public static func isValidInvoiceTransition(from: BillingStatus, to: BillingStatus) -> Bool {
        switch (from, to) {
        case (.reviewDrafts, .readyToSend): return true
        case (.readyToSend, .pending): return true
        case (.pending, .received): return true
        // Allow moving back
        case (.readyToSend, .reviewDrafts): return true
        case (.pending, .readyToSend): return true
        case (.received, .pending): return true
        default: return from == to
        }
    }

    public static func isForwardInvoiceTransition(from: String, to: String) -> Bool {
        let order: [String] = ["review_draft", "ready_to_send", "pending", "received"]
        guard let fromIndex = order.firstIndex(of: from),
              let toIndex = order.firstIndex(of: to) else { return false }
        return toIndex > fromIndex
    }

    public static func requiresDateClearing(to status: BillingStatus) -> (clearSentDate: Bool, clearPaidDate: Bool) {
        switch status {
        case .reviewDrafts, .readyToSend:
            return (true, true)
        case .pending:
            return (false, true)
        default:
            return (false, false)
        }
    }
}
