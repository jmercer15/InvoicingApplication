import XCTest
import SwiftData
import Core
@testable import Data

/// Comprehensive tests for TravelCharge mapping with real data scenarios
/// Tests the entity-to-domain and domain-to-entity mapping logic
@MainActor
final class TravelChargeMappingTests: XCTestCase {
    
    private var modelContext: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model context for testing
        let models: [any PersistentModel.Type] = [
            TravelChargeEntity.self,
            SessionEntity.self,
            ClientEntity.self,
            ClientServiceEntity.self,
            TravelChargeAuditLogEntity.self,
            TravelChargeReviewItemEntity.self
        ]
        let (_, context) = try ModelContainerFactory.makeInMemoryContext(models: models)
        modelContext = context
    }
    
    override func tearDown() async throws {
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Test Data Setup
    
    private func createSessionEntity(
        id: UUID = UUID(),
        title: String = "Test Session",
        startTime: Date = Date(),
        endTime: Date = Date().addingTimeInterval(3600) // 1 hour later
    ) -> SessionEntity {
        let entity = SessionEntity(id: id)
        entity.title = title
        entity.startTime = startTime
        entity.endTime = endTime
        entity.isAllDay = false
        entity.location = "Test Location"
        entity.notes = "Test session notes"
        entity.status = .completed
        entity.isTravel = false
        entity.attendeesCount = 1
        entity.derivedFromEKEventID = "test-event-id"
        entity.googleColorId = "test-color"
        entity.groupID = nil
        entity.groupedPosition = 0
        entity.sessionLatitude = 0.0
        entity.sessionLongitude = 0.0
        entity.calendarIdentifier = "test-calendar"
        entity.ekCreationDate = Date()
        entity.ekEventAvailabilityRaw = 0
        entity.ekEventStatusRaw = 0
        entity.ekRecurrenceRuleDescription = nil
        entity.eventIdentifier = "test-event"
        entity.hasEKAlarms = false
        entity.alarmsData = nil
        entity.isDetached = false
        entity.lastModifiedDate = Date()
        entity.lastSyncTag = "test-sync"
        entity.organizerName = "Test Organizer"
        entity.organizerURL = nil
        entity.occurrenceDate = nil
        entity.recurrenceRuleData = nil
        entity.calendarSourceIdentifier = "test-source"
        entity.timeZone = "Australia/Sydney"
        entity.url = nil
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
    
    private func createClientEntity(
        id: UUID = UUID(),
        ndisNumber: String = "123456789",
        fullName: String = "Test Client"
    ) -> ClientEntity {
        let entity = ClientEntity(id: id, ndisNumber: ndisNumber, fullName: fullName, status: .active)
        entity.email = "test@example.com"
        entity.notes = "Test client notes"
        entity.phone = "0412345678"
        entity.creditAmount = 100.0
        entity.isMinor = false
        entity.hasNdisPlan = true
        entity.planManagementType = "Self Managed"
        entity.billingAuthority = .client
        entity.sendInvoicesToClient = true
        entity.sendInvoicesToPayee = false
        entity.sendInvoicesToPlanManager = false
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
    
    private func createClientServiceEntity(
        id: UUID = UUID(),
        serviceName: String = "Test Service",
        unit: String = "hour",
        rate: Double = 50.0
    ) -> ClientServiceEntity {
        let entity = ClientServiceEntity(id: id, serviceName: serviceName, unit: unit, rate: rate)
        entity.supportItemNumber = "01_001_0107_1_1"
        entity.ndisCode = "01_001_0107_1_1"
        entity.startDate = Date()
        entity.endDate = Date().addingTimeInterval(365 * 24 * 60 * 60) // 1 year from now
        entity.quantity = 1.0
        entity.isActive = true
        entity.notes = "Test service notes"
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
    
    private func createTravelChargeEntity(
        id: UUID = UUID(),
        session: SessionEntity? = nil,
        client: ClientEntity? = nil,
        service: ClientServiceEntity? = nil
    ) -> TravelChargeEntity {
        let entity = TravelChargeEntity(id: id)
        
        // Travel-specific properties
        entity.mmmZoneName = "Zone 1"
        entity.travelDistance = 25.5
        entity.travelDuration = 1800.0 // 30 minutes
        entity.vehicleType = "Car"
        entity.parkingCost = 5.0
        entity.tollCost = 3.50
        entity.participantCount = 1
        entity.splitCosts = false
        entity.chargeType = "Travel"
        entity.travelDirection = "Return"
        
        // Relationships
        entity.linkedSession = session
        entity.client = client
        entity.service = service
        
        // EventRepresentable properties
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
        entity.location = "123 Main St, Sydney NSW 2000 to 456 Queen St, Melbourne VIC 3000"
        entity.notes = "Travel from client home to community center. Status: pending"
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
    
    // MARK: - Entity to Domain Mapping Tests
    
    func testTravelChargeMappingFromEntity() {
        // Given: TravelChargeEntity with all properties set
        let session = createSessionEntity()
        let client = createClientEntity()
        let service = createClientServiceEntity()
        let entity = createTravelChargeEntity(session: session, client: client, service: service)
        
        // When: Convert to domain model
        let travelCharge = TravelCharge(from: entity)
        
        // Then: All properties should be mapped correctly
        XCTAssertEqual(travelCharge.id, entity.id)
        XCTAssertEqual(travelCharge.sessionId, session.id)
        XCTAssertEqual(travelCharge.amount, 5.0) // parkingCost mapped to amount
        XCTAssertEqual(travelCharge.distance, 25.5)
        XCTAssertEqual(travelCharge.travelTime, 1800.0)
        XCTAssertEqual(travelCharge.fromAddress, "123 Main St, Sydney NSW 2000")
        XCTAssertEqual(travelCharge.toAddress, "456 Queen St, Melbourne VIC 3000")
        XCTAssertEqual(travelCharge.status, .pending) // Extracted from notes
        XCTAssertEqual(travelCharge.createdDate, entity.ekCreationDate)
        XCTAssertEqual(travelCharge.lastModifiedDate, entity.lastModifiedDate)
        XCTAssertEqual(travelCharge.notes, "Travel from client home to community center. Status: pending")
    }
    
    func testTravelChargeMappingWithMinimalData() {
        // Given: TravelChargeEntity with minimal data
        let entity = TravelChargeEntity(id: UUID())
        entity.mmmZoneName = nil
        entity.travelDistance = nil
        entity.travelDuration = nil
        entity.vehicleType = nil
        entity.parkingCost = nil
        entity.tollCost = nil
        entity.participantCount = nil
        entity.splitCosts = nil
        entity.chargeType = nil
        entity.travelDirection = nil
        entity.linkedSession = nil
        entity.client = nil
        entity.service = nil
        entity.calendarIdentifier = nil
        entity.ekCreationDate = nil
        entity.ekEventAvailabilityRaw = 0
        entity.ekEventStatusRaw = 0
        entity.ekRecurrenceRuleDescription = nil
        entity.endTime = nil
        entity.eventIdentifier = ""
        entity.hasEKAlarms = false
        entity.alarmsData = nil
        entity.isAllDay = false
        entity.isDetached = false
        entity.lastModifiedDate = nil
        entity.lastSyncTag = nil
        entity.location = nil
        entity.notes = nil
        entity.organizerName = nil
        entity.organizerURL = nil
        entity.occurrenceDate = nil
        entity.recurrenceRuleData = nil
        entity.calendarSourceIdentifier = nil
        entity.startTime = nil
        entity.timeZone = nil
        entity.title = ""
        entity.url = nil
        
        modelContext.insert(entity)
        try! modelContext.save()
        
        // When: Convert to domain model
        let travelCharge = TravelCharge(from: entity)
        
        // Then: Should handle nil values gracefully
        XCTAssertEqual(travelCharge.id, entity.id)
        XCTAssertEqual(travelCharge.sessionId, UUID()) // Default UUID when no session
        XCTAssertEqual(travelCharge.amount, 0.0) // Default when parkingCost is nil
        XCTAssertNil(travelCharge.distance)
        XCTAssertNil(travelCharge.travelTime)
        XCTAssertNil(travelCharge.fromAddress)
        XCTAssertNil(travelCharge.toAddress)
        XCTAssertEqual(travelCharge.status, .pending) // Default status
        XCTAssertEqual(travelCharge.createdDate, Date()) // Default date when ekCreationDate is nil
        XCTAssertNil(travelCharge.lastModifiedDate)
        XCTAssertNil(travelCharge.notes)
    }
    
    func testTravelChargeMappingWithLocationParsing() {
        // Given: TravelChargeEntity with different location formats
        let testCases = [
            ("123 Main St, Sydney NSW 2000 to 456 Queen St, Melbourne VIC 3000", "123 Main St, Sydney NSW 2000", "456 Queen St, Melbourne VIC 3000"),
            ("Home to Office", "Home", "Office"),
            ("Single Location", "Single Location", nil),
            ("", nil, nil),
            (nil, nil, nil)
        ]
        
        for (location, expectedFrom, expectedTo) in testCases {
            let entity = TravelChargeEntity(id: UUID())
            entity.location = location
            entity.ekCreationDate = Date()
            
            modelContext.insert(entity)
            try! modelContext.save()
            
            // When: Convert to domain model
            let travelCharge = TravelCharge(from: entity)
            
            // Then: Location should be parsed correctly
            XCTAssertEqual(travelCharge.fromAddress, expectedFrom, "Failed for location: \(location ?? "nil")")
            XCTAssertEqual(travelCharge.toAddress, expectedTo, "Failed for location: \(location ?? "nil")")
        }
    }
    
    func testTravelChargeMappingWithStatusExtraction() {
        // Given: TravelChargeEntity with different status formats in notes
        let testCases = [
            ("Travel notes. Status: approved", TravelChargeStatus.approved),
            ("Status: pending. More notes", TravelChargeStatus.pending),
            ("Status: rejected", TravelChargeStatus.rejected),
            ("No status here", TravelChargeStatus.pending), // Default
            (nil, TravelChargeStatus.pending) // Default
        ]
        
        for (notes, expectedStatus) in testCases {
            let entity = TravelChargeEntity(id: UUID())
            entity.notes = notes
            entity.ekCreationDate = Date()
            
            modelContext.insert(entity)
            try! modelContext.save()
            
            // When: Convert to domain model
            let travelCharge = TravelCharge(from: entity)
            
            // Then: Status should be extracted correctly
            XCTAssertEqual(travelCharge.status, expectedStatus, "Failed for notes: \(notes ?? "nil")")
        }
    }
    
    // MARK: - Domain to Entity Mapping Tests
    
    func testTravelChargeEntityUpdateFromDomain() {
        // Given: Domain model with all properties
        let sessionId = UUID()
        let travelCharge = TravelCharge(
            id: UUID(),
            sessionId: sessionId,
            amount: 15.50,
            distance: 30.0,
            travelTime: 2400.0, // 40 minutes
            fromAddress: "Client Home",
            toAddress: "Community Center",
            status: .approved,
            createdDate: Date(),
            lastModifiedDate: Date(),
            notes: "Travel to community center for social activities"
        )
        
        // When: Update entity from domain model
        let entity = TravelChargeEntity(id: travelCharge.id)
        entity.update(from: travelCharge)
        
        // Then: All properties should be updated correctly
        XCTAssertEqual(entity.id, travelCharge.id)
        XCTAssertEqual(entity.travelDistance, 30.0)
        XCTAssertEqual(entity.travelDuration, 2400.0)
        XCTAssertEqual(entity.parkingCost, 15.50) // amount stored in parkingCost
        XCTAssertEqual(entity.location, "Client Home to Community Center")
        XCTAssertEqual(entity.notes, "Travel to community center for social activities\nStatus: approved")
        XCTAssertEqual(entity.ekCreationDate, travelCharge.createdDate)
        XCTAssertEqual(entity.lastModifiedDate, travelCharge.lastModifiedDate)
    }
    
    func testTravelChargeEntityUpdateWithNilValues() {
        // Given: Domain model with nil values
        let travelCharge = TravelCharge(
            id: UUID(),
            sessionId: UUID(),
            amount: 0.0,
            distance: nil,
            travelTime: nil,
            fromAddress: nil,
            toAddress: nil,
            status: .pending,
            createdDate: Date(),
            lastModifiedDate: nil,
            notes: nil
        )
        
        // When: Update entity from domain model
        let entity = TravelChargeEntity(id: travelCharge.id)
        entity.update(from: travelCharge)
        
        // Then: Nil values should be handled correctly
        XCTAssertEqual(entity.id, travelCharge.id)
        XCTAssertNil(entity.travelDistance)
        XCTAssertNil(entity.travelDuration)
        XCTAssertEqual(entity.parkingCost, 0.0)
        XCTAssertNil(entity.location)
        XCTAssertEqual(entity.notes, "Status: pending")
        XCTAssertEqual(entity.ekCreationDate, travelCharge.createdDate)
        XCTAssertNil(entity.lastModifiedDate)
    }
    
    func testTravelChargeEntityUpdateWithSingleAddress() {
        // Given: Domain model with only from address
        let travelCharge = TravelCharge(
            id: UUID(),
            sessionId: UUID(),
            amount: 10.0,
            distance: 15.0,
            travelTime: 1200.0,
            fromAddress: "Client Home",
            toAddress: nil,
            status: .pending,
            createdDate: Date(),
            lastModifiedDate: Date(),
            notes: "Travel from home"
        )
        
        // When: Update entity from domain model
        let entity = TravelChargeEntity(id: travelCharge.id)
        entity.update(from: travelCharge)
        
        // Then: Single address should be handled correctly
        XCTAssertEqual(entity.location, "Client Home")
        XCTAssertEqual(entity.notes, "Travel from home\nStatus: pending")
    }
    
    // MARK: - Real-World Scenarios
    
    func testRealWorldScenario_ClientHomeToCommunityCenter() {
        // Given: Real-world travel charge scenario
        let session = createSessionEntity(
            title: "Community Access - Social Activities",
            startTime: Date(),
            endTime: Date().addingTimeInterval(7200) // 2 hours
        )
        let client = createClientEntity(
            fullName: "John Smith",
            ndisNumber: "410000123"
        )
        let service = createClientServiceEntity(
            serviceName: "Community Access",
            unit: "hour",
            rate: 75.0
        )
        
        let entity = createTravelChargeEntity(session: session, client: client, service: service)
        entity.mmmZoneName = "Zone 2"
        entity.travelDistance = 12.5
        entity.travelDuration = 1800.0 // 30 minutes
        entity.vehicleType = "Car"
        entity.parkingCost = 8.50
        entity.tollCost = 4.20
        entity.participantCount = 1
        entity.splitCosts = false
        entity.chargeType = "Travel"
        entity.travelDirection = "Return"
        entity.location = "123 Oak Street, Parramatta NSW 2150 to 456 Community Center, Blacktown NSW 2148"
        entity.notes = "Travel from client home to community center for social activities. Status: approved"
        
        // When: Convert to domain model
        let travelCharge = TravelCharge(from: entity)
        
        // Then: Should map all real-world data correctly
        XCTAssertEqual(travelCharge.id, entity.id)
        XCTAssertEqual(travelCharge.sessionId, session.id)
        XCTAssertEqual(travelCharge.amount, 8.50)
        XCTAssertEqual(travelCharge.distance, 12.5)
        XCTAssertEqual(travelCharge.travelTime, 1800.0)
        XCTAssertEqual(travelCharge.fromAddress, "123 Oak Street, Parramatta NSW 2150")
        XCTAssertEqual(travelCharge.toAddress, "456 Community Center, Blacktown NSW 2148")
        XCTAssertEqual(travelCharge.status, .approved)
        XCTAssertEqual(travelCharge.notes, "Travel from client home to community center for social activities. Status: approved")
    }
    
    func testRealWorldScenario_SupportWorkerTravel() {
        // Given: Support worker travel scenario
        let session = createSessionEntity(
            title: "Personal Care - Morning Routine",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600) // 1 hour
        )
        let client = createClientEntity(
            fullName: "Sarah Johnson",
            ndisNumber: "410000456"
        )
        let service = createClientServiceEntity(
            serviceName: "Personal Care",
            unit: "hour",
            rate: 88.0
        )
        
        let entity = createTravelChargeEntity(session: session, client: client, service: service)
        entity.mmmZoneName = "Zone 1"
        entity.travelDistance = 8.2
        entity.travelDuration = 1200.0 // 20 minutes
        entity.vehicleType = "Car"
        entity.parkingCost = 0.0 // No parking cost
        entity.tollCost = 0.0 // No toll cost
        entity.participantCount = 1
        entity.splitCosts = false
        entity.chargeType = "Travel"
        entity.travelDirection = "Return"
        entity.location = "Support Worker Office to 789 Pine Street, Liverpool NSW 2170"
        entity.notes = "Travel from office to client home for personal care session. Status: pending"
        
        // When: Convert to domain model
        let travelCharge = TravelCharge(from: entity)
        
        // Then: Should map support worker travel correctly
        XCTAssertEqual(travelCharge.id, entity.id)
        XCTAssertEqual(travelCharge.sessionId, session.id)
        XCTAssertEqual(travelCharge.amount, 0.0)
        XCTAssertEqual(travelCharge.distance, 8.2)
        XCTAssertEqual(travelCharge.travelTime, 1200.0)
        XCTAssertEqual(travelCharge.fromAddress, "Support Worker Office")
        XCTAssertEqual(travelCharge.toAddress, "789 Pine Street, Liverpool NSW 2170")
        XCTAssertEqual(travelCharge.status, .pending)
        XCTAssertEqual(travelCharge.notes, "Travel from office to client home for personal care session. Status: pending")
    }
    
    func testRealWorldScenario_GroupTravel() {
        // Given: Group travel scenario
        let session = createSessionEntity(
            title: "Group Activity - Art Class",
            startTime: Date(),
            endTime: Date().addingTimeInterval(10800) // 3 hours
        )
        let client = createClientEntity(
            fullName: "Michael Brown",
            ndisNumber: "410000789"
        )
        let service = createClientServiceEntity(
            serviceName: "Group Activities",
            unit: "hour",
            rate: 65.0
        )
        
        let entity = createTravelChargeEntity(session: session, client: client, service: service)
        entity.mmmZoneName = "Zone 3"
        entity.travelDistance = 45.0
        entity.travelDuration = 3600.0 // 1 hour
        entity.vehicleType = "Van"
        entity.parkingCost = 12.0
        entity.tollCost = 8.50
        entity.participantCount = 4
        entity.splitCosts = true
        entity.chargeType = "Group Travel"
        entity.travelDirection = "Return"
        entity.location = "Group Home to Art Gallery, Sydney NSW 2000"
        entity.notes = "Group travel to art gallery for art class. Costs split between 4 participants. Status: approved"
        
        // When: Convert to domain model
        let travelCharge = TravelCharge(from: entity)
        
        // Then: Should map group travel correctly
        XCTAssertEqual(travelCharge.id, entity.id)
        XCTAssertEqual(travelCharge.sessionId, session.id)
        XCTAssertEqual(travelCharge.amount, 12.0)
        XCTAssertEqual(travelCharge.distance, 45.0)
        XCTAssertEqual(travelCharge.travelTime, 3600.0)
        XCTAssertEqual(travelCharge.fromAddress, "Group Home")
        XCTAssertEqual(travelCharge.toAddress, "Art Gallery, Sydney NSW 2000")
        XCTAssertEqual(travelCharge.status, .approved)
        XCTAssertEqual(travelCharge.notes, "Group travel to art gallery for art class. Costs split between 4 participants. Status: approved")
    }
    
    // MARK: - Edge Cases
    
    func testEdgeCase_EmptyLocation() {
        // Given: Entity with empty location
        let entity = TravelChargeEntity(id: UUID())
        entity.location = ""
        entity.ekCreationDate = Date()
        
        modelContext.insert(entity)
        try! modelContext.save()
        
        // When: Convert to domain model
        let travelCharge = TravelCharge(from: entity)
        
        // Then: Should handle empty location gracefully
        XCTAssertNil(travelCharge.fromAddress)
        XCTAssertNil(travelCharge.toAddress)
    }
    
    func testEdgeCase_MalformedLocation() {
        // Given: Entity with malformed location
        let entity = TravelChargeEntity(id: UUID())
        entity.location = "Invalid location format without proper structure"
        entity.ekCreationDate = Date()
        
        modelContext.insert(entity)
        try! modelContext.save()
        
        // When: Convert to domain model
        let travelCharge = TravelCharge(from: entity)
        
        // Then: Should handle malformed location gracefully
        XCTAssertEqual(travelCharge.fromAddress, "Invalid location format without proper structure")
        XCTAssertNil(travelCharge.toAddress)
    }
    
    func testEdgeCase_InvalidStatus() {
        // Given: Entity with invalid status in notes
        let entity = TravelChargeEntity(id: UUID())
        entity.notes = "Travel notes. Status: invalid_status"
        entity.ekCreationDate = Date()
        
        modelContext.insert(entity)
        try! modelContext.save()
        
        // When: Convert to domain model
        let travelCharge = TravelCharge(from: entity)
        
        // Then: Should default to pending status
        XCTAssertEqual(travelCharge.status, .pending)
    }
    
    func testEdgeCase_NegativeValues() {
        // Given: Entity with negative values
        let entity = TravelChargeEntity(id: UUID())
        entity.travelDistance = -10.0
        entity.travelDuration = -600.0
        entity.parkingCost = -5.0
        entity.tollCost = -2.0
        entity.ekCreationDate = Date()
        
        modelContext.insert(entity)
        try! modelContext.save()
        
        // When: Convert to domain model
        let travelCharge = TravelCharge(from: entity)
        
        // Then: Should preserve negative values (business logic decision)
        XCTAssertEqual(travelCharge.distance, -10.0)
        XCTAssertEqual(travelCharge.travelTime, -600.0)
        XCTAssertEqual(travelCharge.amount, -5.0)
    }
    
    // MARK: - Performance Tests
    
    func testMappingPerformance() {
        // Given: Large number of travel charge entities
        var entities: [TravelChargeEntity] = []
        for i in 0..<1000 {
            let entity = createTravelChargeEntity()
            entity.notes = "Travel charge \(i). Status: pending"
            entities.append(entity)
        }
        
        // When: Convert all to domain models and measure performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let travelCharges = entities.map { TravelCharge(from: $0) }
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then: Should complete in reasonable time
        XCTAssertLessThan(timeElapsed, 1.0, "Mapping 1000 travel charges should complete in less than 1 second")
        XCTAssertEqual(travelCharges.count, 1000)
    }
    
    // MARK: - Integration Tests
    
    func testIntegrationWithRepository() {
        // Given: Travel charge entity in context
        let session = createSessionEntity()
        let client = createClientEntity()
        let service = createClientServiceEntity()
        let entity = createTravelChargeEntity(session: session, client: client, service: service)
        
        // When: Convert to domain model
        let travelCharge = TravelCharge(from: entity)
        
        // Then: Should be compatible with repository operations
        XCTAssertNotNil(travelCharge.id)
        XCTAssertNotNil(travelCharge.sessionId)
        XCTAssertNotNil(travelCharge.createdDate)
    }
    
    func testIntegrationWithUseCases() {
        // Given: Domain model
        let travelCharge = TravelCharge(
            id: UUID(),
            sessionId: UUID(),
            amount: 20.0,
            distance: 25.0,
            travelTime: 1800.0,
            fromAddress: "Home",
            toAddress: "Office",
            status: .pending,
            createdDate: Date(),
            lastModifiedDate: Date(),
            notes: "Test travel"
        )
        
        // When: Update entity from domain model
        let entity = TravelChargeEntity(id: travelCharge.id)
        entity.update(from: travelCharge)
        
        // Then: Should be compatible with use case operations
        XCTAssertEqual(entity.id, travelCharge.id)
        XCTAssertEqual(entity.parkingCost, travelCharge.amount)
        XCTAssertEqual(entity.travelDistance, travelCharge.distance)
        XCTAssertEqual(entity.travelDuration, travelCharge.travelTime)
    }
}

// MARK: - Test Helpers

extension TravelChargeMappingTests {
    
    /// Helper to create a test scenario with specific properties
    private func createTestScenario(
        id: UUID = UUID(),
        amount: Double = 10.0,
        distance: Double? = 20.0,
        travelTime: TimeInterval? = 1800.0,
        fromAddress: String? = "Home",
        toAddress: String? = "Office",
        status: TravelChargeStatus = .pending,
        notes: String? = "Test travel"
    ) -> TravelCharge {
        return TravelCharge(
            id: id,
            sessionId: UUID(),
            amount: amount,
            distance: distance,
            travelTime: travelTime,
            fromAddress: fromAddress,
            toAddress: toAddress,
            status: status,
            createdDate: Date(),
            lastModifiedDate: Date(),
            notes: notes
        )
    }
    
    /// Helper to verify mapping works correctly
    private func verifyMapping(
        entity: TravelChargeEntity,
        expectedAmount: Double,
        expectedDistance: Double?,
        expectedTravelTime: TimeInterval?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let travelCharge = TravelCharge(from: entity)
        XCTAssertEqual(travelCharge.amount, expectedAmount, file: file, line: line)
        XCTAssertEqual(travelCharge.distance, expectedDistance, file: file, line: line)
        XCTAssertEqual(travelCharge.travelTime, expectedTravelTime, file: file, line: line)
    }
}
