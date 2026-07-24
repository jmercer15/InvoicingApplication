import Foundation

/// Shared currency-code contract for persisted invoices and invoice presentation.
public enum InvoiceCurrencyCode {
    public static let defaultValue = "AUD"

    public static func normalized(_ rawValue: String) -> String {
        rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    public static func isValid(_ rawValue: String) -> Bool {
        let code = normalized(rawValue)
        return code.unicodeScalars.count == 3 && code.unicodeScalars.allSatisfy {
            (65...90).contains(Int($0.value))
        }
    }

    public static func normalizedOrDefault(_ rawValue: String) -> String {
        let code = normalized(rawValue)
        return isValid(code) ? code : defaultValue
    }
}
