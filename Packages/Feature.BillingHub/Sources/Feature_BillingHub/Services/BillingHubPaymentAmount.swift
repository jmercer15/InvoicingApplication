import Foundation

/// Validates free-form payment amount strings entered in the Pending / Sent payment panel.
enum BillingHubPaymentAmount {
    enum Comparison: Equatable {
        case matches
        case underpayment(Double)
        case overpayment(Double)

        var isMismatch: Bool {
            self != .matches
        }
    }

    struct MismatchConfirmation: Equatable {
        let title: String
        let buttonTitle: String
        let message: String
    }

    /// Accepts positive plain or pasted AUD currency values, including grouping separators.
    static func isValid(_ raw: String) -> Bool {
        parsedValue(raw).map { $0 > 0 } ?? false
    }

    static func parsedValue(_ raw: String) -> Double? {
        var normalized = raw
            .uppercased()
            .replacingOccurrences(of: "AUD", with: "")
            .replacingOccurrences(of: "$", with: "")
            .filter { !$0.isWhitespace && $0 != "\u{00A0}" }
        guard !normalized.isEmpty,
              normalized.allSatisfy({ $0.isNumber || ".,+-".contains($0) })
        else { return nil }

        let commaCount = normalized.filter { $0 == "," }.count
        let dotCount = normalized.filter { $0 == "." }.count
        if commaCount > 0, dotCount > 0 {
            let commaIndex = normalized.lastIndex(of: ",")!
            let dotIndex = normalized.lastIndex(of: ".")!
            let decimalSeparator: Character = commaIndex > dotIndex ? "," : "."
            let groupingSeparator: Character = decimalSeparator == "," ? "." : ","
            normalized.removeAll { $0 == groupingSeparator }
            if decimalSeparator == "," {
                normalized = normalized.replacingOccurrences(of: ",", with: ".")
            }
        } else if commaCount > 0 {
            let groups = normalized.split(separator: ",", omittingEmptySubsequences: false)
            if groups.count > 1,
               groups.dropFirst().allSatisfy({ $0.count == 3 }) {
                normalized.removeAll { $0 == "," }
            } else {
                guard commaCount == 1 else { return nil }
                normalized = normalized.replacingOccurrences(of: ",", with: ".")
            }
        } else if dotCount > 1 {
            return nil
        }

        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    static func comparison(
        entered: String,
        invoiceTotal: Double,
        tolerance: Double = 0.01
    ) -> Comparison? {
        guard let value = parsedValue(entered) else { return nil }
        let difference = value - invoiceTotal
        if abs(difference) <= tolerance {
            return .matches
        }
        return difference < 0
            ? .underpayment(abs(difference))
            : .overpayment(difference)
    }

    static func mismatchWarning(entered: String, invoiceTotal: Double, tolerance: Double = 0.01) -> String? {
        guard let comparison = comparison(
            entered: entered,
            invoiceTotal: invoiceTotal,
            tolerance: tolerance
        ) else { return nil }
        switch comparison {
        case .matches:
            return nil
        case .underpayment(let difference):
            return "Partial payment — \(currencyText(difference)) remains outstanding."
        case .overpayment(let difference):
            return "Overpayment — \(currencyText(difference)) exceeds the invoice total."
        }
    }

    static func mismatchConfirmation(
        entered: String,
        invoiceTotal: Double
    ) -> MismatchConfirmation? {
        guard let amount = parsedValue(entered),
              let comparison = comparison(entered: entered, invoiceTotal: invoiceTotal)
        else { return nil }
        let amountText = currencyText(amount)
        let totalText = currencyText(invoiceTotal)
        switch comparison {
        case .matches:
            return nil
        case .underpayment(let difference):
            return MismatchConfirmation(
                title: "Record Partial Payment?",
                buttonTitle: "Record Partial Payment",
                message: "Record \(amountText) against invoice total \(totalText), leaving \(currencyText(difference)) outstanding, and move this invoice to Payment Received?"
            )
        case .overpayment(let difference):
            return MismatchConfirmation(
                title: "Record Overpayment?",
                buttonTitle: "Record Overpayment",
                message: "Record \(amountText) against invoice total \(totalText), including \(currencyText(difference)) overpayment, and move this invoice to Payment Received?"
            )
        }
    }

    static func currencyText(_ value: Double) -> String {
        value.formatted(
            .currency(code: "AUD")
                .locale(Locale(identifier: "en_AU"))
        )
    }

    static func currencyText(for raw: String) -> String? {
        parsedValue(raw).map(currencyText)
    }
}
