import Foundation
import Testing
import SwiftData
import Core
import PersistenceModels
@testable import Data

/// Unit tests for NDIS price handling business logic
/// Tests that all business logic properly handles cases where NDISItem.price is nil
@MainActor
@Suite struct NDISPriceHandlingTests {
    
    private let modelContext: ModelContext

    init() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        self.modelContext = context
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
            priceEntity.amount = Decimal(amount)
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
    
    @Test func SafePriceWithValidPrice() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let ndisItem = entity
        
        // When
        let price = NDISPriceUtilities.safePrice(from: ndisItem, fallbackPrice: 0)
        
        // Then
        #expect(price == Decimal(50))
    }
    
    @Test func SafePriceWithNilPrice() {
        // Given
        let entity = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let ndisItem = entity
        
        // When
        let price = NDISPriceUtilities.safePrice(from: ndisItem, fallbackPrice: Decimal(25))
        
        // Then
        #expect(price == Decimal(25))
    }
    
    @Test func HasValidPriceWithValidPrice() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let ndisItem = entity
        
        // When
        let hasValidPrice = NDISPriceUtilities.hasValidPrice(ndisItem)
        
        // Then
        #expect(hasValidPrice)
    }
    
    @Test func HasValidPriceWithNilPrice() {
        // Given
        let entity = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let ndisItem = entity
        
        // When
        let hasValidPrice = NDISPriceUtilities.hasValidPrice(ndisItem)
        
        // Then
        #expect(!(hasValidPrice))
    }
    
    @Test func ValidatedPriceWithValidPrice() throws {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let ndisItem = entity
        
        // When
        let price = try NDISPriceUtilities.validatedPrice(from: ndisItem, context: "test")
        
        // Then
        #expect(price == Decimal(50))
    }
    
    @Test func ValidatedPriceWithNilPrice() {
        // Given
        let entity = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let ndisItem = entity
        
        // Then
        #expect(throws: (any Error).self) { try NDISPriceUtilities.validatedPrice(from: ndisItem, context: "test") }
    }
    
    @Test func ValidatedPriceWithInvalidPrice() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", -10.0)])
        let ndisItem = entity
        
        // Then
        #expect(throws: (any Error).self) { try NDISPriceUtilities.validatedPrice(from: ndisItem, context: "test") }
    }
    
    @Test func CompareByPriceWithValidPrices() {
        // Given
        let entity1 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let entity2 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_2", prices: [("National", 75.0)])
        let item1 = entity1
        let item2 = entity2
        
        // When
        let result = NDISPriceUtilities.compareByPrice(item1, item2)
        
        // Then
        #expect(result == .orderedAscending)
    }
    
    @Test func CompareByPriceWithNilPrices() {
        // Given
        let entity1 = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let entity2 = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_2")
        let item1 = entity1
        let item2 = entity2
        
        // When
        let result = NDISPriceUtilities.compareByPrice(item1, item2, nilPriceValue: 0)
        
        // Then
        #expect(result == .orderedSame)
    }
    
    @Test func MinimumPriceWithMixedPrices() {
        // Given
        let entity1 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let entity2 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_2", prices: [("National", 75.0)])
        let entity3 = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_3")
        let items = [entity1, entity2, entity3]
        
        // When
        let minPrice = NDISPriceUtilities.minimumPrice(from: items, includeNilPrices: false)
        
        // Then
        #expect(minPrice == Decimal(50))
    }
    
    @Test func MaximumPriceWithMixedPrices() {
        // Given
        let entity1 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let entity2 = createNDISItemWithPrices(itemNumber: "01_001_0107_1_2", prices: [("National", 75.0)])
        let entity3 = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_3")
        let items = [entity1, entity2, entity3]
        
        // When
        let maxPrice = NDISPriceUtilities.maximumPrice(from: items, includeNilPrices: false)
        
        // Then
        #expect(maxPrice == Decimal(75))
    }
    
    @Test func FormatPriceWithValidPrice() {
        // Given
        let price = Decimal(50)
        
        // When
        let formatted = NDISPriceUtilities.formatPrice(price)
        
        // Then
        #expect(formatted.contains("50.00"))
    }
    
    @Test func FormatPriceWithNilPrice() {
        // When
        let formatted = NDISPriceUtilities.formatPriceRange(minPrice: nil, maxPrice: nil)
        
        // Then
        #expect(formatted == "Price not available")
    }
    
    @Test func FormatPriceRangeWithValidPrices() {
        // Given
        let minPrice: Decimal? = Decimal(50)
        let maxPrice: Decimal? = Decimal(75)
        
        // When
        let formatted = NDISPriceUtilities.formatPriceRange(minPrice: minPrice, maxPrice: maxPrice)
        
        // Then
        #expect(formatted.contains("50.00"))
        #expect(formatted.contains("75.00"))
    }
    
    @Test func FormatPriceRangeWithNilPrices() {
        // Given
        let minPrice: Decimal? = nil
        let maxPrice: Decimal? = nil
        
        // When
        let formatted = NDISPriceUtilities.formatPriceRange(minPrice: minPrice, maxPrice: maxPrice)
        
        // Then
        #expect(formatted == "Price not available")
    }
    
    // MARK: - Extension Tests
    
    @Test func NDISItemSafePriceExtension() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let ndisItem = entity
        
        // When
        let price = NDISPriceUtilities.safePrice(from: ndisItem, fallbackPrice: Decimal(25))
        
        // Then
        #expect(price == Decimal(50))
    }
    
    @Test func NDISItemHasValidPriceExtension() {
        // Given
        let entity = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let ndisItem = entity
        
        // When
        let hasValidPrice = NDISPriceUtilities.hasValidPrice(ndisItem)
        
        // Then
        #expect(!(hasValidPrice))
    }
    
    @Test func NDISItemFormattedPriceExtension() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let ndisItem = entity
        
        // When
        let formatted = NDISPriceUtilities.formatPrice(ndisItem.price ?? 0)
        
        // Then
        #expect(formatted.contains("50.00"))
    }
    
    // MARK: - Business Logic Integration Tests
    
    @Test func ServiceBulkEditorHandlesNilPrice() {
        // Given
        let entity = createNDISItemWithoutPrices(itemNumber: "01_001_0107_1_1")
        let ndisItem = entity
        
        // When
        let price = NDISPriceUtilities.safePrice(from: ndisItem, fallbackPrice: 0)
        
        // Then
        #expect(price == Decimal(0))
    }
    
    @Test func ServiceBulkEditorHandlesValidPrice() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 50.0)])
        let ndisItem = entity
        
        // When
        let price = NDISPriceUtilities.safePrice(from: ndisItem, fallbackPrice: 0)
        
        // Then
        #expect(price == Decimal(50))
    }
    
    // MARK: - Edge Cases
    
    @Test func PriceExtractionWithZeroAmount() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", 0.0)])
        let ndisItem = entity
        
        // Then
        #expect(ndisItem.price == 0)
    }
    
    @Test func PriceExtractionWithNegativeAmount() {
        // Given
        let entity = createNDISItemWithPrices(itemNumber: "01_001_0107_1_1", prices: [("National", -10.0)])
        let ndisItem = entity
        
        // Then
        #expect(throws: (any Error).self) { try NDISPriceUtilities.validatedPrice(from: ndisItem, context: "test") }
    }
    
    @Test func PriceExtractionWithMultipleRegions() {
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
        #expect(price == 55.0) // Should use NATIONAL price (highest priority)
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
            priceEntity.amount = Decimal(amount)
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
        let expected = expectedPrice.map { Decimal($0) }
        #expect(ndisItem.price == expected)
    }
}
