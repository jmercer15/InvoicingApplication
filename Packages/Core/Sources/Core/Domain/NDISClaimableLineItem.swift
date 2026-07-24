import Foundation

/// A single claimable line item for NDIS billing.
public struct NDISClaimableLineItem: Sendable {
    public let supportItemNumber: String
    public let quantity: Double
    public let unitPrice: Double
    public let totalAmount: Double
    public let claimType: String

    public init(
        supportItemNumber: String,
        quantity: Double,
        unitPrice: Double,
        totalAmount: Double,
        claimType: String
    ) {
        self.supportItemNumber = supportItemNumber
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalAmount = totalAmount
        self.claimType = claimType
    }

    /// Computed convenience property.
    public var lineTotal: Double {
        quantity * unitPrice
    }
}
