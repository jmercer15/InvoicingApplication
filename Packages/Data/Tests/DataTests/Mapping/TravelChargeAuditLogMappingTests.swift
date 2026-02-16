import XCTest
import SwiftData
import Core
@testable import Data

/// Tests for TravelChargeAuditLog mapping with real data scenarios
@MainActor
final class TravelChargeAuditLogMappingTests: XCTestCase {
    
    private var modelContext: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model context for testing
        let models: [any PersistentModel.Type] = [
            TravelChargeAuditLogEntity.self,
            TravelChargeEntity.self
        ]
        let (_, context) = try ModelContainerFactory.makeInMemoryContext(models: models)
        modelContext = context
    }
    
    override func tearDown() async throws {
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Test Data Setup
    
    private func createTravelChargeEntity(id: UUID = UUID()) -> TravelChargeEntity {
        let entity = TravelChargeEntity(id: id)
        entity.mmmZoneName = "Zone 1"
        entity.travelDistance = 25.0
        entity.travelDuration = 1800.0
        entity.vehicleType = "Car"
        entity.parkingCost = 10.0
        entity.tollCost = 5.0
        entity.participantCount = 1
        entity.splitCosts = false
        entity.chargeType = "Travel"
        entity.travelDirection = "Return"
        entity.calendarIdentifier = "travel-calendar"
        entity.ekCreationDate = Date()
        entity.ekEventAvailabilityRaw = 0
        entity.ekEventStatusRaw = 0
        entity.ekRecurrenceRuleDescription = nil
        entity.endTime = Date().addingTimeInterval(3600)
        entity.eventIdentifier = "travel-event-\(id.uuidString)"
        entity.hasEKAlarms = false
        entity.alarmsData = nil
        entity.isAllDay = false
        entity.isDetached = false
        entity.lastModifiedDate = Date()
        entity.lastSyncTag = "travel-sync"
        entity.location = "Home to Office"
        entity.notes = "Travel charge. Status: pending"
        entity.organizerName = "Support Worker"
        entity.organizerURL = nil
        entity.occurrenceDate = nil
        entity.recurrenceRuleData = nil
        entity.calendarSourceIdentifier = "travel-source"
        entity.startTime = Date()
        entity.timeZone = "Australia/Sydney"
        entity.title = "Travel Charge"
        entity.url = nil
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
    
    private func createTravelChargeAuditLogEntity(
        id: UUID = UUID(),
        charge: TravelChargeEntity? = nil,
        action: String = "created",
        timestamp: Date = Date(),
        details: String? = nil,
        summary: String? = nil
    ) -> TravelChargeAuditLogEntity {
        let entity = TravelChargeAuditLogEntity(id: id)
        entity.charge = charge
        entity.action = action
        entity.timestamp = timestamp
        entity.details = details
        entity.summary = summary
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
    
    // MARK: - Entity to Domain Mapping Tests
    
    func testTravelChargeAuditLogMappingFromEntity() {
        // Given: TravelChargeAuditLogEntity with all properties
        let travelCharge = createTravelChargeEntity()
        let entity = createTravelChargeAuditLogEntity(
            charge: travelCharge,
            action: "approved",
            timestamp: Date(),
            details: "Travel charge approved by supervisor",
            summary: "Supervisor Name"
        )
        
        // When: Convert to domain model
        let auditLog = TravelChargeAuditLog(from: entity)
        
        // Then: All properties should be mapped correctly
        XCTAssertEqual(auditLog.id, entity.id)
        XCTAssertEqual(auditLog.travelChargeId, travelCharge.id)
        XCTAssertEqual(auditLog.action, "approved")
        XCTAssertEqual(auditLog.timestamp, entity.timestamp)
        XCTAssertEqual(auditLog.details, "Travel charge approved by supervisor")
        XCTAssertEqual(auditLog.performedBy, "Supervisor Name") // summary mapped to performedBy
    }
    
    func testTravelChargeAuditLogMappingWithMinimalData() {
        // Given: TravelChargeAuditLogEntity with minimal data
        let entity = TravelChargeAuditLogEntity(id: UUID())
        entity.charge = nil
        entity.action = nil
        entity.timestamp = nil
        entity.details = nil
        entity.summary = nil
        
        modelContext.insert(entity)
        try! modelContext.save()
        
        // When: Convert to domain model
        let auditLog = TravelChargeAuditLog(from: entity)
        
        // Then: Should handle nil values gracefully
        XCTAssertEqual(auditLog.id, entity.id)
        XCTAssertEqual(auditLog.travelChargeId, UUID()) // Default UUID when no charge
        XCTAssertEqual(auditLog.action, "unknown") // Default action
        XCTAssertEqual(auditLog.timestamp, Date()) // Default timestamp
        XCTAssertNil(auditLog.details)
        XCTAssertNil(auditLog.performedBy)
    }
    
    // MARK: - Domain to Entity Mapping Tests
    
    func testTravelChargeAuditLogEntityUpdateFromDomain() {
        // Given: Domain model with all properties
        let auditLog = TravelChargeAuditLog(
            id: UUID(),
            travelChargeId: UUID(),
            action: "rejected",
            timestamp: Date(),
            details: "Travel charge rejected due to insufficient documentation",
            performedBy: "Manager Name"
        )
        
        // When: Update entity from domain model
        let entity = TravelChargeAuditLogEntity(id: auditLog.id)
        entity.update(from: auditLog)
        
        // Then: All properties should be updated correctly
        XCTAssertEqual(entity.id, auditLog.id)
        XCTAssertEqual(entity.action, "rejected")
        XCTAssertEqual(entity.timestamp, auditLog.timestamp)
        XCTAssertEqual(entity.details, "Travel charge rejected due to insufficient documentation")
        XCTAssertEqual(entity.summary, "Manager Name") // performedBy mapped to summary
    }
    
    func testTravelChargeAuditLogEntityUpdateWithNilValues() {
        // Given: Domain model with nil values
        let auditLog = TravelChargeAuditLog(
            id: UUID(),
            travelChargeId: UUID(),
            action: "created",
            timestamp: Date(),
            details: nil,
            performedBy: nil
        )
        
        // When: Update entity from domain model
        let entity = TravelChargeAuditLogEntity(id: auditLog.id)
        entity.update(from: auditLog)
        
        // Then: Nil values should be handled correctly
        XCTAssertEqual(entity.id, auditLog.id)
        XCTAssertEqual(entity.action, "created")
        XCTAssertEqual(entity.timestamp, auditLog.timestamp)
        XCTAssertNil(entity.details)
        XCTAssertNil(entity.summary)
    }
    
    // MARK: - Real-World Scenarios
    
    func testRealWorldScenario_TravelChargeApproval() {
        // Given: Real-world approval scenario
        let travelCharge = createTravelChargeEntity()
        let entity = createTravelChargeAuditLogEntity(
            charge: travelCharge,
            action: "approved",
            timestamp: Date(),
            details: "Travel charge approved by NDIS coordinator. Distance: 25km, Duration: 30 minutes, Cost: $15.50",
            summary: "NDIS Coordinator - Jane Smith"
        )
        
        // When: Convert to domain model
        let auditLog = TravelChargeAuditLog(from: entity)
        
        // Then: Should map approval scenario correctly
        XCTAssertEqual(auditLog.id, entity.id)
        XCTAssertEqual(auditLog.travelChargeId, travelCharge.id)
        XCTAssertEqual(auditLog.action, "approved")
        XCTAssertEqual(auditLog.details, "Travel charge approved by NDIS coordinator. Distance: 25km, Duration: 30 minutes, Cost: $15.50")
        XCTAssertEqual(auditLog.performedBy, "NDIS Coordinator - Jane Smith")
    }
    
    func testRealWorldScenario_TravelChargeRejection() {
        // Given: Real-world rejection scenario
        let travelCharge = createTravelChargeEntity()
        let entity = createTravelChargeAuditLogEntity(
            charge: travelCharge,
            action: "rejected",
            timestamp: Date(),
            details: "Travel charge rejected: Missing receipt for parking cost. Please provide valid receipt and resubmit.",
            summary: "Finance Manager - John Doe"
        )
        
        // When: Convert to domain model
        let auditLog = TravelChargeAuditLog(from: entity)
        
        // Then: Should map rejection scenario correctly
        XCTAssertEqual(auditLog.id, entity.id)
        XCTAssertEqual(auditLog.travelChargeId, travelCharge.id)
        XCTAssertEqual(auditLog.action, "rejected")
        XCTAssertEqual(auditLog.details, "Travel charge rejected: Missing receipt for parking cost. Please provide valid receipt and resubmit.")
        XCTAssertEqual(auditLog.performedBy, "Finance Manager - John Doe")
    }
    
    func testRealWorldScenario_TravelChargeModification() {
        // Given: Real-world modification scenario
        let travelCharge = createTravelChargeEntity()
        let entity = createTravelChargeAuditLogEntity(
            charge: travelCharge,
            action: "modified",
            timestamp: Date(),
            details: "Travel charge modified: Distance updated from 20km to 25km, cost adjusted from $12.00 to $15.50",
            summary: "Support Worker - Sarah Johnson"
        )
        
        // When: Convert to domain model
        let auditLog = TravelChargeAuditLog(from: entity)
        
        // Then: Should map modification scenario correctly
        XCTAssertEqual(auditLog.id, entity.id)
        XCTAssertEqual(auditLog.travelChargeId, travelCharge.id)
        XCTAssertEqual(auditLog.action, "modified")
        XCTAssertEqual(auditLog.details, "Travel charge modified: Distance updated from 20km to 25km, cost adjusted from $12.00 to $15.50")
        XCTAssertEqual(auditLog.performedBy, "Support Worker - Sarah Johnson")
    }
    
    // MARK: - Edge Cases
    
    func testEdgeCase_EmptyAction() {
        // Given: Entity with empty action
        let entity = TravelChargeAuditLogEntity(id: UUID())
        entity.action = ""
        entity.timestamp = Date()
        
        modelContext.insert(entity)
        try! modelContext.save()
        
        // When: Convert to domain model
        let auditLog = TravelChargeAuditLog(from: entity)
        
        // Then: Should default to "unknown"
        XCTAssertEqual(auditLog.action, "unknown")
    }
    
    func testEdgeCase_InvalidAction() {
        // Given: Entity with invalid action
        let entity = TravelChargeAuditLogEntity(id: UUID())
        entity.action = "invalid_action"
        entity.timestamp = Date()
        
        modelContext.insert(entity)
        try! modelContext.save()
        
        // When: Convert to domain model
        let auditLog = TravelChargeAuditLog(from: entity)
        
        // Then: Should preserve the action as-is
        XCTAssertEqual(auditLog.action, "invalid_action")
    }
    
    func testEdgeCase_LongDetails() {
        // Given: Entity with very long details
        let longDetails = String(repeating: "This is a very long detail string. ", count: 100)
        let entity = createTravelChargeAuditLogEntity(
            action: "created",
            details: longDetails,
            summary: "Test User"
        )
        
        // When: Convert to domain model
        let auditLog = TravelChargeAuditLog(from: entity)
        
        // Then: Should handle long details correctly
        XCTAssertEqual(auditLog.details, longDetails)
        XCTAssertEqual(auditLog.performedBy, "Test User")
    }
    
    // MARK: - Performance Tests
    
    func testMappingPerformance() {
        // Given: Large number of audit log entities
        let travelCharge = createTravelChargeEntity()
        var entities: [TravelChargeAuditLogEntity] = []
        
        for i in 0..<1000 {
            let entity = createTravelChargeAuditLogEntity(
                charge: travelCharge,
                action: "action_\(i)",
                details: "Detail \(i)",
                summary: "User \(i)"
            )
            entities.append(entity)
        }
        
        // When: Convert all to domain models and measure performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let auditLogs = entities.map { TravelChargeAuditLog(from: $0) }
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then: Should complete in reasonable time
        XCTAssertLessThan(timeElapsed, 1.0, "Mapping 1000 audit logs should complete in less than 1 second")
        XCTAssertEqual(auditLogs.count, 1000)
    }
    
    // MARK: - Integration Tests
    
    func testIntegrationWithTravelCharge() {
        // Given: Audit log linked to travel charge
        let travelCharge = createTravelChargeEntity()
        let entity = createTravelChargeAuditLogEntity(
            charge: travelCharge,
            action: "approved",
            details: "Approved by supervisor",
            summary: "Supervisor"
        )
        
        // When: Convert to domain model
        let auditLog = TravelChargeAuditLog(from: entity)
        
        // Then: Should maintain relationship
        XCTAssertEqual(auditLog.travelChargeId, travelCharge.id)
    }
    
    func testIntegrationWithRepository() {
        // Given: Audit log entity in context
        let entity = createTravelChargeAuditLogEntity(
            action: "created",
            details: "Travel charge created",
            summary: "System"
        )
        
        // When: Convert to domain model
        let auditLog = TravelChargeAuditLog(from: entity)
        
        // Then: Should be compatible with repository operations
        XCTAssertNotNil(auditLog.id)
        XCTAssertNotNil(auditLog.timestamp)
        XCTAssertNotNil(auditLog.action)
    }
}

// MARK: - Test Helpers

extension TravelChargeAuditLogMappingTests {
    
    /// Helper to create a test scenario with specific properties
    private func createTestScenario(
        id: UUID = UUID(),
        travelChargeId: UUID = UUID(),
        action: String = "created",
        timestamp: Date = Date(),
        details: String? = nil,
        performedBy: String? = nil
    ) -> TravelChargeAuditLog {
        return TravelChargeAuditLog(
            id: id,
            travelChargeId: travelChargeId,
            action: action,
            timestamp: timestamp,
            details: details,
            performedBy: performedBy
        )
    }
    
    /// Helper to verify mapping works correctly
    private func verifyMapping(
        entity: TravelChargeAuditLogEntity,
        expectedAction: String,
        expectedDetails: String?,
        expectedPerformedBy: String?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let auditLog = TravelChargeAuditLog(from: entity)
        XCTAssertEqual(auditLog.action, expectedAction, file: file, line: line)
        XCTAssertEqual(auditLog.details, expectedDetails, file: file, line: line)
        XCTAssertEqual(auditLog.performedBy, expectedPerformedBy, file: file, line: line)
    }
}
