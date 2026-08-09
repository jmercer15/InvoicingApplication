import Foundation
import Testing
@testable import Core

@Suite struct InvoiceCurrencyCodeTests {
    @Test func NormalizesWhitespaceAndCase() {
        #expect(InvoiceCurrencyCode.normalized("  aud\n") == "AUD")
    }

    @Test func ValidationRequiresThreeASCIILetters() {
        #expect(InvoiceCurrencyCode.isValid("usd"))
        #expect(!(InvoiceCurrencyCode.isValid("US")))
        #expect(!(InvoiceCurrencyCode.isValid("12!")))
        #expect(!(InvoiceCurrencyCode.isValid("AÜD")))
    }

    @Test func InvalidValuesUseProductDefault() {
        #expect(InvoiceCurrencyCode.defaultValue == "AUD")
        #expect(InvoiceCurrencyCode.normalizedOrDefault("") == "AUD")
        #expect(InvoiceCurrencyCode.normalizedOrDefault("12!") == "AUD")
        #expect(InvoiceCurrencyCode.normalizedOrDefault(" usd ") == "USD")
    }

    @Test func PersistedInvoiceDefaultMatchesSharedContract() {
        #expect(InvoiceCurrencyCode.defaultValue == "AUD")
    }
}
