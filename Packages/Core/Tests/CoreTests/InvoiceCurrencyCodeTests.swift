import XCTest
@testable import Core

final class InvoiceCurrencyCodeTests: XCTestCase {
    func testNormalizesWhitespaceAndCase() {
        XCTAssertEqual(InvoiceCurrencyCode.normalized("  aud\n"), "AUD")
    }

    func testValidationRequiresThreeASCIILetters() {
        XCTAssertTrue(InvoiceCurrencyCode.isValid("usd"))
        XCTAssertFalse(InvoiceCurrencyCode.isValid("US"))
        XCTAssertFalse(InvoiceCurrencyCode.isValid("12!"))
        XCTAssertFalse(InvoiceCurrencyCode.isValid("AÜD"))
    }

    func testInvalidValuesUseProductDefault() {
        XCTAssertEqual(InvoiceCurrencyCode.defaultValue, "AUD")
        XCTAssertEqual(InvoiceCurrencyCode.normalizedOrDefault(""), "AUD")
        XCTAssertEqual(InvoiceCurrencyCode.normalizedOrDefault("12!"), "AUD")
        XCTAssertEqual(InvoiceCurrencyCode.normalizedOrDefault(" usd "), "USD")
    }

    func testPersistedInvoiceDefaultMatchesSharedContract() {
        XCTAssertEqual(Invoice(invoiceNumber: "INV-001").currencyCode, InvoiceCurrencyCode.defaultValue)
    }
}
