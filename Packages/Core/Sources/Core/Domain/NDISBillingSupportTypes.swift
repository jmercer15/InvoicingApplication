import Foundation

public struct NDISServiceBooking: Sendable {
    public let isStatedItemInPlan: Bool
    public let price: Double

    public init(isStatedItemInPlan: Bool, price: Double) {
        self.isStatedItemInPlan = isStatedItemInPlan
        self.price = price
    }
}

public enum NDISBillingError: Error, LocalizedError, Sendable {
    case providerNotRegistered
    case supportItemNotFound
    case supportItemDeactivated
    case legacyServiceBookingRequired
    case noApprovedServiceBooking
    case agreedPriceExceedsLimit
    case invalidGroupSize
    case invalidPrice(String)
    /// Travel inputs / chargeAmount present but support item is not travel-eligible.
    case travelNotEligible(String)

    public var errorDescription: String? {
        switch self {
        case .providerNotRegistered:
            return "Provider is not registered for this claim path"
        case .supportItemNotFound:
            return "Support item not found"
        case .supportItemDeactivated:
            return "Support item is deactivated"
        case .legacyServiceBookingRequired:
            return "Legacy support item requires an active service booking"
        case .noApprovedServiceBooking:
            return "No approved service booking for quotable support"
        case .agreedPriceExceedsLimit:
            return "Agreed price exceeds the NDIS rate limit"
        case .invalidGroupSize:
            return "Invalid group size for group support loading"
        case .invalidPrice(let detail):
            return detail
        case .travelNotEligible(let detail):
            return detail
        }
    }
}
