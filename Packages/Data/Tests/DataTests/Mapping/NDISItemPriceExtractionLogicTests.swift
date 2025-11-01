import XCTest
import Core
@testable import Data

/// Unit tests specifically for the NDISItem price extraction logic
/// Tests the extractRepresentativePrice method and its edge cases
final class NDISItemPriceExtractionLogicTests: XCTestCase {
    
    // MARK: - Test Data Setup
    
    private func createRegionalPriceEntity(region: String, amount: Double) -> RegionalPriceEntity {
        let entity = RegionalPriceEntity(id: UUID())
        entity.regionIdentifier = region
        entity.amount = amount
        return entity
    }
    
    // MARK: - Priority Order Tests
    
    func testExtractRepresentativePriceWithNational() {
        // Given: Regional prices with NATIONAL
        let regionalPrices = [
            createRegionalPriceEntity(region: "NSW", amount: 45.0),
            createRegionalPriceEntity(region: "VIC", amount: 55.0),
            createRegionalPriceEntity(region: "NATIONAL", amount: 50.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use NATIONAL price
        XCTAssertEqual(price, 50.0)
    }
    
    func testExtractRepresentativePriceWithNSW() {
        // Given: Regional prices with NSW (no NATIONAL)
        let regionalPrices = [
            createRegionalPriceEntity(region: "VIC", amount: 55.0),
            createRegionalPriceEntity(region: "NSW", amount: 45.0),
            createRegionalPriceEntity(region: "QLD", amount: 40.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use NSW price
        XCTAssertEqual(price, 45.0)
    }
    
    func testExtractRepresentativePriceWithVIC() {
        // Given: Regional prices with VIC (no NATIONAL or NSW)
        let regionalPrices = [
            createRegionalPriceEntity(region: "QLD", amount: 40.0),
            createRegionalPriceEntity(region: "VIC", amount: 55.0),
            createRegionalPriceEntity(region: "WA", amount: 60.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use VIC price
        XCTAssertEqual(price, 55.0)
    }
    
    func testExtractRepresentativePriceWithQLD() {
        // Given: Regional prices with QLD (no higher priority regions)
        let regionalPrices = [
            createRegionalPriceEntity(region: "WA", amount: 60.0),
            createRegionalPriceEntity(region: "QLD", amount: 40.0),
            createRegionalPriceEntity(region: "SA", amount: 35.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use QLD price
        XCTAssertEqual(price, 40.0)
    }
    
    func testExtractRepresentativePriceWithWA() {
        // Given: Regional prices with WA (no higher priority regions)
        let regionalPrices = [
            createRegionalPriceEntity(region: "SA", amount: 35.0),
            createRegionalPriceEntity(region: "WA", amount: 60.0),
            createRegionalPriceEntity(region: "TAS", amount: 65.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use WA price
        XCTAssertEqual(price, 60.0)
    }
    
    func testExtractRepresentativePriceWithSA() {
        // Given: Regional prices with SA (no higher priority regions)
        let regionalPrices = [
            createRegionalPriceEntity(region: "TAS", amount: 65.0),
            createRegionalPriceEntity(region: "SA", amount: 35.0),
            createRegionalPriceEntity(region: "ACT", amount: 70.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use SA price
        XCTAssertEqual(price, 35.0)
    }
    
    func testExtractRepresentativePriceWithTAS() {
        // Given: Regional prices with TAS (no higher priority regions)
        let regionalPrices = [
            createRegionalPriceEntity(region: "ACT", amount: 70.0),
            createRegionalPriceEntity(region: "TAS", amount: 65.0),
            createRegionalPriceEntity(region: "NT", amount: 75.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use TAS price
        XCTAssertEqual(price, 65.0)
    }
    
    func testExtractRepresentativePriceWithACT() {
        // Given: Regional prices with ACT (no higher priority regions)
        let regionalPrices = [
            createRegionalPriceEntity(region: "NT", amount: 75.0),
            createRegionalPriceEntity(region: "ACT", amount: 70.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use ACT price
        XCTAssertEqual(price, 70.0)
    }
    
    func testExtractRepresentativePriceWithNT() {
        // Given: Regional prices with NT (lowest priority)
        let regionalPrices = [
            createRegionalPriceEntity(region: "NT", amount: 75.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use NT price
        XCTAssertEqual(price, 75.0)
    }
    
    func testExtractRepresentativePriceWithNonStandardRegion() {
        // Given: Regional prices with only non-standard region
        let regionalPrices = [
            createRegionalPriceEntity(region: "CUSTOM_REGION", amount: 80.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use the non-standard region price
        XCTAssertEqual(price, 80.0)
    }
    
    // MARK: - Edge Cases
    
    func testExtractRepresentativePriceWithEmptyArray() {
        // Given: Empty regional prices array
        let regionalPrices: [RegionalPriceEntity] = []
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should return nil
        XCTAssertNil(price)
    }
    
    func testExtractRepresentativePriceWithZeroAmounts() {
        // Given: Regional prices with zero amounts
        let regionalPrices = [
            createRegionalPriceEntity(region: "NATIONAL", amount: 0.0),
            createRegionalPriceEntity(region: "NSW", amount: 0.0),
            createRegionalPriceEntity(region: "VIC", amount: 0.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should return nil (zero amounts are filtered out)
        XCTAssertNil(price)
    }
    
    func testExtractRepresentativePriceWithNegativeAmounts() {
        // Given: Regional prices with negative amounts
        let regionalPrices = [
            createRegionalPriceEntity(region: "NATIONAL", amount: -10.0),
            createRegionalPriceEntity(region: "NSW", amount: -5.0),
            createRegionalPriceEntity(region: "VIC", amount: -15.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should return nil (negative amounts are filtered out)
        XCTAssertNil(price)
    }
    
    func testExtractRepresentativePriceWithMixedValidAndInvalid() {
        // Given: Regional prices with mix of valid and invalid amounts
        let regionalPrices = [
            createRegionalPriceEntity(region: "NATIONAL", amount: 0.0),  // Invalid
            createRegionalPriceEntity(region: "NSW", amount: -5.0),      // Invalid
            createRegionalPriceEntity(region: "VIC", amount: 55.0),      // Valid
            createRegionalPriceEntity(region: "QLD", amount: 0.0)        // Invalid
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use VIC price (first valid price in priority order)
        XCTAssertEqual(price, 55.0)
    }
    
    func testExtractRepresentativePriceWithVeryLargeAmounts() {
        // Given: Regional prices with very large amounts
        let regionalPrices = [
            createRegionalPriceEntity(region: "NATIONAL", amount: 999999.99),
            createRegionalPriceEntity(region: "NSW", amount: 888888.88)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use NATIONAL price
        XCTAssertEqual(price, 999999.99)
    }
    
    func testExtractRepresentativePriceWithVerySmallAmounts() {
        // Given: Regional prices with very small amounts
        let regionalPrices = [
            createRegionalPriceEntity(region: "NATIONAL", amount: 0.01),
            createRegionalPriceEntity(region: "NSW", amount: 0.02)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use NATIONAL price
        XCTAssertEqual(price, 0.01)
    }
    
    // MARK: - Priority Order Validation
    
    func testPriorityOrderWithIdenticalAmounts() {
        // Given: Regional prices with identical amounts in different regions
        let regionalPrices = [
            createRegionalPriceEntity(region: "VIC", amount: 50.0),
            createRegionalPriceEntity(region: "NSW", amount: 50.0),
            createRegionalPriceEntity(region: "NATIONAL", amount: 50.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use NATIONAL price (highest priority)
        XCTAssertEqual(price, 50.0)
    }
    
    func testPriorityOrderWithDescendingAmounts() {
        // Given: Regional prices with amounts in descending order of priority
        let regionalPrices = [
            createRegionalPriceEntity(region: "NT", amount: 10.0),
            createRegionalPriceEntity(region: "ACT", amount: 20.0),
            createRegionalPriceEntity(region: "TAS", amount: 30.0),
            createRegionalPriceEntity(region: "SA", amount: 40.0),
            createRegionalPriceEntity(region: "WA", amount: 50.0),
            createRegionalPriceEntity(region: "QLD", amount: 60.0),
            createRegionalPriceEntity(region: "VIC", amount: 70.0),
            createRegionalPriceEntity(region: "NSW", amount: 80.0),
            createRegionalPriceEntity(region: "NATIONAL", amount: 90.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use NATIONAL price (highest priority, not highest value)
        XCTAssertEqual(price, 90.0)
    }
    
    func testPriorityOrderWithAscendingAmounts() {
        // Given: Regional prices with amounts in ascending order of priority
        let regionalPrices = [
            createRegionalPriceEntity(region: "NATIONAL", amount: 10.0),
            createRegionalPriceEntity(region: "NSW", amount: 20.0),
            createRegionalPriceEntity(region: "VIC", amount: 30.0),
            createRegionalPriceEntity(region: "QLD", amount: 40.0),
            createRegionalPriceEntity(region: "WA", amount: 50.0),
            createRegionalPriceEntity(region: "SA", amount: 60.0),
            createRegionalPriceEntity(region: "TAS", amount: 70.0),
            createRegionalPriceEntity(region: "ACT", amount: 80.0),
            createRegionalPriceEntity(region: "NT", amount: 90.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use NATIONAL price (highest priority, not highest value)
        XCTAssertEqual(price, 10.0)
    }
    
    // MARK: - Multiple Price Scenarios
    
    func testExtractRepresentativePriceWithAllStandardRegions() {
        // Given: Regional prices with all standard regions
        let regionalPrices = [
            createRegionalPriceEntity(region: "NT", amount: 75.0),
            createRegionalPriceEntity(region: "ACT", amount: 70.0),
            createRegionalPriceEntity(region: "TAS", amount: 65.0),
            createRegionalPriceEntity(region: "SA", amount: 35.0),
            createRegionalPriceEntity(region: "WA", amount: 60.0),
            createRegionalPriceEntity(region: "QLD", amount: 40.0),
            createRegionalPriceEntity(region: "VIC", amount: 55.0),
            createRegionalPriceEntity(region: "NSW", amount: 45.0),
            createRegionalPriceEntity(region: "NATIONAL", amount: 50.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use NATIONAL price (highest priority)
        XCTAssertEqual(price, 50.0)
    }
    
    func testExtractRepresentativePriceWithMixedRegions() {
        // Given: Regional prices with mixed standard and non-standard regions
        let regionalPrices = [
            createRegionalPriceEntity(region: "CUSTOM_REGION", amount: 80.0),
            createRegionalPriceEntity(region: "NSW", amount: 45.0),
            createRegionalPriceEntity(region: "ANOTHER_CUSTOM", amount: 90.0),
            createRegionalPriceEntity(region: "VIC", amount: 55.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use NSW price (highest priority standard region)
        XCTAssertEqual(price, 45.0)
    }
    
    func testExtractRepresentativePriceWithOnlyNonStandardRegions() {
        // Given: Regional prices with only non-standard regions
        let regionalPrices = [
            createRegionalPriceEntity(region: "CUSTOM_REGION_1", amount: 80.0),
            createRegionalPriceEntity(region: "CUSTOM_REGION_2", amount: 90.0),
            createRegionalPriceEntity(region: "CUSTOM_REGION_3", amount: 70.0)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use the first available non-standard region price
        XCTAssertEqual(price, 80.0)
    }
    
    // MARK: - Performance Tests
    
    func testExtractRepresentativePricePerformance() {
        // Given: Large array of regional prices
        var regionalPrices: [RegionalPriceEntity] = []
        
        // Add 1000 regional prices
        for i in 0..<1000 {
            regionalPrices.append(createRegionalPriceEntity(region: "REGION_\(i)", amount: Double(i)))
        }
        
        // When: Extract representative price and measure performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then: Should complete quickly and return first available price
        XCTAssertLessThan(timeElapsed, 0.1) // Should complete in less than 100ms
        XCTAssertEqual(price, 0.0) // Should return first available price
    }
    
    // MARK: - Real-World Scenarios
    
    func testRealWorldScenario_PersonalCare() {
        // Given: Personal care item with typical regional pricing
        let regionalPrices = [
            createRegionalPriceEntity(region: "NSW", amount: 88.00),
            createRegionalPriceEntity(region: "VIC", amount: 85.00),
            createRegionalPriceEntity(region: "QLD", amount: 82.00),
            createRegionalPriceEntity(region: "WA", amount: 90.00)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use NSW price (highest priority available)
        XCTAssertEqual(price, 88.00)
    }
    
    func testRealWorldScenario_CommunityAccess() {
        // Given: Community access item with NATIONAL pricing
        let regionalPrices = [
            createRegionalPriceEntity(region: "NATIONAL", amount: 75.00)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use NATIONAL price
        XCTAssertEqual(price, 75.00)
    }
    
    func testRealWorldScenario_Transport() {
        // Given: Transport item with mixed regional pricing
        let regionalPrices = [
            createRegionalPriceEntity(region: "VIC", amount: 1.20),
            createRegionalPriceEntity(region: "QLD", amount: 1.15),
            createRegionalPriceEntity(region: "WA", amount: 1.25),
            createRegionalPriceEntity(region: "SA", amount: 1.10)
        ]
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should use VIC price (highest priority available)
        XCTAssertEqual(price, 1.20)
    }
    
    func testRealWorldScenario_NoPricing() {
        // Given: Item with no regional pricing
        let regionalPrices: [RegionalPriceEntity] = []
        
        // When: Extract representative price
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        
        // Then: Should return nil
        XCTAssertNil(price)
    }
}

// MARK: - Test Helpers

extension NDISItemPriceExtractionLogicTests {
    
    /// Helper to create a test scenario with specific regional prices
    private func createTestScenario(prices: [(region: String, amount: Double)]) -> [RegionalPriceEntity] {
        return prices.map { createRegionalPriceEntity(region: $0.region, amount: $0.amount) }
    }
    
    /// Helper to verify price extraction works correctly
    private func verifyPriceExtraction(
        prices: [(region: String, amount: Double)],
        expectedPrice: Double?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let regionalPrices = createTestScenario(prices: prices)
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        XCTAssertEqual(price, expectedPrice, file: file, line: line)
    }
    
    /// Helper to verify priority order is respected
    private func verifyPriorityOrder(
        prices: [(region: String, amount: Double)],
        expectedRegion: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let regionalPrices = createTestScenario(prices: prices)
        let price = NDISItem.extractRepresentativePrice(from: regionalPrices)
        let expectedPrice = prices.first { $0.region == expectedRegion }?.amount
        XCTAssertEqual(price, expectedPrice, file: file, line: line)
    }
}
