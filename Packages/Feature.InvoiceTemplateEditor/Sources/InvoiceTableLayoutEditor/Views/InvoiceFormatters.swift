import Core
import Foundation
import SharedUI

/// Formats monetary amounts as `$` + grouped value; omits decimal places for whole numbers.
enum InvoiceMoneyFormatter {
  private static let fractionDigits = 2

  private static let wholeNumberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 0
    formatter.usesGroupingSeparator = true
    return formatter
  }()

  private static let fractionalFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = fractionDigits
    formatter.maximumFractionDigits = fractionDigits
    formatter.usesGroupingSeparator = true
    return formatter
  }()

  static func rounded(_ amount: Decimal) -> Decimal {
    InvoiceCalculations.currencyRounded(amount)
  }

  private static func isWholeNumber(_ amount: Decimal) -> Bool {
    var value = amount
    var truncated = Decimal()
    NSDecimalRound(&truncated, &value, 0, .down)
    return amount == truncated
  }

  private static func numericString(for roundedAmount: Decimal) -> String {
    let formatter = isWholeNumber(roundedAmount) ? wholeNumberFormatter : fractionalFormatter
    let fallback = isWholeNumber(roundedAmount) ? "0" : "0.00"
    return formatter.string(from: NSDecimalNumber(decimal: roundedAmount)) ?? fallback
  }

  static func string(
    for amount: Decimal,
    currencyCode: String = InvoiceCurrencyCode.defaultValue,
    displayStyle: InvoiceCurrencyDisplayStyle = .default
  ) -> String {
    let roundedAmount = rounded(amount)
    let numeric = numericString(for: roundedAmount)
    let code = InvoiceCurrencyCode.normalizedOrDefault(currencyCode)

    switch displayStyle {
    case .symbol:
      if code == "USD" {
        return "$\(numeric)"
      }
      return currencyString(for: roundedAmount, currencyCode: code)
    case .code:
      return "\(code) \(numeric)"
    case .iso:
      return "\(numeric) \(code)"
    }
  }

  static func editablePrefix(
    currencyCode: String,
    displayStyle: InvoiceCurrencyDisplayStyle
  ) -> String? {
    switch displayStyle {
    case .symbol:
      currencySymbol(for: currencyCode)
    case .code:
      InvoiceCurrencyCode.normalizedOrDefault(currencyCode)
    case .iso:
      nil
    }
  }

  static func editableSuffix(
    currencyCode: String,
    displayStyle: InvoiceCurrencyDisplayStyle
  ) -> String? {
    displayStyle == .iso ? InvoiceCurrencyCode.normalizedOrDefault(currencyCode) : nil
  }

  private static func currencySymbol(for currencyCode: String) -> String {
    CurrencyFormatting.symbol(for: currencyCode)
  }

  private static func currencyString(for roundedAmount: Decimal, currencyCode: String) -> String {
    CurrencyFormatting.display(roundedAmount, code: currencyCode, omitFractionIfWhole: true)
  }

  /// Numeric portion for editable money fields; `$` is shown as a separate prefix.
  static func editableString(for amount: Decimal) -> String {
    numericString(for: rounded(amount))
  }
}

/// Display string for non-monetary decimal fields (quantity, percentages).
enum InvoiceDecimalFormatter {
  static func string(for value: Decimal, locale: Locale = .current) -> String {
    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 16
    return formatter.string(from: NSDecimalNumber(decimal: value))
      ?? NSDecimalNumber(decimal: value).stringValue
  }
}

enum InvoiceDateFormatter {
  /// Display string for document metadata and line-item date columns.
  static func documentString(for date: Date, style: InvoiceDateFormatStyle) -> String {
    switch style {
    case .medium: DateFormatting.mediumDate(date)
    case .short: DateFormatting.shortDate(date)
    case .long: DateFormatting.longDate(date)
    }
  }
}
