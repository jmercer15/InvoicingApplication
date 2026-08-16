import Foundation

/// Stateless rules for resolving, validating, comparing, and aggregating NDIS prices.
///
/// This type accepts price values rather than persistence entities so pricing rules remain
/// reusable by import, persistence, and presentation adapters.
public enum NDISPriceUtilities {
    /// Returns `price` when present; otherwise returns `fallbackPrice`.
    public static func price(
        resolving price: Decimal?,
        fallback fallbackPrice: Decimal? = nil
    ) -> Decimal? {
        price ?? fallbackPrice
    }

    /// Returns whether `price` is present and greater than zero.
    public static func hasValidPrice(_ price: Decimal?) -> Bool {
        guard let price else { return false }
        return price > 0
    }

    /// Returns a positive price or throws an error describing its invalid state.
    ///
    /// - Parameters:
    ///   - price: Price value being validated.
    ///   - itemNumber: NDIS support item number used for error context.
    ///   - context: Optional operation context used for error context.
    public static func validatedPrice(
        _ price: Decimal?,
        itemNumber: String,
        context: String = ""
    ) throws -> Decimal {
        guard let price else {
            throw NDISPriceError.missingPrice(itemNumber: itemNumber, context: context)
        }
        guard price > 0 else {
            throw NDISPriceError.invalidPrice(itemNumber: itemNumber, price: price, context: context)
        }
        return price
    }

    /// Compares two optional prices after replacing nil values with `nilPriceValue`.
    public static func compare(
        _ lhs: Decimal?,
        to rhs: Decimal?,
        nilPriceValue: Decimal = 0
    ) -> ComparisonResult {
        let lhsPrice = lhs ?? nilPriceValue
        let rhsPrice = rhs ?? nilPriceValue

        if lhsPrice < rhsPrice { return .orderedAscending }
        if lhsPrice > rhsPrice { return .orderedDescending }
        return .orderedSame
    }

    /// Returns lowest price, optionally treating nil values as zero.
    public static func minimumPrice(
        in prices: [Decimal?],
        includingNilPrices: Bool = false
    ) -> Decimal? {
        normalized(prices, includingNilPrices: includingNilPrices).min()
    }

    /// Returns highest price, optionally treating nil values as zero.
    public static func maximumPrice(
        in prices: [Decimal?],
        includingNilPrices: Bool = false
    ) -> Decimal? {
        normalized(prices, includingNilPrices: includingNilPrices).max()
    }

    /// Resolves a price according to `strategy`.
    ///
    /// - Throws: ``NDISPriceError/missingPrice(itemNumber:context:)`` or
    ///   ``NDISPriceError/invalidPrice(itemNumber:price:context:)`` when `strategy` is `.throwError`.
    public static func resolvedPrice(
        from price: Decimal?,
        using strategy: PriceFallbackStrategy,
        itemNumber: String,
        context: String = ""
    ) throws -> Decimal? {
        switch strategy {
        case .useZero:
            price ?? 0
        case .useValue(let fallback):
            price ?? fallback
        case .throwError:
            try validatedPrice(price, itemNumber: itemNumber, context: context)
        case .skip:
            price
        }
    }

    private static func normalized(
        _ prices: [Decimal?],
        includingNilPrices: Bool
    ) -> [Decimal] {
        prices.compactMap { price in
            price ?? (includingNilPrices ? 0 : nil)
        }
    }
}

/// Strategy used when an NDIS price is unavailable.
public enum PriceFallbackStrategy: Equatable, Sendable {
    /// Replaces a missing price with zero.
    case useZero
    /// Replaces a missing price with specified value.
    case useValue(Decimal)
    /// Rejects missing and non-positive prices.
    case throwError
    /// Leaves a missing price unresolved.
    case skip
}

/// Errors produced by NDIS price validation.
public enum NDISPriceError: Error, Equatable, LocalizedError, Sendable {
    /// Price was not supplied for given support item.
    case missingPrice(itemNumber: String, context: String)
    /// Price was not positive for given support item.
    case invalidPrice(itemNumber: String, price: Decimal, context: String)

    /// Localized description for display by an outer presentation layer.
    public var errorDescription: String? {
        switch self {
        case .missingPrice(let itemNumber, let context):
            return "NDIS item \(itemNumber) has no price\(context.isEmpty ? "" : " (context: \(context))")."
        case .invalidPrice(let itemNumber, let price, let context):
            return "NDIS item \(itemNumber) has an invalid price \(price)\(context.isEmpty ? "" : " (context: \(context))")."
        }
    }
}
