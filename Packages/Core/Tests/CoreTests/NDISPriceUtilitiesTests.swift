import Foundation
import Testing
@testable import Core

@Suite struct NDISPriceUtilitiesTests {
    @Test func ResolvesPresentPriceBeforeFallback() {
        #expect(NDISPriceUtilities.price(resolving: 50, fallback: 25) == 50)
    }

    @Test func ResolvesFallbackWhenPriceMissing() {
        #expect(NDISPriceUtilities.price(resolving: nil, fallback: 25) == 25)
    }

    @Test func RecognizesOnlyPositivePricesAsValid() {
        #expect(NDISPriceUtilities.hasValidPrice(50))
        #expect(!NDISPriceUtilities.hasValidPrice(0))
        #expect(!NDISPriceUtilities.hasValidPrice(-1))
        #expect(!NDISPriceUtilities.hasValidPrice(nil))
    }

    @Test func ValidatesPriceWithItemContext() throws {
        #expect(try NDISPriceUtilities.validatedPrice(50, itemNumber: "01_001_0107_1_1") == 50)
        #expect(throws: NDISPriceError.missingPrice(itemNumber: "01_001_0107_1_1", context: "billing")) {
            try NDISPriceUtilities.validatedPrice(nil, itemNumber: "01_001_0107_1_1", context: "billing")
        }
        #expect(throws: NDISPriceError.invalidPrice(itemNumber: "01_001_0107_1_1", price: 0, context: "billing")) {
            try NDISPriceUtilities.validatedPrice(0, itemNumber: "01_001_0107_1_1", context: "billing")
        }
    }

    @Test func ComparesOptionalPricesUsingConfiguredNilValue() {
        #expect(NDISPriceUtilities.compare(50, to: 75) == .orderedAscending)
        #expect(NDISPriceUtilities.compare(nil, to: nil) == .orderedSame)
        #expect(NDISPriceUtilities.compare(nil, to: 25, nilPriceValue: 30) == .orderedDescending)
    }

    @Test func AggregatesOptionalPricesWithExplicitNilPolicy() {
        let prices: [Decimal?] = [50, nil, 75]

        #expect(NDISPriceUtilities.minimumPrice(in: prices) == 50)
        #expect(NDISPriceUtilities.maximumPrice(in: prices) == 75)
        #expect(NDISPriceUtilities.minimumPrice(in: prices, includingNilPrices: true) == 0)
        #expect(NDISPriceUtilities.maximumPrice(in: prices, includingNilPrices: true) == 75)
    }

    @Test func ResolvesEveryFallbackStrategy() throws {
        #expect(try NDISPriceUtilities.resolvedPrice(from: nil, using: .useZero, itemNumber: "item") == 0)
        #expect(try NDISPriceUtilities.resolvedPrice(from: nil, using: .useValue(25), itemNumber: "item") == 25)
        #expect(try NDISPriceUtilities.resolvedPrice(from: nil, using: .skip, itemNumber: "item") == nil)
        #expect(throws: NDISPriceError.missingPrice(itemNumber: "item", context: "")) {
            try NDISPriceUtilities.resolvedPrice(from: nil, using: .throwError, itemNumber: "item")
        }
    }
}
