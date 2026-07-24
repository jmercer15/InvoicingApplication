import Foundation
import Core

/// Factory methods for creating entities from dictionary data.
struct AllDataFactories {
    
    // MARK: - Shared Helpers
    
    internal static func canonicalInvoiceStatusToken(_ rawStatus: String?) -> String? {
        guard let rawStatus else { return nil }
        let n = rawStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_")
        guard !n.isEmpty else { return nil }
        switch n {
        case "draft", "reviewdraft", "review_draft", "review_drafts": return InvoiceStatus.reviewDraft.rawValue
        case "readytosend", "ready_to_send":                          return InvoiceStatus.readyToSend.rawValue
        case "sent":                                                   return InvoiceStatus.pending.rawValue
        case "paid", "completed", "payment_received":                 return InvoiceStatus.received.rawValue
        case "pending":                                                return InvoiceStatus.pending.rawValue
        case "received":                                               return InvoiceStatus.received.rawValue
        case "overdue":                                                return InvoiceStatus.overdue.rawValue
        case "cancelled", "canceled":                                  return InvoiceStatus.cancelled.rawValue
        case "void", "voided":                                         return InvoiceStatus.voided.rawValue
        default:                                                        return n
        }
    }

    internal static func canonicalSessionStatusToken(_ rawStatus: String?) -> String? {
        guard let rawStatus else { return nil }
        let n = rawStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_")
        guard !n.isEmpty else { return nil }
        switch n {
        case "needs_services", "needsservice", "needstravel", "needs_travel", "add_travel": return SessionStatus.needsTravel.rawValue
        case "reviewdraft", "review_draft", "review_drafts":                                return SessionStatus.reviewDraft.rawValue
        case "readytosend", "ready_to_send":                                                return SessionStatus.readyToSend.rawValue
        case "noshow", "no_show":                                                           return SessionStatus.noShow.rawValue
        case "rescheduled":                                                                 return SessionStatus.rescheduled.rawValue
        case "scheduled":                                                                   return SessionStatus.scheduled.rawValue
        case "completed":                                                                   return SessionStatus.completed.rawValue
        case "grouped":                                                                     return SessionStatus.grouped.rawValue
        case "pending":                                                                     return SessionStatus.pending.rawValue
        case "received", "paid":                                                            return SessionStatus.received.rawValue
        case "cancelled", "canceled":                                                       return SessionStatus.cancelled.rawValue
        default:                                                                             return n
        }
    }
}
