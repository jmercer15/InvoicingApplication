import Core
import XCTest

final class InvoiceFinancialCalculatorTests: XCTestCase {
    func testMixedLineTaxPercentageDiscountAndCreditUseCanonicalRounding() {
        let totals = InvoiceFinancialCalculator.calculate(
            lineItems: [
                .init(quantity: 2, unitPrice: 100, taxRate: 10),
                .init(quantity: 1, unitPrice: 50, taxRate: 0)
            ],
            percentageDiscount: 10,
            creditApplied: 5
        )

        XCTAssertEqual(totals.subtotal, 250)
        XCTAssertEqual(totals.discount, 25)
        XCTAssertEqual(totals.taxTotal, 18)
        XCTAssertEqual(totals.grandTotal, 238)
    }

    func testFixedDiscountIsCappedAndGrandTotalCannotBecomeNegative() {
        let totals = InvoiceFinancialCalculator.calculate(
            lineItems: [.init(quantity: 1, unitPrice: 10, taxRate: 10)],
            fixedDiscount: 100,
            creditApplied: 100
        )

        XCTAssertEqual(totals.discount, 10)
        XCTAssertEqual(totals.taxTotal, 0)
        XCTAssertEqual(totals.grandTotal, 0)
    }
}
