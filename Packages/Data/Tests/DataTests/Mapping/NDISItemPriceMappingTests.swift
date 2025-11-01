import XCTest
import SwiftData
import Core
@testable import Data

/// Comprehensive tests for NDISItem price mapping with various regional price scenarios
/// Tests the priority-based price extraction logic and edge cases
@MainActor
final class NDISItemPriceMappingTests: XCTestCase {
    
    private var modelContext: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model context for testing
        let schema = Schema([
            NDISItemEntity.self,
            RegionalPriceEntity.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDown() async throws {
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Test Data Setup
    
    private func createNDISItemEntity(
        itemNumber: String,
        name: String = "Test Item",
        description: String = "Test Description",
        category: String = "Test Category",
        unit: String = "hour"
    ) -> NDISItemEntity {
        let entity = NDISItemEntity(id: UUID())
        entity.itemNumber = itemNumber
        entity.name = name
        entity.description = description
        entity.category = category
        entity.unit = unit
        entity.isCurrent = true
        entity.status = "Active"
        entity.type = "Support Item"
        entity.categoryNamePACE = "Test PACE Category"
        entity.categoryNumber = "01"
        entity.categoryNumberPACE = "01"
        entity.effectiveStartDate = Date()
        entity.effectiveEndDate = Date().addingTimeInterval(365 * 24 * 60 * 60) // 1 year from now
        entity.features = "Test features"
        entity.ndiaRequestedReports = false
        entity.nonFaceToFaceProvision = false
        entity.providerTravel = false
        entity.quoteRequired = false
        entity.registrationGroup = "Test Group"
        entity.registrationGroupNumber = "01"
        entity.shortNoticeCancellations = false
        entity.irregularSILSupports = false
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
    
    private func addRegionalPrice(
        to item: NDISItemEntity,
        region: String,
        amount: Double
    ) -> RegionalPriceEntity {
        let priceEntity = RegionalPriceEntity(id: UUID())
        priceEntity.regionIdentifier = region
        priceEntity.amount = amount
        priceEntity.ndisItem = item
        modelContext.insert(priceEntity)
        try! modelContext.save()
        return priceEntity
    }
    
    // MARK: - Priority Order Tests
    
    func testPriceExtractionWithNationalPrice() {
        // Given: Item with NATIONAL price (highest priority)
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_1")
        addRegionalPrice(to: entity, region: "NATIONAL", amount: 50.0)
        addRegionalPrice(to: entity, region: "NSW", amount: 45.0)
        addRegionalPrice(to: entity, region: "VIC", amount: 55.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use NATIONAL price (highest priority)
        XCTAssertEqual(ndisItem.price, 50.0)
    }
    
    func testPriceExtractionWithNSWPrice() {
        // Given: Item with NSW price (no NATIONAL)
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_2")
        addRegionalPrice(to: entity, region: "NSW", amount: 45.0)
        addRegionalPrice(to: entity, region: "VIC", amount: 55.0)
        addRegionalPrice(to: entity, region: "QLD", amount: 40.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use NSW price (second priority)
        XCTAssertEqual(ndisItem.price, 45.0)
    }
    
    func testPriceExtractionWithVICPrice() {
        // Given: Item with VIC price (no NATIONAL or NSW)
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_3")
        addRegionalPrice(to: entity, region: "VIC", amount: 55.0)
        addRegionalPrice(to: entity, region: "QLD", amount: 40.0)
        addRegionalPrice(to: entity, region: "WA", amount: 60.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use VIC price (third priority)
        XCTAssertEqual(ndisItem.price, 55.0)
    }
    
    func testPriceExtractionWithQLDPrice() {
        // Given: Item with QLD price (no NATIONAL, NSW, or VIC)
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_4")
        addRegionalPrice(to: entity, region: "QLD", amount: 40.0)
        addRegionalPrice(to: entity, region: "WA", amount: 60.0)
        addRegionalPrice(to: entity, region: "SA", amount: 35.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use QLD price (fourth priority)
        XCTAssertEqual(ndisItem.price, 40.0)
    }
    
    func testPriceExtractionWithWAPrice() {
        // Given: Item with WA price (no higher priority regions)
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_5")
        addRegionalPrice(to: entity, region: "WA", amount: 60.0)
        addRegionalPrice(to: entity, region: "SA", amount: 35.0)
        addRegionalPrice(to: entity, region: "TAS", amount: 65.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use WA price (fifth priority)
        XCTAssertEqual(ndisItem.price, 60.0)
    }
    
    func testPriceExtractionWithSAPrice() {
        // Given: Item with SA price (no higher priority regions)
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_6")
        addRegionalPrice(to: entity, region: "SA", amount: 35.0)
        addRegionalPrice(to: entity, region: "TAS", amount: 65.0)
        addRegionalPrice(to: entity, region: "ACT", amount: 70.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use SA price (sixth priority)
        XCTAssertEqual(ndisItem.price, 35.0)
    }
    
    func testPriceExtractionWithTASPrice() {
        // Given: Item with TAS price (no higher priority regions)
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_7")
        addRegionalPrice(to: entity, region: "TAS", amount: 65.0)
        addRegionalPrice(to: entity, region: "ACT", amount: 70.0)
        addRegionalPrice(to: entity, region: "NT", amount: 75.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use TAS price (seventh priority)
        XCTAssertEqual(ndisItem.price, 65.0)
    }
    
    func testPriceExtractionWithACTPrice() {
        // Given: Item with ACT price (no higher priority regions)
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_8")
        addRegionalPrice(to: entity, region: "ACT", amount: 70.0)
        addRegionalPrice(to: entity, region: "NT", amount: 75.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use ACT price (eighth priority)
        XCTAssertEqual(ndisItem.price, 70.0)
    }
    
    func testPriceExtractionWithNTPrice() {
        // Given: Item with NT price (lowest priority)
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_9")
        addRegionalPrice(to: entity, region: "NT", amount: 75.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use NT price (ninth priority)
        XCTAssertEqual(ndisItem.price, 75.0)
    }
    
    func testPriceExtractionWithNonStandardRegion() {
        // Given: Item with only non-standard region
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_10")
        addRegionalPrice(to: entity, region: "CUSTOM_REGION", amount: 80.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use the non-standard region price (fallback)
        XCTAssertEqual(ndisItem.price, 80.0)
    }
    
    // MARK: - Multiple Price Scenarios
    
    func testPriceExtractionWithAllRegions() {
        // Given: Item with all standard regions
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_11")
        addRegionalPrice(to: entity, region: "NT", amount: 75.0)
        addRegionalPrice(to: entity, region: "ACT", amount: 70.0)
        addRegionalPrice(to: entity, region: "TAS", amount: 65.0)
        addRegionalPrice(to: entity, region: "SA", amount: 35.0)
        addRegionalPrice(to: entity, region: "WA", amount: 60.0)
        addRegionalPrice(to: entity, region: "QLD", amount: 40.0)
        addRegionalPrice(to: entity, region: "VIC", amount: 55.0)
        addRegionalPrice(to: entity, region: "NSW", amount: 45.0)
        addRegionalPrice(to: entity, region: "NATIONAL", amount: 50.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use NATIONAL price (highest priority)
        XCTAssertEqual(ndisItem.price, 50.0)
    }
    
    func testPriceExtractionWithMixedRegions() {
        // Given: Item with mixed standard and non-standard regions
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_12")
        addRegionalPrice(to: entity, region: "CUSTOM_REGION", amount: 80.0)
        addRegionalPrice(to: entity, region: "NSW", amount: 45.0)
        addRegionalPrice(to: entity, region: "ANOTHER_CUSTOM", amount: 90.0)
        addRegionalPrice(to: entity, region: "VIC", amount: 55.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use NSW price (highest priority standard region)
        XCTAssertEqual(ndisItem.price, 45.0)
    }
    
    func testPriceExtractionWithOnlyNonStandardRegions() {
        // Given: Item with only non-standard regions
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_13")
        addRegionalPrice(to: entity, region: "CUSTOM_REGION_1", amount: 80.0)
        addRegionalPrice(to: entity, region: "CUSTOM_REGION_2", amount: 90.0)
        addRegionalPrice(to: entity, region: "CUSTOM_REGION_3", amount: 70.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use the first available non-standard region price
        XCTAssertEqual(ndisItem.price, 80.0)
    }
    
    // MARK: - Edge Cases
    
    func testPriceExtractionWithNoPrices() {
        // Given: Item with no regional prices
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_14")
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should have nil price
        XCTAssertNil(ndisItem.price)
    }
    
    func testPriceExtractionWithZeroPrices() {
        // Given: Item with zero amount prices
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_15")
        addRegionalPrice(to: entity, region: "NATIONAL", amount: 0.0)
        addRegionalPrice(to: entity, region: "NSW", amount: 0.0)
        addRegionalPrice(to: entity, region: "VIC", amount: 0.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should have nil price (zero amounts are filtered out)
        XCTAssertNil(ndisItem.price)
    }
    
    func testPriceExtractionWithNegativePrices() {
        // Given: Item with negative amount prices
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_16")
        addRegionalPrice(to: entity, region: "NATIONAL", amount: -10.0)
        addRegionalPrice(to: entity, region: "NSW", amount: -5.0)
        addRegionalPrice(to: entity, region: "VIC", amount: -15.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should have nil price (negative amounts are filtered out)
        XCTAssertNil(ndisItem.price)
    }
    
    func testPriceExtractionWithMixedValidAndInvalidPrices() {
        // Given: Item with mix of valid and invalid prices
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_17")
        addRegionalPrice(to: entity, region: "NATIONAL", amount: 0.0)  // Invalid
        addRegionalPrice(to: entity, region: "NSW", amount: -5.0)      // Invalid
        addRegionalPrice(to: entity, region: "VIC", amount: 55.0)      // Valid
        addRegionalPrice(to: entity, region: "QLD", amount: 0.0)       // Invalid
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use VIC price (first valid price in priority order)
        XCTAssertEqual(ndisItem.price, 55.0)
    }
    
    func testPriceExtractionWithVeryLargePrices() {
        // Given: Item with very large prices
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_18")
        addRegionalPrice(to: entity, region: "NATIONAL", amount: 999999.99)
        addRegionalPrice(to: entity, region: "NSW", amount: 888888.88)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use NATIONAL price (highest priority)
        XCTAssertEqual(ndisItem.price, 999999.99)
    }
    
    func testPriceExtractionWithVerySmallPrices() {
        // Given: Item with very small prices
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_19")
        addRegionalPrice(to: entity, region: "NATIONAL", amount: 0.01)
        addRegionalPrice(to: entity, region: "NSW", amount: 0.02)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use NATIONAL price (highest priority)
        XCTAssertEqual(ndisItem.price, 0.01)
    }
    
    // MARK: - Priority Order Validation
    
    func testPriorityOrderWithIdenticalPrices() {
        // Given: Item with identical prices in different regions
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_20")
        addRegionalPrice(to: entity, region: "VIC", amount: 50.0)
        addRegionalPrice(to: entity, region: "NSW", amount: 50.0)
        addRegionalPrice(to: entity, region: "NATIONAL", amount: 50.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use NATIONAL price (highest priority, even if identical)
        XCTAssertEqual(ndisItem.price, 50.0)
    }
    
    func testPriorityOrderWithDescendingPrices() {
        // Given: Item with prices in descending order of priority
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_21")
        addRegionalPrice(to: entity, region: "NT", amount: 10.0)
        addRegionalPrice(to: entity, region: "ACT", amount: 20.0)
        addRegionalPrice(to: entity, region: "TAS", amount: 30.0)
        addRegionalPrice(to: entity, region: "SA", amount: 40.0)
        addRegionalPrice(to: entity, region: "WA", amount: 50.0)
        addRegionalPrice(to: entity, region: "QLD", amount: 60.0)
        addRegionalPrice(to: entity, region: "VIC", amount: 70.0)
        addRegionalPrice(to: entity, region: "NSW", amount: 80.0)
        addRegionalPrice(to: entity, region: "NATIONAL", amount: 90.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use NATIONAL price (highest priority, not highest value)
        XCTAssertEqual(ndisItem.price, 90.0)
    }
    
    func testPriorityOrderWithAscendingPrices() {
        // Given: Item with prices in ascending order of priority
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_22")
        addRegionalPrice(to: entity, region: "NATIONAL", amount: 10.0)
        addRegionalPrice(to: entity, region: "NSW", amount: 20.0)
        addRegionalPrice(to: entity, region: "VIC", amount: 30.0)
        addRegionalPrice(to: entity, region: "QLD", amount: 40.0)
        addRegionalPrice(to: entity, region: "WA", amount: 50.0)
        addRegionalPrice(to: entity, region: "SA", amount: 60.0)
        addRegionalPrice(to: entity, region: "TAS", amount: 70.0)
        addRegionalPrice(to: entity, region: "ACT", amount: 80.0)
        addRegionalPrice(to: entity, region: "NT", amount: 90.0)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use NATIONAL price (highest priority, not highest value)
        XCTAssertEqual(ndisItem.price, 10.0)
    }
    
    // MARK: - Real-World Scenarios
    
    func testRealWorldScenario1_PersonalCare() {
        // Given: Personal care item with typical regional pricing
        let entity = createNDISItemEntity(
            itemNumber: "01_001_0107_1_1",
            name: "Personal Care",
            description: "Assistance with daily personal care activities",
            category: "Assistance with Daily Life",
            unit: "hour"
        )
        addRegionalPrice(to: entity, region: "NSW", amount: 88.00)
        addRegionalPrice(to: entity, region: "VIC", amount: 85.00)
        addRegionalPrice(to: entity, region: "QLD", amount: 82.00)
        addRegionalPrice(to: entity, region: "WA", amount: 90.00)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use NSW price (highest priority available)
        XCTAssertEqual(ndisItem.price, 88.00)
        XCTAssertEqual(ndisItem.name, "Personal Care")
        XCTAssertEqual(ndisItem.unit, "hour")
    }
    
    func testRealWorldScenario2_CommunityAccess() {
        // Given: Community access item with NATIONAL pricing
        let entity = createNDISItemEntity(
            itemNumber: "01_001_0107_2_1",
            name: "Community Access",
            description: "Support to access and participate in community activities",
            category: "Assistance with Daily Life",
            unit: "hour"
        )
        addRegionalPrice(to: entity, region: "NATIONAL", amount: 75.00)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use NATIONAL price
        XCTAssertEqual(ndisItem.price, 75.00)
        XCTAssertEqual(ndisItem.name, "Community Access")
        XCTAssertEqual(ndisItem.unit, "hour")
    }
    
    func testRealWorldScenario3_Transport() {
        // Given: Transport item with mixed regional pricing
        let entity = createNDISItemEntity(
            itemNumber: "01_001_0107_3_1",
            name: "Transport",
            description: "Transport to access community, social, economic and daily life activities",
            category: "Transport",
            unit: "km"
        )
        addRegionalPrice(to: entity, region: "VIC", amount: 1.20)
        addRegionalPrice(to: entity, region: "QLD", amount: 1.15)
        addRegionalPrice(to: entity, region: "WA", amount: 1.25)
        addRegionalPrice(to: entity, region: "SA", amount: 1.10)
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should use VIC price (highest priority available)
        XCTAssertEqual(ndisItem.price, 1.20)
        XCTAssertEqual(ndisItem.name, "Transport")
        XCTAssertEqual(ndisItem.unit, "km")
    }
    
    func testRealWorldScenario4_NoPricing() {
        // Given: Item with no regional pricing (new item)
        let entity = createNDISItemEntity(
            itemNumber: "01_001_0107_4_1",
            name: "New Support Item",
            description: "A new support item without pricing information",
            category: "Assistance with Daily Life",
            unit: "hour"
        )
        
        // When: Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Then: Should have nil price
        XCTAssertNil(ndisItem.price)
        XCTAssertEqual(ndisItem.name, "New Support Item")
        XCTAssertEqual(ndisItem.unit, "hour")
    }
    
    // MARK: - Performance Tests
    
    func testPriceExtractionPerformance() {
        // Given: Item with many regional prices
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_23")
        
        // Add 100 regional prices
        for i in 0..<100 {
            addRegionalPrice(to: entity, region: "REGION_\(i)", amount: Double(i))
        }
        
        // When: Convert to domain model and measure performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let ndisItem = NDISItem(from: entity)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then: Should complete quickly and use first available price
        XCTAssertLessThan(timeElapsed, 0.1) // Should complete in less than 100ms
        XCTAssertEqual(ndisItem.price, 0.0) // Should use first available price
    }
    
    // MARK: - Integration Tests
    
    func testIntegrationWithNDISPriceUtilities() {
        // Given: Item with regional prices
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_24")
        addRegionalPrice(to: entity, region: "NSW", amount: 45.0)
        addRegionalPrice(to: entity, region: "VIC", amount: 55.0)
        
        // When: Convert to domain model and use utilities
        let ndisItem = NDISItem(from: entity)
        let safePrice = NDISPriceUtilities.safePrice(from: ndisItem, fallbackPrice: 0.0)
        let hasValidPrice = NDISPriceUtilities.hasValidPrice(ndisItem)
        let formattedPrice = NDISPriceUtilities.formatPrice(ndisItem.price)
        
        // Then: Utilities should work correctly
        XCTAssertEqual(safePrice, 45.0)
        XCTAssertTrue(hasValidPrice)
        XCTAssertTrue(formattedPrice.contains("45.00"))
    }
    
    func testIntegrationWithBusinessLogic() {
        // Given: Item with regional prices
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_25")
        addRegionalPrice(to: entity, region: "NATIONAL", amount: 50.0)
        addRegionalPrice(to: entity, region: "NSW", amount: 45.0)
        
        // When: Convert to domain model and simulate business logic usage
        let ndisItem = NDISItem(from: entity)
        
        // Simulate ServiceBulkEditorView usage
        let rate = ndisItem.price ?? 0.0
        let priceMode: BulkPriceMode = ndisItem.price != nil ? .ndis : .custom
        
        // Then: Business logic should work correctly
        XCTAssertEqual(rate, 50.0)
        XCTAssertEqual(priceMode, .ndis)
    }
}

// MARK: - Test Helpers

extension NDISItemPriceMappingTests {
    
    /// Helper to create a test scenario with specific regional prices
    private func createTestScenario(
        itemNumber: String,
        name: String = "Test Item",
        prices: [(region: String, amount: Double)]
    ) -> NDISItem {
        let entity = createNDISItemEntity(itemNumber: itemNumber, name: name)
        
        for (region, amount) in prices {
            addRegionalPrice(to: entity, region: region, amount: amount)
        }
        
        return NDISItem(from: entity)
    }
    
    /// Helper to verify price extraction works correctly
    private func verifyPriceExtraction(
        itemNumber: String,
        prices: [(region: String, amount: Double)],
        expectedPrice: Double?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let ndisItem = createTestScenario(itemNumber: itemNumber, prices: prices)
        XCTAssertEqual(ndisItem.price, expectedPrice, file: file, line: line)
    }
    
    /// Helper to verify priority order is respected
    private func verifyPriorityOrder(
        itemNumber: String,
        prices: [(region: String, amount: Double)],
        expectedRegion: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let ndisItem = createTestScenario(itemNumber: itemNumber, prices: prices)
        let expectedPrice = prices.first { $0.region == expectedRegion }?.amount
        XCTAssertEqual(ndisItem.price, expectedPrice, file: file, line: line)
    }
}
