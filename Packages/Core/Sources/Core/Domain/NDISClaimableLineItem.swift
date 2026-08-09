import Foundation

/// A single claimable line item for NDIS billing.
public struct NDISClaimableLineItem: Sendable {
    public let supportItemNumber: String
    public let quantity: Decimal
    public let unitPrice: Decimal
    public let totalAmount: Decimal
    public let claimType: String

    public init(
        supportItemNumber: String,
        quantity: Decimal,
        unitPrice: Decimal,
        totalAmount: Decimal,
        claimType: String
    ) {
        self.supportItemNumber = supportItemNumber
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalAmount = totalAmount
        self.claimType = claimType
    }

    /// Computed convenience property.
    public var lineTotal: Decimal {
        quantity * unitPrice
    }
}
