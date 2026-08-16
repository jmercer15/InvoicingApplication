import Foundation
import SwiftUI

public enum ValidatedDecimalParseResult<T: Equatable>: Equatable, Sendable where T: Sendable {
    case empty
    case value(T)
    case invalid
}

public struct ValidatedDecimalParser: Sendable {
    public struct FormatOptions: Sendable {
        public let minimumFractionDigits: Int?
        public let maximumFractionDigits: Int?
        public let generatesDecimalNumbers: Bool

        public init(
            minimumFractionDigits: Int? = nil,
            maximumFractionDigits: Int? = nil,
            generatesDecimalNumbers: Bool = false
        ) {
            self.minimumFractionDigits = minimumFractionDigits
            self.maximumFractionDigits = maximumFractionDigits
            self.generatesDecimalNumbers = generatesDecimalNumbers
        }

        public static let decimal = FormatOptions(generatesDecimalNumbers: true)
        public static let double = FormatOptions(minimumFractionDigits: 0, maximumFractionDigits: 2, generatesDecimalNumbers: false)
    }

    private static func parseStrict(
        _ text: String,
        locale: Locale,
        options: FormatOptions
    ) -> NSNumber? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.isLenient = false
        formatter.usesGroupingSeparator = true
        formatter.generatesDecimalNumbers = options.generatesDecimalNumbers
        if let min = options.minimumFractionDigits {
            formatter.minimumFractionDigits = min
        }
        if let max = options.maximumFractionDigits {
            formatter.maximumFractionDigits = max
        }

        var value: AnyObject?
        var consumedRange = NSRange(location: 0, length: (text as NSString).length)

        do {
            try formatter.getObjectValue(&value, for: text, range: &consumedRange)
        } catch {
            return nil
        }

        guard consumedRange.location == 0,
              consumedRange.length == (text as NSString).length,
              let number = value as? NSNumber else {
            return nil
        }
        return number
    }

    public static func parseNumber(
        _ text: String,
        locale: Locale = .current,
        options: FormatOptions = .decimal
    ) -> NSNumber? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let number = parseStrict(trimmed, locale: locale, options: options) {
            return number
        }

        let decimalSeparator = locale.decimalSeparator ?? "."
        guard decimalSeparator != ".",
              trimmed.range(of: #"^\d+\.\d+$"#, options: .regularExpression) != nil else {
            return nil
        }
        return parseStrict(trimmed, locale: Locale(identifier: "en_US_POSIX"), options: options)
    }

    public static func parseDecimal(
        _ text: String,
        locale: Locale = .current
    ) -> Decimal? {
        parseNumber(text, locale: locale, options: .decimal)?.decimalValue
    }

    public static func string(
        for decimal: Decimal,
        locale: Locale = .current
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true
        formatter.isLenient = false
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSDecimalNumber(decimal: decimal))
            ?? NSDecimalNumber(decimal: decimal).stringValue
    }

    public static func parseDouble(
        _ text: String,
        in range: ClosedRange<Double>? = nil,
        locale: Locale = .current
    ) -> Double? {
        guard let number = parseNumber(text, locale: locale, options: .double) else { return nil }
        let dVal = number.doubleValue
        guard dVal.isFinite else { return nil }
        if let range = range {
            guard range.contains(dVal) else { return nil }
        }
        return dVal
    }

    public static func string(
        for double: Double,
        locale: Locale = .current
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.isLenient = false
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: double)) ?? String(double)
    }

    public static func parseFilterAmount(
        _ text: String,
        locale: Locale = .current
    ) -> ValidatedDecimalParseResult<Double> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        guard let value = parseDouble(trimmed, locale: locale), value >= 0 else {
            return .invalid
        }
        return .value(value)
    }
}
