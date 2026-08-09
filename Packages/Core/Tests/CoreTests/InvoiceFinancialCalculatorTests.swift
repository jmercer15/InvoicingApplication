import Core
import Testing
@Suite struct InvoiceFinancialCalculatorTests {
    @Test func MixedLineTaxPercentageDiscountAndCreditUseCanonicalRounding() {
        let totals = InvoiceFinancialCalculator.calculate(
            lineItems: [
                .init(quantity: 2, unitPrice: 100, taxRate: 10),
                .init(quantity: 1, unitPrice: 50, taxRate: 0)
            ],
            percentageDiscount: 10,
            creditApplied: 5
        )

        #expect(totals.subtotal == 250)
        #expect(totals.discount == 25)
        #expect(totals.taxTotal == 18)
        #expect(totals.grandTotal == 238)
    }

    @Test func FixedDiscountIsCappedAndGrandTotalCannotBecomeNegative() {
        let totals = InvoiceFinancialCalculator.calculate(
            lineItems: [.init(quantity: 1, unitPrice: 10, taxRate: 10)],
            fixedDiscount: 100,
            creditApplied: 100
        )

        #expect(totals.discount == 10)
        #expect(totals.taxTotal == 0)
        #expect(totals.grandTotal == 0)
    }
}
