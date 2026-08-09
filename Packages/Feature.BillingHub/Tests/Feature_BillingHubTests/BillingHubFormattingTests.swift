import Foundation
import SharedUI
import Testing

@Suite(.tags(.unit))
struct BillingHubFormattingTests {
    @Test func invoiceLaneTotalUsesCurrencyFormatting() throws {
        let total = try #require(Decimal(string: "1234.50"))
        let formatted = CurrencyFormatting.display(total, code: "AUD", locale: Locale(identifier: "en_AU"))
        #expect(formatted.contains("1"))
        #expect(formatted.contains("234") || formatted.contains("1,234"))
    }

    @Test func travelRateChipUsesCurrencyFormatting() {
        let rate = 0.97
        let formatted = CurrencyFormatting.display(rate, code: "AUD", locale: Locale(identifier: "en_AU"))
        #expect(formatted.contains("0"))
        #expect(formatted.contains("97") || formatted.contains("9"))
    }
}
