import Foundation

public struct NDISServiceBooking: Sendable {
    public let isStatedItemInPlan: Bool
    public let price: Double

    public init(isStatedItemInPlan: Bool, price: Double) {
        self.isStatedItemInPlan = isStatedItemInPlan
        self.price = price
    }
}

public enum NDISBillingError: Error, Sendable {
    case providerNotRegistered
    case supportItemNotFound
    case supportItemDeactivated
    case legacyServiceBookingRequired
    case noApprovedServiceBooking
    case agreedPriceExceedsLimit
    case invalidGroupSize
    case invalidPrice(String)
}
