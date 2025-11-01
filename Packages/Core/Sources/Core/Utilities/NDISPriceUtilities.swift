import Foundation

/// Utilities for safely working with NDIS item prices
/// 
/// This utility provides safe access to NDIS item prices, handling cases where
/// the price might be nil due to missing regional price data.
public struct NDISPriceUtilities {
    
    // MARK: - Price Access
    
    /// Safely get the price from an NDIS item, with fallback options
    /// - Parameters:
    ///   - ndisItem: The NDIS item to get the price from
    ///   - fallbackPrice: The fallback price to use if the item's price is nil
    /// - Returns: The item's price or the fallback price
    public static func safePrice(from ndisItem: NDISItem, fallbackPrice: Double = 0.0) -> Double {
        return ndisItem.price ?? fallbackPrice
    }
    
    /// Get the price from an NDIS item with a specific fallback strategy
    /// - Parameters:
    ///   - ndisItem: The NDIS item to get the price from
    ///   - fallbackStrategy: The strategy to use when price is nil
    /// - Returns: The item's price or a calculated fallback
    public static func safePrice(from ndisItem: NDISItem, fallbackStrategy: PriceFallbackStrategy) -> Double {
        guard let price = ndisItem.price else {
            return calculateFallbackPrice(for: ndisItem, strategy: fallbackStrategy)
        }
        return price
    }
    
    /// Check if an NDIS item has a valid price
    /// - Parameter ndisItem: The NDIS item to check
    /// - Returns: True if the item has a non-nil price
    public static func hasValidPrice(_ ndisItem: NDISItem) -> Bool {
        return ndisItem.price != nil
    }
    
    /// Get the price with validation and error handling
    /// - Parameters:
    ///   - ndisItem: The NDIS item to get the price from
    ///   - context: The context for error reporting
    /// - Returns: A result containing the price or an error
    public static func validatedPrice(from ndisItem: NDISItem, context: String = "") -> Result<Double, NDISPriceError> {
        guard let price = ndisItem.price else {
            return .failure(.noPriceAvailable(itemNumber: ndisItem.itemNumber, context: context))
        }
        
        guard price >= 0 else {
            return .failure(.invalidPrice(price: price, itemNumber: ndisItem.itemNumber, context: context))
        }
        
        return .success(price)
    }
    
    // MARK: - Price Comparison
    
    /// Compare two NDIS items by price, handling nil values
    /// - Parameters:
    ///   - lhs: First NDIS item
    ///   - rhs: Second NDIS item
    ///   - nilPriceValue: Value to use for nil prices in comparison
    /// - Returns: Comparison result
    public static func compareByPrice(_ lhs: NDISItem, _ rhs: NDISItem, nilPriceValue: Double = 0.0) -> ComparisonResult {
        let leftPrice = lhs.price ?? nilPriceValue
        let rightPrice = rhs.price ?? nilPriceValue
        
        if leftPrice < rightPrice {
            return .orderedAscending
        } else if leftPrice > rightPrice {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
    
    /// Get the minimum price from an array of NDIS items
    /// - Parameters:
    ///   - items: Array of NDIS items
    ///   - includeNilPrices: Whether to include items with nil prices
    /// - Returns: The minimum price, or nil if no valid prices found
    public static func minimumPrice(from items: [NDISItem], includeNilPrices: Bool = false) -> Double? {
        let validPrices = items.compactMap { item in
            includeNilPrices ? (item.price ?? 0.0) : item.price
        }
        
        return validPrices.min()
    }
    
    /// Get the maximum price from an array of NDIS items
    /// - Parameters:
    ///   - items: Array of NDIS items
    ///   - includeNilPrices: Whether to include items with nil prices
    /// - Returns: The maximum price, or nil if no valid prices found
    public static func maximumPrice(from items: [NDISItem], includeNilPrices: Bool = false) -> Double? {
        let validPrices = items.compactMap { item in
            includeNilPrices ? (item.price ?? 0.0) : item.price
        }
        
        return validPrices.max()
    }
    
    // MARK: - Price Formatting
    
    /// Format a price for display, handling nil values
    /// - Parameters:
    ///   - price: The price to format
    ///   - currencyCode: The currency code (default: "AUD")
    ///   - nilDisplayText: Text to display when price is nil
    /// - Returns: Formatted price string
    public static func formatPrice(_ price: Double?, currencyCode: String = "AUD", nilDisplayText: String = "Price not available") -> String {
        guard let price = price else {
            return nilDisplayText
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSNumber(value: price)) ?? "\(currencyCode) \(String(format: "%.2f", price))"
    }
    
    /// Format a price range for display
    /// - Parameters:
    ///   - minPrice: Minimum price
    ///   - maxPrice: Maximum price
    ///   - currencyCode: The currency code (default: "AUD")
    /// - Returns: Formatted price range string
    public static func formatPriceRange(minPrice: Double?, maxPrice: Double?, currencyCode: String = "AUD") -> String {
        switch (minPrice, maxPrice) {
        case (nil, nil):
            return "Price not available"
        case (let min?, nil):
            return "From \(formatPrice(min, currencyCode: currencyCode))"
        case (nil, let max?):
            return "Up to \(formatPrice(max, currencyCode: currencyCode))"
        case (let min?, let max?) where min == max:
            return formatPrice(min, currencyCode: currencyCode)
        case (let min?, let max?):
            return "\(formatPrice(min, currencyCode: currencyCode)) - \(formatPrice(max, currencyCode: currencyCode))"
        }
    }
    
    // MARK: - Private Helpers
    
    private static func calculateFallbackPrice(for ndisItem: NDISItem, strategy: PriceFallbackStrategy) -> Double {
        switch strategy {
        case .zero:
            return 0.0
        case .average(let items):
            let validPrices = items.compactMap { $0.price }
            return validPrices.isEmpty ? 0.0 : validPrices.reduce(0, +) / Double(validPrices.count)
        case .median(let items):
            let validPrices = items.compactMap { $0.price }.sorted()
            guard !validPrices.isEmpty else { return 0.0 }
            let mid = validPrices.count / 2
            return validPrices.count % 2 == 0 ? (validPrices[mid - 1] + validPrices[mid]) / 2 : validPrices[mid]
        case .custom(let price):
            return price
        }
    }
}

// MARK: - Supporting Types

/// Fallback strategies for when NDIS item price is nil
public enum PriceFallbackStrategy {
    case zero
    case average([NDISItem])
    case median([NDISItem])
    case custom(Double)
}

/// Errors that can occur when working with NDIS prices
public enum NDISPriceError: Error, LocalizedError {
    case noPriceAvailable(itemNumber: String, context: String)
    case invalidPrice(price: Double, itemNumber: String, context: String)
    
    public var errorDescription: String? {
        switch self {
        case .noPriceAvailable(let itemNumber, let context):
            return "No price available for NDIS item \(itemNumber)\(context.isEmpty ? "" : " in \(context)")"
        case .invalidPrice(let price, let itemNumber, let context):
            return "Invalid price \(price) for NDIS item \(itemNumber)\(context.isEmpty ? "" : " in \(context)")"
        }
    }
}

// MARK: - Extensions

extension NDISItem {
    /// Safely get the price with a fallback
    /// - Parameter fallback: The fallback price to use if nil
    /// - Returns: The item's price or the fallback
    public func safePrice(fallback: Double = 0.0) -> Double {
        return NDISPriceUtilities.safePrice(from: self, fallbackPrice: fallback)
    }
    
    /// Check if this item has a valid price
    public var hasValidPrice: Bool {
        return NDISPriceUtilities.hasValidPrice(self)
    }
    
    /// Get formatted price string
    /// - Parameter currencyCode: The currency code (default: "AUD")
    /// - Returns: Formatted price string
    public func formattedPrice(currencyCode: String = "AUD") -> String {
        return NDISPriceUtilities.formatPrice(self.price, currencyCode: currencyCode)
    }
}
