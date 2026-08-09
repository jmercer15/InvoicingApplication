import Foundation

/// `Invoice` has no dedicated payment method/reference columns, so payment details are recorded as
/// a single tagged line inside `notes`. Re-recording a payment replaces the existing tagged line
/// instead of appending duplicates.
enum BillingHubPaymentNoteFormatter {
    private static let linePrefix = "Payment: "

    static func paymentLine(from notes: String?) -> String? {
        (notes ?? "")
            .components(separatedBy: .newlines)
            .first { $0.hasPrefix(linePrefix) }
    }

    /// Reads the amount produced by `applyingPaymentLine`. Notes authored outside the app simply
    /// return `nil`, leaving receipt presentation conservative instead of guessing.
    static func recordedAmount(from notes: String?) -> Double? {
        guard let line = paymentLine(from: notes) else { return nil }
        let amount = line
            .dropFirst(linePrefix.count)
            .components(separatedBy: " via ")
            .first ?? ""
        return BillingHubPaymentAmount.parsedValue(amount)
    }

    static func applyingPaymentLine(
        amount: String,
        date: Date,
        method: String,
        reference: String,
        to notes: String?
    ) -> String {
        let trimmedAmount = BillingHubPaymentAmount.currencyText(for: amount)
            ?? amount.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReference = reference
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let referenceSuffix = trimmedReference.isEmpty ? "" : " ref \(trimmedReference)"
        let dateText = date.formatted(.dateTime.day().month().year())
        let line = "\(linePrefix)\(trimmedAmount) via \(method) on \(dateText)\(referenceSuffix)"

        var lines = (notes ?? "").components(separatedBy: .newlines)
        if let index = lines.firstIndex(where: { $0.hasPrefix(linePrefix) }) {
            lines[index] = line
        } else if lines.count == 1, lines[0].isEmpty {
            lines = [line]
        } else {
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    /// Removes the tagged `Payment: …` line (if any), preserving other note lines.
    static func removingPaymentLine(from notes: String?) -> String? {
        guard let notes else { return nil }
        let cleaned = notes
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix(linePrefix) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}
