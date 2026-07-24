import XCTest
import SwiftData
import Core
@testable import Data

/// Unit tests for NDIS price handling business logic
/// Tests that all business logic properly handles cases where NDISItem.price is nil
@MainActor
final class NDISPriceHandlingTests: XCTestCase {
    
    private var modelContext: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model context for testing
        let models: [any PersistentModel.Type] = [
            NDISItem.self,
            RegionalPrice.self,
            ServiceAgreement.self,
            SupportLog.self,
            BulkClaimBatch.self,
            BulkClaimLine.self
        ]
        let (_, context) = try ModelContainerFactory.makeInMemoryContext(models: models)
        modelContext = context
    }
    
    override func tearDown() async throws {
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Test Data Setup
    
    private func createNDISItemWithPrices(itemNumber: String, prices: [(region: String, amount: Double)]) -> NDISItem {
        let entity = NDISItem(id: UUID())
        entity.itemNumber = itemNumber
        entity.name = "Test Item \(itemNumber)"
        entity.itemDescription = "Test description"
        entity.category = "Test Category"
        entity.unit = "hour"
        entity.isCurrent = true
        
        // Create regional prices
        for (region, amount) in prices {
            let priceEntity = RegionalPrice(id: UUID())
            priceEntity.regionIdentifier = region
            priceEntity.amount = amount
            priceEntity.ndisItem = entity
            modelContext.insert(priceEntity)
        }
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
    
    private func createNDISItemWithoutPrices(itemNumber: String) -> NDISItem {
        let entity = NDISItem(id: UUID())
        entity.itemNumber = itemNumber
        entity.name = "Test Item \(itemNumber)"
        entity.itemDescription = "Test description"
        entity.category = "Test Category"
        entity.unit = "hour"
        entity.isCurrent = true
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
    
    // MARK: - NDISPriceUtilities Tests
    
    func testSafePriceWithValidPrice() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let ndisItem = entity
        
        // When
        let price = NDISPriceUtilities.safePrice(from: ndisItem, fallbackPrice: 0)
        
        // Then
        XCTAssertEqual(price, Decimal(50))
    }
    
    func testSafePriceWithNilPrice() {
        // Given
        let entity = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let ndisItem = entity
        
        // When
        let price = NDISPriceUtilities.safePrice(from: ndisItem, fallbackPrice: Decimal(25))
        
        // Then
        XCTAssertEqual(price, Decimal(25))
    }
    
    func testHasValidPriceWithValidPrice() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let ndisItem = entity
        
        // When
        let hasValidPrice = NDISPriceUtilities.hasValidPrice(ndisItem)
        
        // Then
        XCTAssertTrue(hasValidPrice)
    }
    
    func testHasValidPriceWithNilPrice() {
        // Given
        let entity = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let ndisItem = entity
        
        // When
        let hasValidPrice = NDISPriceUtilities.hasValidPrice(ndisItem)
        
        // Then
        XCTAssertFalse(hasValidPrice)
    }
    
    func testValidatedPriceWithValidPrice() throws {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let ndisItem = entity
        
        // When
        let price = try NDISPriceUtilities.validatedPrice(from: ndisItem, context: "test")
        
        // Then
        XCTAssertEqual(price, Decimal(50))
    }
    
    func testValidatedPriceWithNilPrice() {
        // Given
        let entity = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let ndisItem = entity
        
        // Then
        XCTAssertThrowsError(try NDISPriceUtilities.validatedPrice(from: ndisItem, context: "test"))
    }
    
    func testValidatedPriceWithInvalidPrice() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", -10.0)])
        let ndisItem = entity
        
        // Then
        XCTAssertThrowsError(try NDISPriceUtilities.validatedPrice(from: ndisItem, context: "test"))
    }
    
    func testCompareByPriceWithValidPrices() {
        // Given
        let entity1 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let entity2 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_2", prices: [("National", 75.0)])
        let item1 = entity1
        let item2 = entity2
        
        // When
        let result = NDISPriceUtilities.compareByPrice(item1, item2)
        
        // Then
        XCTAssertEqual(result, .orderedAscending)
    }
    
    func testCompareByPriceWithNilPrices() {
        // Given
        let entity1 = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let entity2 = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_2")
        let item1 = entity1
        let item2 = entity2
        
        // When
        let result = NDISPriceUtilities.compareByPrice(item1, item2, nilPriceValue: 0)
        
        // Then
        XCTAssertEqual(result, .orderedSame)
    }
    
    func testMinimumPriceWithMixedPrices() {
        // Given
        let entity1 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let entity2 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_2", prices: [("National", 75.0)])
        let entity3 = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_3")
        let items = [entity1, entity2, entity3]
        
        // When
        let minPrice = NDISPriceUtilities.minimumPrice(from: items, includeNilPrices: false)
        
        // Then
        XCTAssertEqual(minPrice, Decimal(50))
    }
    
    func testMaximumPriceWithMixedPrices() {
        // Given
        let entity1 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let entity2 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_2", prices: [("National", 75.0)])
        let entity3 = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_3")
        let items = [entity1, entity2, entity3]
        
        // When
        let maxPrice = NDISPriceUtilities.maximumPrice(from: items, includeNilPrices: false)
        
        // Then
        XCTAssertEqual(maxPrice, Decimal(75))
    }
    
    func testFormatPriceWithValidPrice() {
        // Given
        let price = Decimal(50)
        
        // When
        let formatted = NDISPriceUtilities.formatPrice(price)
        
        // Then
        XCTAssertTrue(formatted.contains("50.00"))
    }
    
    func testFormatPriceWithNilPrice() {
        // When
        let formatted = NDISPriceUtilities.formatPriceRange(minPrice: nil, maxPrice: nil)
        
        // Then
        XCTAssertEqual(formatted, "Price not available")
    }
    
    func testFormatPriceRangeWithValidPrices() {
        // Given
        let minPrice: Decimal? = Decimal(50)
        let maxPrice: Decimal? = Decimal(75)
        
        // When
        let formatted = NDISPriceUtilities.formatPriceRange(minPrice: minPrice, maxPrice: maxPrice)
        
        // Then
        XCTAssertTrue(formatted.contains("50.00"))
        XCTAssertTrue(formatted.contains("75.00"))
    }
    
    func testFormatPriceRangeWithNilPrices() {
        // Given
        let minPrice: Decimal? = nil
        let maxPrice: Decimal? = nil
        
        // When
        let formatted = NDISPriceUtilities.formatPriceRange(minPrice: minPrice, maxPrice: maxPrice)
        
        // Then
        XCTAssertEqual(formatted, "Price not available")
    }
    
    // MARK: - Extension Tests
    
    func testNDISItemSafePriceExtension() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let ndisItem = entity
        
        // When
        let price = NDISPriceUtilities.safePrice(from: ndisItem, fallbackPrice: Decimal(25))
        
        // Then
        XCTAssertEqual(price, Decimal(50))
    }
    
    func testNDISItemHasValidPriceExtension() {
        // Given
        let entity = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let ndisItem = entity
        
        // When
        let hasValidPrice = NDISPriceUtilities.hasValidPrice(ndisItem)
        
        // Then
        XCTAssertFalse(hasValidPrice)
    }
    
    func testNDISItemFormattedPriceExtension() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let ndisItem = entity
        
        // When
        let formatted = NDISPriceUtilities.formatPrice(Decimal(ndisItem.price ?? 0))
        
        // Then
        XCTAssertTrue(formatted.contains("50.00"))
    }
    
    // MARK: - Business Logic Integration Tests
    
    func testServiceBulkEditorHandlesNilPrice() {
        // Given
        let entity = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let ndisItem = entity
        
        // When
        let price = NDISPriceUtilities.safePrice(from: ndisItem, fallbackPrice: 0)
        
        // Then
        XCTAssertEqual(price, Decimal(0))
    }
    
    func testServiceBulkEditorHandlesValidPrice() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let ndisItem = entity
        
        // When
        let price = NDISPriceUtilities.safePrice(from: ndisItem, fallbackPrice: 0)
        
        // Then
        XCTAssertEqual(price, Decimal(50))
    }
    
    // MARK: - Edge Cases
    
    func testPriceExtractionWithZeroAmount() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 0.0)])
        let ndisItem = entity
        
        // Then
        XCTAssertEqual(ndisItem.price, 0)
    }
    
    func testPriceExtractionWithNegativeAmount() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", -10.0)])
        let ndisItem = entity
        
        // Then
        XCTAssertThrowsError(try NDISPriceUtilities.validatedPrice(from: ndisItem, context: "test"))
    }
    
    func testPriceExtractionWithMultipleRegions() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [
            ("NSW", 45.0),
            ("VIC", 50.0),
            ("National", 55.0)
        ])
        let ndisItem = entity
        
        // When
        let price = ndisItem.price
        
        // Then
        XCTAssertEqual(price, 55.0) // Should use NATIONAL price (highest priority)
    }
}

// MARK: - Test Helpers

extension NDISPriceHandlingTests {
    
    /// Helper to create a test NDIS item with specific regional prices
    private func createTestNDISItem(
        itemNumber: String,
        name: String = "Test Item",
        prices: [(region: String, amount: Double)] = []
    ) -> NDISItem {
        let entity = NDISItem(id: UUID())
        entity.itemNumber = itemNumber
        entity.name = name
        entity.itemDescription = "Test description for \(name)"
        entity.category = "Test Category"
        entity.unit = "hour"
        entity.isCurrent = true
        
        // Add regional prices if provided
        for (region, amount) in prices {
            let priceEntity = RegionalPrice(id: UUID())
            priceEntity.regionIdentifier = region
            priceEntity.amount = amount
            priceEntity.ndisItem = entity
            modelContext.insert(priceEntity)
        }
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
    
    /// Helper to verify price extraction works correctly
    private func verifyPriceExtraction(
        entity: NDISItem,
        expectedPrice: Double?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let ndisItem = entity
        XCTAssertEqual(ndisItem.price, expectedPrice, file: file, line: line)
    }
}
