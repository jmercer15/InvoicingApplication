import Foundation
import Core

extension InvoiceImport {
    
    internal static func parseInvoiceStatus(_ status: String?, invoiceNumber: String) throws -> InvoiceStatus {
        guard let token = canonicalInvoiceStatusToken(status) else { return .reviewDraft }
        guard let parsedStatus = InvoiceStatus(rawValue: token) else {
            throw NSError(
                domain: "InvoiceImportError",
                code: 1003,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invoice \(invoiceNumber) has unsupported status '\(status ?? "")'."
                ]
            )
        }
        return parsedStatus
    }

    internal static func canonicalInvoiceStatusToken(_ rawStatus: String?) -> String? {
        guard let rawStatus else { return nil }
        let normalized = rawStatus
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        guard !normalized.isEmpty else { return nil }

        switch normalized {
        case "draft", "reviewdraft", "review_draft", "review_drafts":
            return InvoiceStatus.reviewDraft.rawValue
        case "readytosend", "ready_to_send":
            return InvoiceStatus.readyToSend.rawValue
        case "sent":
            return InvoiceStatus.pending.rawValue
        case "paid", "completed", "payment_received":
            return InvoiceStatus.received.rawValue
        case "pending":
            return InvoiceStatus.pending.rawValue
        case "received":
            return InvoiceStatus.received.rawValue
        case "overdue":
            return InvoiceStatus.overdue.rawValue
        case "cancelled", "canceled":
            return InvoiceStatus.cancelled.rawValue
        case "void", "voided":
            return InvoiceStatus.voided.rawValue
        default:
            return normalized
        }
    }
}
