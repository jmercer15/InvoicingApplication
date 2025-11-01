import XCTest
import SwiftData
import Core
@testable import Data

/// Tests for TravelChargeReviewItem mapping with real data scenarios
@MainActor
final class TravelChargeReviewItemMappingTests: XCTestCase {
    
    private var modelContext: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model context for testing
        let schema = Schema([
            TravelChargeReviewItemEntity.self,
            SessionEntity.self
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
    
    private func createSessionEntity(id: UUID = UUID()) -> SessionEntity {
        let entity = SessionEntity(id: id)
        entity.title = "Test Session"
        entity.startTime = Date()
        entity.endTime = Date().addingTimeInterval(3600)
        entity.isAllDay = false
        entity.location = "Test Location"
        entity.notes = "Test session notes"
        entity.status = "completed"
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
        entity.endTime = Date().addingTimeInterval(3600)
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
        entity.startTime = Date()
        entity.timeZone = "Australia/Sydney"
        entity.url = nil
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
    
    private func createTravelChargeReviewItemEntity(
        id: UUID = UUID(),
        session: SessionEntity? = nil,
        hasViolations: Bool = false,
        violations: [String]? = nil,
        timestamp: Date = Date(),
        overrideReason: String? = nil,
        status: String = "pending"
    ) -> TravelChargeReviewItemEntity {
        let entity = TravelChargeReviewItemEntity(id: id)
        entity.session = session
        entity.hasViolations = hasViolations
        entity.violations = violations
        entity.timestamp = timestamp
        entity.overrideReason = overrideReason
        entity.status = status
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
    
    // MARK: - Entity to Domain Mapping Tests
    
    func testTravelChargeReviewItemMappingFromEntity() {
        // Given: TravelChargeReviewItemEntity with all properties
        let session = createSessionEntity()
        let entity = createTravelChargeReviewItemEntity(
            session: session,
            hasViolations: true,
            violations: ["Distance exceeds maximum allowed", "Missing receipt"],
            timestamp: Date(),
            overrideReason: "Reviewer Name",
            status: "resolved"
        )
        
        // When: Convert to domain model
        let reviewItem = TravelChargeReviewItem(from: entity)
        
        // Then: All properties should be mapped correctly
        XCTAssertEqual(reviewItem.id, entity.id)
        XCTAssertEqual(reviewItem.travelChargeId, session.id) // session ID mapped to travelChargeId
        XCTAssertEqual(reviewItem.hasViolations, true)
        XCTAssertEqual(reviewItem.violationDescription, "Distance exceeds maximum allowed") // First violation
        XCTAssertEqual(reviewItem.reviewDate, entity.timestamp)
        XCTAssertEqual(reviewItem.reviewedBy, "Reviewer Name") // overrideReason mapped to reviewedBy
    }
    
    func testTravelChargeReviewItemMappingWithMinimalData() {
        // Given: TravelChargeReviewItemEntity with minimal data
        let entity = createTravelChargeReviewItemEntity()
        entity.session = nil
        entity.hasViolations = false
        entity.violations = nil
        entity.timestamp = nil
        entity.overrideReason = nil
        entity.status = "pending"
        
        modelContext.insert(entity)
        try! modelContext.save()
        
        // When: Convert to domain model
        let reviewItem = TravelChargeReviewItem(from: entity)
        
        // Then: Should handle nil values gracefully
        XCTAssertEqual(reviewItem.id, entity.id)
        XCTAssertEqual(reviewItem.travelChargeId, UUID()) // Default UUID when no session
        XCTAssertEqual(reviewItem.hasViolations, false)
        XCTAssertNil(reviewItem.violationDescription)
        XCTAssertEqual(reviewItem.reviewDate, Date()) // Default date when timestamp is nil
        XCTAssertNil(reviewItem.reviewedBy)
    }
    
    func testTravelChargeReviewItemMappingWithNoViolations() {
        // Given: TravelChargeReviewItemEntity with no violations
        let session = createSessionEntity()
        let entity = createTravelChargeReviewItemEntity(
            session: session,
            hasViolations: false,
            violations: nil,
            timestamp: Date(),
            overrideReason: "Approved by supervisor",
            status: "approved"
        )
        
        // When: Convert to domain model
        let reviewItem = TravelChargeReviewItem(from: entity)
        
        // Then: Should map no violations correctly
        XCTAssertEqual(reviewItem.id, entity.id)
        XCTAssertEqual(reviewItem.travelChargeId, session.id)
        XCTAssertEqual(reviewItem.hasViolations, false)
        XCTAssertNil(reviewItem.violationDescription)
        XCTAssertEqual(reviewItem.reviewDate, entity.timestamp)
        XCTAssertEqual(reviewItem.reviewedBy, "Approved by supervisor")
    }
    
    func testTravelChargeReviewItemMappingWithMultipleViolations() {
        // Given: TravelChargeReviewItemEntity with multiple violations
        let session = createSessionEntity()
        let violations = [
            "Distance exceeds maximum allowed",
            "Missing receipt for parking cost",
            "Travel time seems excessive for distance"
        ]
        let entity = createTravelChargeReviewItemEntity(
            session: session,
            hasViolations: true,
            violations: violations,
            timestamp: Date(),
            overrideReason: "Reviewer - John Smith",
            status: "pending"
        )
        
        // When: Convert to domain model
        let reviewItem = TravelChargeReviewItem(from: entity)
        
        // Then: Should map first violation as description
        XCTAssertEqual(reviewItem.id, entity.id)
        XCTAssertEqual(reviewItem.travelChargeId, session.id)
        XCTAssertEqual(reviewItem.hasViolations, true)
        XCTAssertEqual(reviewItem.violationDescription, "Distance exceeds maximum allowed")
        XCTAssertEqual(reviewItem.reviewDate, entity.timestamp)
        XCTAssertEqual(reviewItem.reviewedBy, "Reviewer - John Smith")
    }
    
    // MARK: - Domain to Entity Mapping Tests
    
    func testTravelChargeReviewItemEntityUpdateFromDomain() {
        // Given: Domain model with all properties
        let reviewItem = TravelChargeReviewItem(
            id: UUID(),
            travelChargeId: UUID(),
            hasViolations: true,
            violationDescription: "Distance exceeds maximum allowed",
            reviewDate: Date(),
            reviewedBy: "Reviewer Name"
        )
        
        // When: Update entity from domain model
        let entity = TravelChargeReviewItemEntity(id: reviewItem.id)
        entity.update(from: reviewItem)
        
        // Then: All properties should be updated correctly
        XCTAssertEqual(entity.id, reviewItem.id)
        XCTAssertEqual(entity.hasViolations, true)
        XCTAssertEqual(entity.violations, ["Distance exceeds maximum allowed"]) // Single violation array
        XCTAssertEqual(entity.timestamp, reviewItem.reviewDate)
        XCTAssertEqual(entity.overrideReason, "Reviewer Name") // reviewedBy mapped to overrideReason
        XCTAssertEqual(entity.status, "pending") // Status based on hasViolations
    }
    
    func testTravelChargeReviewItemEntityUpdateWithNoViolations() {
        // Given: Domain model with no violations
        let reviewItem = TravelChargeReviewItem(
            id: UUID(),
            travelChargeId: UUID(),
            hasViolations: false,
            violationDescription: nil,
            reviewDate: Date(),
            reviewedBy: "Approved by supervisor"
        )
        
        // When: Update entity from domain model
        let entity = TravelChargeReviewItemEntity(id: reviewItem.id)
        entity.update(from: reviewItem)
        
        // Then: No violations should be handled correctly
        XCTAssertEqual(entity.id, reviewItem.id)
        XCTAssertEqual(entity.hasViolations, false)
        XCTAssertNil(entity.violations)
        XCTAssertEqual(entity.timestamp, reviewItem.reviewDate)
        XCTAssertEqual(entity.overrideReason, "Approved by supervisor")
        XCTAssertEqual(entity.status, "resolved") // Status based on hasViolations
    }
    
    func testTravelChargeReviewItemEntityUpdateWithNilValues() {
        // Given: Domain model with nil values
        let reviewItem = TravelChargeReviewItem(
            id: UUID(),
            travelChargeId: UUID(),
            hasViolations: false,
            violationDescription: nil,
            reviewDate: Date(),
            reviewedBy: nil
        )
        
        // When: Update entity from domain model
        let entity = TravelChargeReviewItemEntity(id: reviewItem.id)
        entity.update(from: reviewItem)
        
        // Then: Nil values should be handled correctly
        XCTAssertEqual(entity.id, reviewItem.id)
        XCTAssertEqual(entity.hasViolations, false)
        XCTAssertNil(entity.violations)
        XCTAssertEqual(entity.timestamp, reviewItem.reviewDate)
        XCTAssertNil(entity.overrideReason)
        XCTAssertEqual(entity.status, "resolved")
    }
    
    // MARK: - Real-World Scenarios
    
    func testRealWorldScenario_TravelChargeApproval() {
        // Given: Real-world approval scenario
        let session = createSessionEntity()
        let entity = createTravelChargeReviewItemEntity(
            session: session,
            hasViolations: false,
            violations: nil,
            timestamp: Date(),
            overrideReason: "NDIS Coordinator - Jane Smith",
            status: "approved"
        )
        
        // When: Convert to domain model
        let reviewItem = TravelChargeReviewItem(from: entity)
        
        // Then: Should map approval scenario correctly
        XCTAssertEqual(reviewItem.id, entity.id)
        XCTAssertEqual(reviewItem.travelChargeId, session.id)
        XCTAssertEqual(reviewItem.hasViolations, false)
        XCTAssertNil(reviewItem.violationDescription)
        XCTAssertEqual(reviewItem.reviewedBy, "NDIS Coordinator - Jane Smith")
    }
    
    func testRealWorldScenario_TravelChargeRejection() {
        // Given: Real-world rejection scenario
        let session = createSessionEntity()
        let violations = [
            "Distance of 45km exceeds maximum allowed 30km for this service type",
            "Missing receipt for parking cost of $12.00",
            "Travel time of 2 hours seems excessive for 45km distance"
        ]
        let entity = createTravelChargeReviewItemEntity(
            session: session,
            hasViolations: true,
            violations: violations,
            timestamp: Date(),
            overrideReason: "Finance Manager - John Doe",
            status: "rejected"
        )
        
        // When: Convert to domain model
        let reviewItem = TravelChargeReviewItem(from: entity)
        
        // Then: Should map rejection scenario correctly
        XCTAssertEqual(reviewItem.id, entity.id)
        XCTAssertEqual(reviewItem.travelChargeId, session.id)
        XCTAssertEqual(reviewItem.hasViolations, true)
        XCTAssertEqual(reviewItem.violationDescription, "Distance of 45km exceeds maximum allowed 30km for this service type")
        XCTAssertEqual(reviewItem.reviewedBy, "Finance Manager - John Doe")
    }
    
    func testRealWorldScenario_TravelChargeModification() {
        // Given: Real-world modification scenario
        let session = createSessionEntity()
        let violations = [
            "Distance updated from 20km to 25km - requires re-approval"
        ]
        let entity = createTravelChargeReviewItemEntity(
            session: session,
            hasViolations: true,
            violations: violations,
            timestamp: Date(),
            overrideReason: "Support Worker - Sarah Johnson",
            status: "pending"
        )
        
        // When: Convert to domain model
        let reviewItem = TravelChargeReviewItem(from: entity)
        
        // Then: Should map modification scenario correctly
        XCTAssertEqual(reviewItem.id, entity.id)
        XCTAssertEqual(reviewItem.travelChargeId, session.id)
        XCTAssertEqual(reviewItem.hasViolations, true)
        XCTAssertEqual(reviewItem.violationDescription, "Distance updated from 20km to 25km - requires re-approval")
        XCTAssertEqual(reviewItem.reviewedBy, "Support Worker - Sarah Johnson")
    }
    
    // MARK: - Edge Cases
    
    func testEdgeCase_EmptyViolationsArray() {
        // Given: Entity with empty violations array
        let session = createSessionEntity()
        let entity = createTravelChargeReviewItemEntity(
            session: session,
            hasViolations: true,
            violations: [],
            timestamp: Date(),
            overrideReason: "Reviewer",
            status: "pending"
        )
        
        // When: Convert to domain model
        let reviewItem = TravelChargeReviewItem(from: entity)
        
        // Then: Should handle empty violations array gracefully
        XCTAssertEqual(reviewItem.hasViolations, true)
        XCTAssertNil(reviewItem.violationDescription)
    }
    
    func testEdgeCase_EmptyViolationString() {
        // Given: Entity with empty violation string
        let session = createSessionEntity()
        let entity = createTravelChargeReviewItemEntity(
            session: session,
            hasViolations: true,
            violations: [""],
            timestamp: Date(),
            overrideReason: "Reviewer",
            status: "pending"
        )
        
        // When: Convert to domain model
        let reviewItem = TravelChargeReviewItem(from: entity)
        
        // Then: Should handle empty violation string gracefully
        XCTAssertEqual(reviewItem.hasViolations, true)
        XCTAssertEqual(reviewItem.violationDescription, "")
    }
    
    func testEdgeCase_LongViolationDescription() {
        // Given: Entity with very long violation description
        let longViolation = String(repeating: "This is a very long violation description. ", count: 50)
        let session = createSessionEntity()
        let entity = createTravelChargeReviewItemEntity(
            session: session,
            hasViolations: true,
            violations: [longViolation],
            timestamp: Date(),
            overrideReason: "Reviewer",
            status: "pending"
        )
        
        // When: Convert to domain model
        let reviewItem = TravelChargeReviewItem(from: entity)
        
        // Then: Should handle long violation description correctly
        XCTAssertEqual(reviewItem.violationDescription, longViolation)
    }
    
    // MARK: - Performance Tests
    
    func testMappingPerformance() {
        // Given: Large number of review item entities
        let session = createSessionEntity()
        var entities: [TravelChargeReviewItemEntity] = []
        
        for i in 0..<1000 {
            let entity = createTravelChargeReviewItemEntity(
                session: session,
                hasViolations: i % 2 == 0,
                violations: i % 2 == 0 ? ["Violation \(i)"] : nil,
                timestamp: Date(),
                overrideReason: "Reviewer \(i)",
                status: i % 2 == 0 ? "pending" : "resolved"
            )
            entities.append(entity)
        }
        
        // When: Convert all to domain models and measure performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let reviewItems = entities.map { TravelChargeReviewItem(from: $0) }
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then: Should complete in reasonable time
        XCTAssertLessThan(timeElapsed, 1.0, "Mapping 1000 review items should complete in less than 1 second")
        XCTAssertEqual(reviewItems.count, 1000)
    }
    
    // MARK: - Integration Tests
    
    func testIntegrationWithSession() {
        // Given: Review item linked to session
        let session = createSessionEntity()
        let entity = createTravelChargeReviewItemEntity(
            session: session,
            hasViolations: false,
            violations: nil,
            timestamp: Date(),
            overrideReason: "Approved",
            status: "approved"
        )
        
        // When: Convert to domain model
        let reviewItem = TravelChargeReviewItem(from: entity)
        
        // Then: Should maintain relationship
        XCTAssertEqual(reviewItem.travelChargeId, session.id)
    }
    
    func testIntegrationWithRepository() {
        // Given: Review item entity in context
        let entity = createTravelChargeReviewItemEntity(
            hasViolations: true,
            violations: ["Test violation"],
            timestamp: Date(),
            overrideReason: "Test reviewer",
            status: "pending"
        )
        
        // When: Convert to domain model
        let reviewItem = TravelChargeReviewItem(from: entity)
        
        // Then: Should be compatible with repository operations
        XCTAssertNotNil(reviewItem.id)
        XCTAssertNotNil(reviewItem.reviewDate)
        XCTAssertNotNil(reviewItem.hasViolations)
    }
}

// MARK: - Test Helpers

extension TravelChargeReviewItemMappingTests {
    
    /// Helper to create a test scenario with specific properties
    private func createTestScenario(
        id: UUID = UUID(),
        travelChargeId: UUID = UUID(),
        hasViolations: Bool = false,
        violationDescription: String? = nil,
        reviewDate: Date = Date(),
        reviewedBy: String? = nil
    ) -> TravelChargeReviewItem {
        return TravelChargeReviewItem(
            id: id,
            travelChargeId: travelChargeId,
            hasViolations: hasViolations,
            violationDescription: violationDescription,
            reviewDate: reviewDate,
            reviewedBy: reviewedBy
        )
    }
    
    /// Helper to verify mapping works correctly
    private func verifyMapping(
        entity: TravelChargeReviewItemEntity,
        expectedHasViolations: Bool,
        expectedViolationDescription: String?,
        expectedReviewedBy: String?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let reviewItem = TravelChargeReviewItem(from: entity)
        XCTAssertEqual(reviewItem.hasViolations, expectedHasViolations, file: file, line: line)
        XCTAssertEqual(reviewItem.violationDescription, expectedViolationDescription, file: file, line: line)
        XCTAssertEqual(reviewItem.reviewedBy, expectedReviewedBy, file: file, line: line)
    }
}
