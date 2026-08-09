import Foundation

/// Converts legacy JSON/CSV double money tokens into persisted `Decimal` values.
public enum MoneyDecimalImport {
    public static func decimal(from value: Double) -> Decimal {
        Decimal(value)
    }

    public static func decimal(from value: Double?) -> Decimal? {
        guard let value else { return nil }
        return Decimal(value)
    }
}
