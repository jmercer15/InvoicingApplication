import Foundation

/// Canonical invoice money calculation shared by persistence, workflows, and editor UI.
public enum InvoiceFinancialCalculator {
    public struct LineItem: Sendable, Equatable {
        public let quantity: Decimal
        public let unitPrice: Decimal
        public let taxRate: Decimal

        public init(quantity: Decimal, unitPrice: Decimal, taxRate: Decimal) {
            self.quantity = quantity
            self.unitPrice = unitPrice
            self.taxRate = taxRate
        }
    }

    public struct Totals: Sendable, Equatable {
        public let subtotal: Decimal
        public let discount: Decimal
        public let taxTotal: Decimal
        public let creditApplied: Decimal
        public let grandTotal: Decimal

        public init(
            subtotal: Decimal,
            discount: Decimal,
            taxTotal: Decimal,
            creditApplied: Decimal,
            grandTotal: Decimal
        ) {
            self.subtotal = subtotal
            self.discount = discount
            self.taxTotal = taxTotal
            self.creditApplied = creditApplied
            self.grandTotal = grandTotal
        }
    }

    public static func currencyRounded(_ amount: Decimal) -> Decimal {
        var value = amount
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .plain)
        return result
    }

    public static func lineSubtotal(quantity: Decimal, unitPrice: Decimal) -> Decimal {
        currencyRounded(quantity * unitPrice)
    }

    public static func lineTax(subtotal: Decimal, taxRate: Decimal) -> Decimal {
        currencyRounded(subtotal * taxRate / 100)
    }

    public static func lineTotal(subtotal: Decimal, taxRate: Decimal) -> Decimal {
        currencyRounded(subtotal + lineTax(subtotal: subtotal, taxRate: taxRate))
    }

    public static func calculate(
        lineItems: [LineItem],
        fixedDiscount: Decimal = 0,
        percentageDiscount: Decimal = 0,
        creditApplied: Decimal = 0
    ) -> Totals {
        var subtotal: Decimal = 0
        var taxTotal: Decimal = 0

        for item in lineItems {
            let lineSubtotal = lineSubtotal(
                quantity: item.quantity,
                unitPrice: item.unitPrice
            )
            subtotal += lineSubtotal
            taxTotal += lineTax(subtotal: lineSubtotal, taxRate: item.taxRate)
        }

        subtotal = currencyRounded(subtotal)
        let discount = discountValue(
            subtotal: subtotal,
            fixedDiscount: fixedDiscount,
            percentageDiscount: percentageDiscount
        )
        let discountedSubtotal = currencyRounded(max(0, subtotal - discount))
        let discountRatio = subtotal > 0 ? discountedSubtotal / subtotal : 1
        let adjustedTax = currencyRounded(taxTotal * discountRatio)
        let normalizedCredit = currencyRounded(max(0, creditApplied))
        let grandTotal = currencyRounded(
            max(0, discountedSubtotal + adjustedTax - normalizedCredit)
        )

        return Totals(
            subtotal: subtotal,
            discount: discount,
            taxTotal: adjustedTax,
            creditApplied: normalizedCredit,
            grandTotal: grandTotal
        )
    }

    public static func discountValue(
        subtotal: Decimal,
        fixedDiscount: Decimal,
        percentageDiscount: Decimal
    ) -> Decimal {
        let nonNegativeSubtotal = max(0, subtotal)
        if percentageDiscount > 0 {
            let value = currencyRounded(nonNegativeSubtotal * percentageDiscount / 100)
            return min(nonNegativeSubtotal, value)
        }
        return min(nonNegativeSubtotal, currencyRounded(max(0, fixedDiscount)))
    }
}
