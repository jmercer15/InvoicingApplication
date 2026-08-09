import Foundation

/// Controls PDF chrome for invoice vs receipt export without mutating persisted draft fields.
public enum InvoicePDFPresentation: Sendable, Equatable {
    case invoice
    case receipt(paymentSummary: String)

    public static func receiptSummary(paidDate: Date?, notes: String?) -> String {
        var lines: [String] = []
        if let paidDate {
            let paid = paidDate.formatted(.dateTime.day().month().year())
            lines.append("Paid on \(paid)")
        }
        let paymentLine = (notes ?? "")
            .components(separatedBy: .newlines)
            .first { $0.hasPrefix("Payment: ") }
        if let paymentLine, !paymentLine.isEmpty {
            lines.append(paymentLine)
        }
        return lines.joined(separator: "\n")
    }
}
