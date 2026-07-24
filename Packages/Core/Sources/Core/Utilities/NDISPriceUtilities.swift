import Foundation


/// Utility methods for working with NDIS price data on NDISItem entities.
/// Provides consistent, null-safe access to PACE and legacy price fields.
public struct NDISPriceUtilities {

    // MARK: - Safe Price Retrieval

    /// Returns the effective price for an NDIS item, with a fallback if the primary price is nil.
    public static func safePrice(from item: NDISItem, fallbackPrice: Decimal? = nil) -> Decimal? {
        if let p = item.price { return Decimal(p) }
        return fallbackPrice
    }

    /// Returns true if the item has a non-nil, positive price.
    public static func hasValidPrice(_ item: NDISItem) -> Bool {
        guard let price = item.price else { return false }
        return price > 0
    }

    /// Returns the item's price after validation, throwing if the price is invalid.
    public static func validatedPrice(from item: NDISItem, context: String = "") throws -> Decimal {
        guard let p = item.price else {
            throw NDISPriceError.missingPrice(itemNumber: item.itemNumber, context: context)
        }
        let price = Decimal(p)
        guard price > 0 else {
            throw NDISPriceError.invalidPrice(itemNumber: item.itemNumber, price: price, context: context)
        }
        return price
    }

    /// Returns the item's raw price without validation; may be nil.
    ///
    /// - Note: Prefer `safePrice(from:fallbackPrice:)` for most use cases.
    public static func validatedPrice(from item: NDISItem) -> Decimal? {
        if let p = item.price { return Decimal(p) }
        return nil
    }

    // MARK: - Comparison

    /// Compares two items by their price.
    /// Returns `ComparisonResult.orderedAscending`, `.orderedSame`, or `.orderedDescending`.
    public static func compareByPrice(_ lhs: NDISItem, _ rhs: NDISItem, nilPriceValue: Decimal = 0) -> ComparisonResult {
        let lhsPrice = lhs.price.map { Decimal($0) } ?? nilPriceValue
        let rhsPrice = rhs.price.map { Decimal($0) } ?? nilPriceValue

        if lhsPrice < rhsPrice { return .orderedAscending }
        if lhsPrice > rhsPrice { return .orderedDescending }
        return .orderedSame
    }

    // MARK: - Aggregation

    /// Returns the minimum price across an array of items, excluding or including nil prices.
    public static func minimumPrice(from items: [NDISItem], includeNilPrices: Bool = false) -> Decimal? {
        let prices = items.compactMap { item -> Decimal? in
            guard includeNilPrices || item.price != nil else { return nil }
            if let p = item.price { return Decimal(p) }
            return includeNilPrices ? 0 : nil
        }
        return prices.min()
    }

    /// Returns the maximum price across an array of items, excluding or including nil prices.
    public static func maximumPrice(from items: [NDISItem], includeNilPrices: Bool = false) -> Decimal? {
        let prices = items.compactMap { item -> Decimal? in
            guard includeNilPrices || item.price != nil else { return nil }
            if let p = item.price { return Decimal(p) }
            return includeNilPrices ? 0 : nil
        }
        return prices.max()
    }

    // MARK: - Formatting

    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    /// Formats a Decimal price as an Australian dollar string.
    public static func formatPrice(_ price: Decimal) -> String {
        return priceFormatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }

    /// Formats a price range as a string.
    public static func formatPriceRange(minPrice: Decimal?, maxPrice: Decimal?) -> String {
        switch (minPrice, maxPrice) {
        case (nil, nil):
            return "Price not available"
        case (let min?, nil):
            return "From \(formatPrice(min))"
        case (nil, let max?):
            return "Up to \(formatPrice(max))"
        case (let min?, let max?) where min == max:
            return formatPrice(min)
        case (let min?, let max?):
            return "\(formatPrice(min)) – \(formatPrice(max))"
        }
    }
}

// MARK: - Price Fallback Strategy

/// Describes how to handle items with missing prices.
public enum PriceFallbackStrategy {
    /// Use zero as the fallback price.
    case useZero
    /// Use a specific decimal value.
    case useValue(Decimal)
    /// Throw an error when price is missing.
    case throwError
    /// Skip the item.
    case skip
}

// MARK: - Errors

public enum NDISPriceError: Error, LocalizedError {
    case missingPrice(itemNumber: String, context: String)
    case invalidPrice(itemNumber: String, price: Decimal, context: String)

    public var errorDescription: String? {
        switch self {
        case .missingPrice(let itemNumber, let context):
            return "NDIS item \(itemNumber) has no price\(context.isEmpty ? "" : " (context: \(context))")."
        case .invalidPrice(let itemNumber, let price, let context):
            return "NDIS item \(itemNumber) has an invalid price \(price)\(context.isEmpty ? "" : " (context: \(context))")."
        }
    }
}

// MARK: - NDISItem Extension

public extension NDISItem {
    /// Convenience accessor using PriceFallbackStrategy.
    func resolvedPrice(strategy: PriceFallbackStrategy) throws -> Decimal? {
        let decimalPrice = price.map { Decimal($0) }
        switch strategy {
        case .useZero:
            return decimalPrice ?? 0
        case .useValue(let fallback):
            return decimalPrice ?? fallback
        case .throwError:
            return try NDISPriceUtilities.validatedPrice(from: self, context: "")
        case .skip:
            return decimalPrice
        }
    }
}
