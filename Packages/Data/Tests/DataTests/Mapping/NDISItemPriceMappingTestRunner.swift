import XCTest
import SwiftData
import Core
@testable import Data

/// Test runner for comprehensive NDISItem price mapping validation
/// Runs all price mapping scenarios and validates the results
@MainActor
final class NDISItemPriceMappingTestRunner: XCTestCase {
    
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
    
    // MARK: - Comprehensive Test Scenarios
    
    func testAllPriceMappingScenarios() {
        // Define all test scenarios
        let scenarios = [
            // Priority order scenarios
            PriceMappingScenario(
                name: "NATIONAL priority",
                prices: [("NATIONAL", 50.0), ("NSW", 45.0), ("VIC", 55.0)],
                expectedPrice: 50.0,
                expectedRegion: "NATIONAL"
            ),
            PriceMappingScenario(
                name: "NSW priority",
                prices: [("NSW", 45.0), ("VIC", 55.0), ("QLD", 40.0)],
                expectedPrice: 45.0,
                expectedRegion: "NSW"
            ),
            PriceMappingScenario(
                name: "VIC priority",
                prices: [("VIC", 55.0), ("QLD", 40.0), ("WA", 60.0)],
                expectedPrice: 55.0,
                expectedRegion: "VIC"
            ),
            PriceMappingScenario(
                name: "QLD priority",
                prices: [("QLD", 40.0), ("WA", 60.0), ("SA", 35.0)],
                expectedPrice: 40.0,
                expectedRegion: "QLD"
            ),
            PriceMappingScenario(
                name: "WA priority",
                prices: [("WA", 60.0), ("SA", 35.0), ("TAS", 65.0)],
                expectedPrice: 60.0,
                expectedRegion: "WA"
            ),
            PriceMappingScenario(
                name: "SA priority",
                prices: [("SA", 35.0), ("TAS", 65.0), ("ACT", 70.0)],
                expectedPrice: 35.0,
                expectedRegion: "SA"
            ),
            PriceMappingScenario(
                name: "TAS priority",
                prices: [("TAS", 65.0), ("ACT", 70.0), ("NT", 75.0)],
                expectedPrice: 65.0,
                expectedRegion: "TAS"
            ),
            PriceMappingScenario(
                name: "ACT priority",
                prices: [("ACT", 70.0), ("NT", 75.0)],
                expectedPrice: 70.0,
                expectedRegion: "ACT"
            ),
            PriceMappingScenario(
                name: "NT priority",
                prices: [("NT", 75.0)],
                expectedPrice: 75.0,
                expectedRegion: "NT"
            ),
            
            // Edge cases
            PriceMappingScenario(
                name: "No prices",
                prices: [],
                expectedPrice: nil,
                expectedRegion: nil
            ),
            PriceMappingScenario(
                name: "Zero prices",
                prices: [("NATIONAL", 0.0), ("NSW", 0.0)],
                expectedPrice: nil,
                expectedRegion: nil
            ),
            PriceMappingScenario(
                name: "Negative prices",
                prices: [("NATIONAL", -10.0), ("NSW", -5.0)],
                expectedPrice: nil,
                expectedRegion: nil
            ),
            PriceMappingScenario(
                name: "Mixed valid and invalid",
                prices: [("NATIONAL", 0.0), ("NSW", -5.0), ("VIC", 55.0), ("QLD", 0.0)],
                expectedPrice: 55.0,
                expectedRegion: "VIC"
            ),
            
            // Real-world scenarios
            PriceMappingScenario(
                name: "Personal Care",
                prices: [("NSW", 88.00), ("VIC", 85.00), ("QLD", 82.00), ("WA", 90.00)],
                expectedPrice: 88.00,
                expectedRegion: "NSW"
            ),
            PriceMappingScenario(
                name: "Community Access",
                prices: [("NATIONAL", 75.00)],
                expectedPrice: 75.00,
                expectedRegion: "NATIONAL"
            ),
            PriceMappingScenario(
                name: "Transport",
                prices: [("VIC", 1.20), ("QLD", 1.15), ("WA", 1.25), ("SA", 1.10)],
                expectedPrice: 1.20,
                expectedRegion: "VIC"
            ),
            
            // Non-standard regions
            PriceMappingScenario(
                name: "Non-standard region",
                prices: [("CUSTOM_REGION", 80.0)],
                expectedPrice: 80.0,
                expectedRegion: "CUSTOM_REGION"
            ),
            PriceMappingScenario(
                name: "Mixed standard and non-standard",
                prices: [("CUSTOM_REGION", 80.0), ("NSW", 45.0), ("ANOTHER_CUSTOM", 90.0)],
                expectedPrice: 45.0,
                expectedRegion: "NSW"
            ),
            PriceMappingScenario(
                name: "Only non-standard regions",
                prices: [("CUSTOM_REGION_1", 80.0), ("CUSTOM_REGION_2", 90.0), ("CUSTOM_REGION_3", 70.0)],
                expectedPrice: 80.0,
                expectedRegion: "CUSTOM_REGION_1"
            )
        ]
        
        // Run all scenarios
        for scenario in scenarios {
            runPriceMappingScenario(scenario)
        }
    }
    
    // MARK: - Performance Tests
    
    func testPriceMappingPerformance() {
        // Test with large number of regional prices
        let largeScenario = PriceMappingScenario(
            name: "Large dataset",
            prices: (0..<1000).map { ("REGION_\($0)", Double($0)) },
            expectedPrice: 0.0,
            expectedRegion: "REGION_0"
        )
        
        // Measure performance
        let startTime = CFAbsoluteTimeGetCurrent()
        runPriceMappingScenario(largeScenario)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete in reasonable time
        XCTAssertLessThan(timeElapsed, 1.0, "Price mapping should complete in less than 1 second")
    }
    
    // MARK: - Integration Tests
    
    func testIntegrationWithBusinessLogic() {
        // Test integration with ServiceBulkEditorView logic
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_1")
        addRegionalPrice(to: entity, region: "NSW", amount: 88.00)
        addRegionalPrice(to: entity, region: "VIC", amount: 85.00)
        
        let ndisItem = NDISItem(from: entity)
        
        // Simulate ServiceBulkEditorView logic
        let rate = ndisItem.price ?? 0.0
        let priceMode: BulkPriceMode = ndisItem.price != nil ? .ndis : .custom
        
        XCTAssertEqual(rate, 88.00)
        XCTAssertEqual(priceMode, .ndis)
    }
    
    func testIntegrationWithNDISPriceUtilities() {
        // Test integration with NDISPriceUtilities
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_2")
        addRegionalPrice(to: entity, region: "NATIONAL", amount: 50.0)
        
        let ndisItem = NDISItem(from: entity)
        
        // Test utility functions
        let safePrice = NDISPriceUtilities.safePrice(from: ndisItem, fallbackPrice: 0.0)
        let hasValidPrice = NDISPriceUtilities.hasValidPrice(ndisItem)
        let formattedPrice = NDISPriceUtilities.formatPrice(ndisItem.price)
        
        XCTAssertEqual(safePrice, 50.0)
        XCTAssertTrue(hasValidPrice)
        XCTAssertTrue(formattedPrice.contains("50.00"))
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandlingScenarios() {
        // Test error handling with invalid data
        let errorScenarios = [
            PriceMappingScenario(
                name: "All zero prices",
                prices: [("NATIONAL", 0.0), ("NSW", 0.0), ("VIC", 0.0)],
                expectedPrice: nil,
                expectedRegion: nil
            ),
            PriceMappingScenario(
                name: "All negative prices",
                prices: [("NATIONAL", -10.0), ("NSW", -5.0), ("VIC", -15.0)],
                expectedPrice: nil,
                expectedRegion: nil
            ),
            PriceMappingScenario(
                name: "Mixed valid and invalid",
                prices: [("NATIONAL", 0.0), ("NSW", -5.0), ("VIC", 55.0)],
                expectedPrice: 55.0,
                expectedRegion: "VIC"
            )
        ]
        
        for scenario in errorScenarios {
            runPriceMappingScenario(scenario)
        }
    }
    
    // MARK: - Private Helpers
    
    private func runPriceMappingScenario(_ scenario: PriceMappingScenario) {
        // Create NDIS item entity
        let entity = createNDISItemEntity(itemNumber: "01_001_0107_1_\(scenario.name.hashValue)")
        
        // Add regional prices
        for (region, amount) in scenario.prices {
            addRegionalPrice(to: entity, region: region, amount: amount)
        }
        
        // Convert to domain model
        let ndisItem = NDISItem(from: entity)
        
        // Verify price extraction
        XCTAssertEqual(
            ndisItem.price,
            scenario.expectedPrice,
            "Price extraction failed for scenario: \(scenario.name)"
        )
        
        // Verify region priority if expected
        if let expectedRegion = scenario.expectedRegion {
            let expectedPrice = scenario.prices.first { $0.region == expectedRegion }?.amount
            XCTAssertEqual(
                ndisItem.price,
                expectedPrice,
                "Region priority failed for scenario: \(scenario.name)"
            )
        }
    }
    
    private func createNDISItemEntity(itemNumber: String) -> NDISItemEntity {
        let entity = NDISItemEntity(id: UUID())
        entity.itemNumber = itemNumber
        entity.name = "Test Item"
        entity.description = "Test Description"
        entity.category = "Test Category"
        entity.unit = "hour"
        entity.isCurrent = true
        entity.status = "Active"
        entity.type = "Support Item"
        entity.categoryNamePACE = "Test PACE Category"
        entity.categoryNumber = "01"
        entity.categoryNumberPACE = "01"
        entity.effectiveStartDate = Date()
        entity.effectiveEndDate = Date().addingTimeInterval(365 * 24 * 60 * 60)
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
    
    private func addRegionalPrice(to item: NDISItemEntity, region: String, amount: Double) -> RegionalPriceEntity {
        let priceEntity = RegionalPriceEntity(id: UUID())
        priceEntity.regionIdentifier = region
        priceEntity.amount = amount
        priceEntity.ndisItem = item
        modelContext.insert(priceEntity)
        try! modelContext.save()
        return priceEntity
    }
}

// MARK: - Supporting Types

private struct PriceMappingScenario {
    let name: String
    let prices: [(region: String, amount: Double)]
    let expectedPrice: Double?
    let expectedRegion: String?
}

// MARK: - Mock Types for Testing

private enum BulkPriceMode: CaseIterable {
    case ndis
    case custom
}
