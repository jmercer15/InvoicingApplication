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
            NDISItemEntity.self,
            RegionalPriceEntity.self,
            ServiceAgreementEntity.self,
            SupportLogEntity.self,
            BulkClaimBatchEntity.self,
            BulkClaimLineEntity.self
        ]
        let (_, context) = try ModelContainerFactory.makeInMemoryContext(models: models)
        modelContext = context
    }
    
    override func tearDown() async throws {
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Test Data Setup
    
    private func createNDISItemWithPrices(itemNumber: String, prices: [(region: String, amount: Double)]) -> NDISItemEntity {
        let entity = NDISItemEntity(id: UUID())
        entity.itemNumber = itemNumber
        entity.name = "Test Item \(itemNumber)"
        entity.description = "Test description"
        entity.category = "Test Category"
        entity.unit = "hour"
        entity.isCurrent = true
        
        // Create regional prices
        for (region, amount) in prices {
            let priceEntity = RegionalPriceEntity(id: UUID())
            priceEntity.regionIdentifier = region
            priceEntity.amount = amount
            priceEntity.ndisItem = entity
            modelContext.insert(priceEntity)
        }
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
    
    private func createNDISItemWithoutPrices(itemNumber: String) -> NDISItemEntity {
        let entity = NDISItemEntity(id: UUID())
        entity.itemNumber = itemNumber
        entity.name = "Test Item \(itemNumber)"
        entity.description = "Test description"
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
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("NATIONAL", 50.0)])
        let ndisItem = NDISItem(from: entity)
        
        // When
        let price = NDISPriceUtilities.safePrice(from: ndisItem, fallbackPrice: 0.0)
        
        // Then
        XCTAssertEqual(price, 50.0)
    }
    
    func testSafePriceWithNilPrice() {
        // Given
        let entity = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let ndisItem = NDISItem(from: entity)
        
        // When
        let price = NDISPriceUtilities.safePrice(from: ndisItem, fallbackPrice: 25.0)
        
        // Then
        XCTAssertEqual(price, 25.0)
    }
    
    func testHasValidPriceWithValidPrice() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("NATIONAL", 50.0)])
        let ndisItem = NDISItem(from: entity)
        
        // When
        let hasValidPrice = NDISPriceUtilities.hasValidPrice(ndisItem)
        
        // Then
        XCTAssertTrue(hasValidPrice)
    }
    
    func testHasValidPriceWithNilPrice() {
        // Given
        let entity = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let ndisItem = NDISItem(from: entity)
        
        // When
        let hasValidPrice = NDISPriceUtilities.hasValidPrice(ndisItem)
        
        // Then
        XCTAssertFalse(hasValidPrice)
    }
    
    func testValidatedPriceWithValidPrice() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("NATIONAL", 50.0)])
        let ndisItem = NDISItem(from: entity)
        
        // When
        let result = NDISPriceUtilities.validatedPrice(from: ndisItem, context: "test")
        
        // Then
        switch result {
        case .success(let price):
            XCTAssertEqual(price, 50.0)
        case .failure:
            XCTFail("Expected success but got failure")
        }
    }
    
    func testValidatedPriceWithNilPrice() {
        // Given
        let entity = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let ndisItem = NDISItem(from: entity)
        
        // When
        let result = NDISPriceUtilities.validatedPrice(from: ndisItem, context: "test")
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("No price available"))
        }
    }
    
    func testValidatedPriceWithInvalidPrice() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("NATIONAL", -10.0)])
        let ndisItem = NDISItem(from: entity)
        
        // When
        let result = NDISPriceUtilities.validatedPrice(from: ndisItem, context: "test")
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("Invalid price"))
        }
    }
    
    func testCompareByPriceWithValidPrices() {
        // Given
        let entity1 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("NATIONAL", 50.0)])
        let entity2 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_2", prices: [("NATIONAL", 75.0)])
        let item1 = NDISItem(from: entity1)
        let item2 = NDISItem(from: entity2)
        
        // When
        let result = NDISPriceUtilities.compareByPrice(item1, item2)
        
        // Then
        XCTAssertEqual(result, .orderedAscending)
    }
    
    func testCompareByPriceWithNilPrices() {
        // Given
        let entity1 = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let entity2 = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_2")
        let item1 = NDISItem(from: entity1)
        let item2 = NDISItem(from: entity2)
        
        // When
        let result = NDISPriceUtilities.compareByPrice(item1, item2, nilPriceValue: 0.0)
        
        // Then
        XCTAssertEqual(result, .orderedSame)
    }
    
    func testMinimumPriceWithMixedPrices() {
        // Given
        let entity1 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("NATIONAL", 50.0)])
        let entity2 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_2", prices: [("NATIONAL", 75.0)])
        let entity3 = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_3")
        let items = [NDISItem(from: entity1), NDISItem(from: entity2), NDISItem(from: entity3)]
        
        // When
        let minPrice = NDISPriceUtilities.minimumPrice(from: items, includeNilPrices: false)
        
        // Then
        XCTAssertEqual(minPrice, 50.0)
    }
    
    func testMaximumPriceWithMixedPrices() {
        // Given
        let entity1 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("NATIONAL", 50.0)])
        let entity2 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_2", prices: [("NATIONAL", 75.0)])
        let entity3 = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_3")
        let items = [NDISItem(from: entity1), NDISItem(from: entity2), NDISItem(from: entity3)]
        
        // When
        let maxPrice = NDISPriceUtilities.maximumPrice(from: items, includeNilPrices: false)
        
        // Then
        XCTAssertEqual(maxPrice, 75.0)
    }
    
    func testFormatPriceWithValidPrice() {
        // Given
        let price: Double? = 50.0
        
        // When
        let formatted = NDISPriceUtilities.formatPrice(price)
        
        // Then
        XCTAssertTrue(formatted.contains("50.00"))
    }
    
    func testFormatPriceWithNilPrice() {
        // Given
        let price: Double? = nil
        
        // When
        let formatted = NDISPriceUtilities.formatPrice(price)
        
        // Then
        XCTAssertEqual(formatted, "Price not available")
    }
    
    func testFormatPriceRangeWithValidPrices() {
        // Given
        let minPrice: Double? = 50.0
        let maxPrice: Double? = 75.0
        
        // When
        let formatted = NDISPriceUtilities.formatPriceRange(minPrice: minPrice, maxPrice: maxPrice)
        
        // Then
        XCTAssertTrue(formatted.contains("50.00"))
        XCTAssertTrue(formatted.contains("75.00"))
    }
    
    func testFormatPriceRangeWithNilPrices() {
        // Given
        let minPrice: Double? = nil
        let maxPrice: Double? = nil
        
        // When
        let formatted = NDISPriceUtilities.formatPriceRange(minPrice: minPrice, maxPrice: maxPrice)
        
        // Then
        XCTAssertEqual(formatted, "Price not available")
    }
    
    // MARK: - Extension Tests
    
    func testNDISItemSafePriceExtension() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("NATIONAL", 50.0)])
        let ndisItem = NDISItem(from: entity)
        
        // When
        let price = ndisItem.safePrice(fallback: 25.0)
        
        // Then
        XCTAssertEqual(price, 50.0)
    }
    
    func testNDISItemHasValidPriceExtension() {
        // Given
        let entity = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let ndisItem = NDISItem(from: entity)
        
        // When
        let hasValidPrice = ndisItem.hasValidPrice
        
        // Then
        XCTAssertFalse(hasValidPrice)
    }
    
    func testNDISItemFormattedPriceExtension() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("NATIONAL", 50.0)])
        let ndisItem = NDISItem(from: entity)
        
        // When
        let formatted = ndisItem.formattedPrice()
        
        // Then
        XCTAssertTrue(formatted.contains("50.00"))
    }
    
    // MARK: - Business Logic Integration Tests
    
    func testServiceBulkEditorHandlesNilPrice() {
        // Given
        let entity = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let ndisItem = NDISItem(from: entity)
        
        // When
        let template = ServiceBulkEditorTemplate(ndisItem: ndisItem)
        
        // Then
        XCTAssertEqual(template.priceMode, .custom)
        XCTAssertEqual(template.rate, 0.0) // Should fallback to 0.0
    }
    
    func testServiceBulkEditorHandlesValidPrice() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("NATIONAL", 50.0)])
        let ndisItem = NDISItem(from: entity)
        
        // When
        let template = ServiceBulkEditorTemplate(ndisItem: ndisItem)
        
        // Then
        XCTAssertEqual(template.priceMode, .ndis)
        XCTAssertEqual(template.rate, 50.0)
    }
    
    // MARK: - Edge Cases
    
    func testPriceExtractionWithZeroAmount() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("NATIONAL", 0.0)])
        let ndisItem = NDISItem(from: entity)
        
        // When
        let hasValidPrice = ndisItem.hasValidPrice
        
        // Then
        XCTAssertTrue(hasValidPrice) // 0.0 is a valid price
    }
    
    func testPriceExtractionWithNegativeAmount() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("NATIONAL", -10.0)])
        let ndisItem = NDISItem(from: entity)
        
        // When
        let result = NDISPriceUtilities.validatedPrice(from: ndisItem)
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure for negative price")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("Invalid price"))
        }
    }
    
    func testPriceExtractionWithMultipleRegions() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [
            ("NSW", 45.0),
            ("VIC", 50.0),
            ("NATIONAL", 55.0)
        ])
        let ndisItem = NDISItem(from: entity)
        
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
    ) -> NDISItemEntity {
        let entity = NDISItemEntity(id: UUID())
        entity.itemNumber = itemNumber
        entity.name = name
        entity.description = "Test description for \(name)"
        entity.category = "Test Category"
        entity.unit = "hour"
        entity.isCurrent = true
        
        // Add regional prices if provided
        for (region, amount) in prices {
            let priceEntity = RegionalPriceEntity(id: UUID())
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
        entity: NDISItemEntity,
        expectedPrice: Double?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let ndisItem = NDISItem(from: entity)
        XCTAssertEqual(ndisItem.price, expectedPrice, file: file, line: line)
    }
}
