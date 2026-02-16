import XCTest
import SwiftData
import Core
@testable import Data

/// Comprehensive test runner for travel charge mapping validation
/// Runs all travel charge mapping scenarios and validates the results
@MainActor
final class TravelChargeMappingTestRunner: XCTestCase {
    
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
    
    // MARK: - Comprehensive Test Scenarios
    
    func testAllTravelChargeMappingScenarios() {
        // Define all test scenarios
        let scenarios = [
            // Basic mapping scenarios
            TravelChargeMappingScenario(
                name: "Complete travel charge mapping",
                entityProperties: [
                    "mmmZoneName": "Zone 1",
                    "travelDistance": 25.0,
                    "travelDuration": 1800.0,
                    "vehicleType": "Car",
                    "parkingCost": 10.0,
                    "tollCost": 5.0,
                    "participantCount": 1,
                    "splitCosts": false,
                    "chargeType": "Travel",
                    "travelDirection": "Return",
                    "location": "Home to Office",
                    "notes": "Travel charge. Status: approved"
                ],
                expectedAmount: 10.0,
                expectedDistance: 25.0,
                expectedTravelTime: 1800.0,
                expectedFromAddress: "Home",
                expectedToAddress: "Office",
                expectedStatus: .approved
            ),
            TravelChargeMappingScenario(
                name: "Minimal travel charge mapping",
                entityProperties: [
                    "mmmZoneName": nil,
                    "travelDistance": nil,
                    "travelDuration": nil,
                    "vehicleType": nil,
                    "parkingCost": nil,
                    "tollCost": nil,
                    "participantCount": nil,
                    "splitCosts": nil,
                    "chargeType": nil,
                    "travelDirection": nil,
                    "location": nil,
                    "notes": nil
                ],
                expectedAmount: 0.0,
                expectedDistance: nil,
                expectedTravelTime: nil,
                expectedFromAddress: nil,
                expectedToAddress: nil,
                expectedStatus: .pending
            ),
            
            // Location parsing scenarios
            TravelChargeMappingScenario(
                name: "Location with 'to' separator",
                entityProperties: [
                    "location": "123 Main St, Sydney NSW 2000 to 456 Queen St, Melbourne VIC 3000",
                    "notes": "Travel. Status: pending"
                ],
                expectedAmount: 0.0,
                expectedDistance: nil,
                expectedTravelTime: nil,
                expectedFromAddress: "123 Main St, Sydney NSW 2000",
                expectedToAddress: "456 Queen St, Melbourne VIC 3000",
                expectedStatus: .pending
            ),
            TravelChargeMappingScenario(
                name: "Single location",
                entityProperties: [
                    "location": "Single Location",
                    "notes": "Travel. Status: approved"
                ],
                expectedAmount: 0.0,
                expectedDistance: nil,
                expectedTravelTime: nil,
                expectedFromAddress: "Single Location",
                expectedToAddress: nil,
                expectedStatus: .approved
            ),
            TravelChargeMappingScenario(
                name: "Empty location",
                entityProperties: [
                    "location": "",
                    "notes": "Travel. Status: rejected"
                ],
                expectedAmount: 0.0,
                expectedDistance: nil,
                expectedTravelTime: nil,
                expectedFromAddress: nil,
                expectedToAddress: nil,
                expectedStatus: .rejected
            ),
            
            // Status extraction scenarios
            TravelChargeMappingScenario(
                name: "Status: approved",
                entityProperties: [
                    "notes": "Travel notes. Status: approved"
                ],
                expectedAmount: 0.0,
                expectedDistance: nil,
                expectedTravelTime: nil,
                expectedFromAddress: nil,
                expectedToAddress: nil,
                expectedStatus: .approved
            ),
            TravelChargeMappingScenario(
                name: "Status: pending",
                entityProperties: [
                    "notes": "Status: pending. More notes"
                ],
                expectedAmount: 0.0,
                expectedDistance: nil,
                expectedTravelTime: nil,
                expectedFromAddress: nil,
                expectedToAddress: nil,
                expectedStatus: .pending
            ),
            TravelChargeMappingScenario(
                name: "Status: rejected",
                entityProperties: [
                    "notes": "Status: rejected"
                ],
                expectedAmount: 0.0,
                expectedDistance: nil,
                expectedTravelTime: nil,
                expectedFromAddress: nil,
                expectedToAddress: nil,
                expectedStatus: .rejected
            ),
            TravelChargeMappingScenario(
                name: "No status in notes",
                entityProperties: [
                    "notes": "No status here"
                ],
                expectedAmount: 0.0,
                expectedDistance: nil,
                expectedTravelTime: nil,
                expectedFromAddress: nil,
                expectedToAddress: nil,
                expectedStatus: .pending
            ),
            
            // Real-world scenarios
            TravelChargeMappingScenario(
                name: "Client home to community center",
                entityProperties: [
                    "mmmZoneName": "Zone 2",
                    "travelDistance": 12.5,
                    "travelDuration": 1800.0,
                    "vehicleType": "Car",
                    "parkingCost": 8.50,
                    "tollCost": 4.20,
                    "participantCount": 1,
                    "splitCosts": false,
                    "chargeType": "Travel",
                    "travelDirection": "Return",
                    "location": "123 Oak Street, Parramatta NSW 2150 to 456 Community Center, Blacktown NSW 2148",
                    "notes": "Travel from client home to community center for social activities. Status: approved"
                ],
                expectedAmount: 8.50,
                expectedDistance: 12.5,
                expectedTravelTime: 1800.0,
                expectedFromAddress: "123 Oak Street, Parramatta NSW 2150",
                expectedToAddress: "456 Community Center, Blacktown NSW 2148",
                expectedStatus: .approved
            ),
            TravelChargeMappingScenario(
                name: "Support worker travel",
                entityProperties: [
                    "mmmZoneName": "Zone 1",
                    "travelDistance": 8.2,
                    "travelDuration": 1200.0,
                    "vehicleType": "Car",
                    "parkingCost": 0.0,
                    "tollCost": 0.0,
                    "participantCount": 1,
                    "splitCosts": false,
                    "chargeType": "Travel",
                    "travelDirection": "Return",
                    "location": "Support Worker Office to 789 Pine Street, Liverpool NSW 2170",
                    "notes": "Travel from office to client home for personal care session. Status: pending"
                ],
                expectedAmount: 0.0,
                expectedDistance: 8.2,
                expectedTravelTime: 1200.0,
                expectedFromAddress: "Support Worker Office",
                expectedToAddress: "789 Pine Street, Liverpool NSW 2170",
                expectedStatus: .pending
            ),
            TravelChargeMappingScenario(
                name: "Group travel",
                entityProperties: [
                    "mmmZoneName": "Zone 3",
                    "travelDistance": 45.0,
                    "travelDuration": 3600.0,
                    "vehicleType": "Van",
                    "parkingCost": 12.0,
                    "tollCost": 8.50,
                    "participantCount": 4,
                    "splitCosts": true,
                    "chargeType": "Group Travel",
                    "travelDirection": "Return",
                    "location": "Group Home to Art Gallery, Sydney NSW 2000",
                    "notes": "Group travel to art gallery for art class. Costs split between 4 participants. Status: approved"
                ],
                expectedAmount: 12.0,
                expectedDistance: 45.0,
                expectedTravelTime: 3600.0,
                expectedFromAddress: "Group Home",
                expectedToAddress: "Art Gallery, Sydney NSW 2000",
                expectedStatus: .approved
            )
        ]
        
        // Run all scenarios
        for scenario in scenarios {
            runTravelChargeMappingScenario(scenario)
        }
    }
    
    // MARK: - Audit Log Mapping Scenarios
    
    func testAllAuditLogMappingScenarios() {
        let auditLogScenarios = [
            AuditLogMappingScenario(
                name: "Complete audit log mapping",
                entityProperties: [
                    "action": "approved",
                    "details": "Travel charge approved by supervisor",
                    "summary": "Supervisor Name"
                ],
                expectedAction: "approved",
                expectedDetails: "Travel charge approved by supervisor",
                expectedPerformedBy: "Supervisor Name"
            ),
            AuditLogMappingScenario(
                name: "Minimal audit log mapping",
                entityProperties: [
                    "action": nil,
                    "details": nil,
                    "summary": nil
                ],
                expectedAction: "unknown",
                expectedDetails: nil,
                expectedPerformedBy: nil
            ),
            AuditLogMappingScenario(
                name: "Rejection audit log",
                entityProperties: [
                    "action": "rejected",
                    "details": "Travel charge rejected: Missing receipt for parking cost",
                    "summary": "Finance Manager - John Doe"
                ],
                expectedAction: "rejected",
                expectedDetails: "Travel charge rejected: Missing receipt for parking cost",
                expectedPerformedBy: "Finance Manager - John Doe"
            )
        ]
        
        for scenario in auditLogScenarios {
            runAuditLogMappingScenario(scenario)
        }
    }
    
    // MARK: - Review Item Mapping Scenarios
    
    func testAllReviewItemMappingScenarios() {
        let reviewItemScenarios = [
            ReviewItemMappingScenario(
                name: "Complete review item mapping",
                entityProperties: [
                    "hasViolations": true,
                    "violations": ["Distance exceeds maximum allowed", "Missing receipt"],
                    "overrideReason": "Reviewer Name",
                    "status": "resolved"
                ],
                expectedHasViolations: true,
                expectedViolationDescription: "Distance exceeds maximum allowed",
                expectedReviewedBy: "Reviewer Name"
            ),
            ReviewItemMappingScenario(
                name: "No violations review item",
                entityProperties: [
                    "hasViolations": false,
                    "violations": nil,
                    "overrideReason": "Approved by supervisor",
                    "status": "approved"
                ],
                expectedHasViolations: false,
                expectedViolationDescription: nil,
                expectedReviewedBy: "Approved by supervisor"
            ),
            ReviewItemMappingScenario(
                name: "Minimal review item mapping",
                entityProperties: [
                    "hasViolations": false,
                    "violations": nil,
                    "overrideReason": nil,
                    "status": "pending"
                ],
                expectedHasViolations: false,
                expectedViolationDescription: nil,
                expectedReviewedBy: nil
            )
        ]
        
        for scenario in reviewItemScenarios {
            runReviewItemMappingScenario(scenario)
        }
    }
    
    // MARK: - Performance Tests
    
    func testTravelChargeMappingPerformance() {
        // Test with large number of travel charge entities
        var entities: [TravelChargeEntity] = []
        for i in 0..<1000 {
            let entity = createTravelChargeEntity()
            entity.notes = "Travel charge \(i). Status: pending"
            entities.append(entity)
        }
        
        // Measure performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let travelCharges = entities.map { TravelCharge(from: $0) }
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete in reasonable time
        XCTAssertLessThan(timeElapsed, 1.0, "Travel charge mapping should complete in less than 1 second")
        XCTAssertEqual(travelCharges.count, 1000)
    }
    
    // MARK: - Integration Tests
    
    func testIntegrationWithRepository() {
        // Test integration with repository operations
        let session = createSessionEntity()
        let client = createClientEntity()
        let service = createClientServiceEntity()
        let entity = createTravelChargeEntity(session: session, client: client, service: service)
        
        let travelCharge = TravelCharge(from: entity)
        
        // Should be compatible with repository operations
        XCTAssertNotNil(travelCharge.id)
        XCTAssertNotNil(travelCharge.sessionId)
        XCTAssertNotNil(travelCharge.createdDate)
    }
    
    func testIntegrationWithUseCases() {
        // Test integration with use case operations
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
        
        let entity = TravelChargeEntity(id: travelCharge.id)
        entity.update(from: travelCharge)
        
        // Should be compatible with use case operations
        XCTAssertEqual(entity.id, travelCharge.id)
        XCTAssertEqual(entity.parkingCost, travelCharge.amount)
        XCTAssertEqual(entity.travelDistance, travelCharge.distance)
        XCTAssertEqual(entity.travelDuration, travelCharge.travelTime)
    }
    
    // MARK: - Private Helpers
    
    private func runTravelChargeMappingScenario(_ scenario: TravelChargeMappingScenario) {
        // Create travel charge entity
        let entity = createTravelChargeEntity()
        
        // Set properties based on scenario
        for (key, value) in scenario.entityProperties {
            switch key {
            case "mmmZoneName":
                entity.mmmZoneName = value as? String
            case "travelDistance":
                entity.travelDistance = value as? Double
            case "travelDuration":
                entity.travelDuration = value as? Double
            case "vehicleType":
                entity.vehicleType = value as? String
            case "parkingCost":
                entity.parkingCost = value as? Double
            case "tollCost":
                entity.tollCost = value as? Double
            case "participantCount":
                entity.participantCount = value as? Int16
            case "splitCosts":
                entity.splitCosts = value as? Bool
            case "chargeType":
                entity.chargeType = value as? String
            case "travelDirection":
                entity.travelDirection = value as? String
            case "location":
                entity.location = value as? String
            case "notes":
                entity.notes = value as? String
            default:
                break
            }
        }
        
        // Convert to domain model
        let travelCharge = TravelCharge(from: entity)
        
        // Verify mapping
        XCTAssertEqual(
            travelCharge.amount,
            scenario.expectedAmount,
            "Amount mapping failed for scenario: \(scenario.name)"
        )
        XCTAssertEqual(
            travelCharge.distance,
            scenario.expectedDistance,
            "Distance mapping failed for scenario: \(scenario.name)"
        )
        XCTAssertEqual(
            travelCharge.travelTime,
            scenario.expectedTravelTime,
            "Travel time mapping failed for scenario: \(scenario.name)"
        )
        XCTAssertEqual(
            travelCharge.fromAddress,
            scenario.expectedFromAddress,
            "From address mapping failed for scenario: \(scenario.name)"
        )
        XCTAssertEqual(
            travelCharge.toAddress,
            scenario.expectedToAddress,
            "To address mapping failed for scenario: \(scenario.name)"
        )
        XCTAssertEqual(
            travelCharge.status,
            scenario.expectedStatus,
            "Status mapping failed for scenario: \(scenario.name)"
        )
    }
    
    private func runAuditLogMappingScenario(_ scenario: AuditLogMappingScenario) {
        // Create audit log entity
        let entity = createTravelChargeAuditLogEntity()
        
        // Set properties based on scenario
        for (key, value) in scenario.entityProperties {
            switch key {
            case "action":
                entity.action = value as? String
            case "details":
                entity.details = value as? String
            case "summary":
                entity.summary = value as? String
            default:
                break
            }
        }
        
        // Convert to domain model
        let auditLog = TravelChargeAuditLog(from: entity)
        
        // Verify mapping
        XCTAssertEqual(
            auditLog.action,
            scenario.expectedAction,
            "Action mapping failed for scenario: \(scenario.name)"
        )
        XCTAssertEqual(
            auditLog.details,
            scenario.expectedDetails,
            "Details mapping failed for scenario: \(scenario.name)"
        )
        XCTAssertEqual(
            auditLog.performedBy,
            scenario.expectedPerformedBy,
            "Performed by mapping failed for scenario: \(scenario.name)"
        )
    }
    
    private func runReviewItemMappingScenario(_ scenario: ReviewItemMappingScenario) {
        // Create review item entity
        let session = createSessionEntity()
        let entity = createTravelChargeReviewItemEntity(session: session)
        
        // Set properties based on scenario
        for (key, value) in scenario.entityProperties {
            switch key {
            case "hasViolations":
                entity.hasViolations = value as? Bool ?? false
            case "violations":
                entity.violations = value as? [String]
            case "overrideReason":
                entity.overrideReason = value as? String
            case "status":
                entity.status = SessionStatus(rawValue: value as? String ?? "pending") ?? .scheduled
            default:
                break
            }
        }
        
        // Convert to domain model
        let reviewItem = TravelChargeReviewItem(from: entity)
        
        // Verify mapping
        XCTAssertEqual(
            reviewItem.hasViolations,
            scenario.expectedHasViolations,
            "Has violations mapping failed for scenario: \(scenario.name)"
        )
        XCTAssertEqual(
            reviewItem.violationDescription,
            scenario.expectedViolationDescription,
            "Violation description mapping failed for scenario: \(scenario.name)"
        )
        XCTAssertEqual(
            reviewItem.reviewedBy,
            scenario.expectedReviewedBy,
            "Reviewed by mapping failed for scenario: \(scenario.name)"
        )
    }
    
    // MARK: - Test Data Creation Helpers
    
    private func createSessionEntity(id: UUID = UUID()) -> SessionEntity {
        let entity = SessionEntity(id: id)
        entity.title = "Test Session"
        entity.startTime = Date()
        entity.endTime = Date().addingTimeInterval(3600)
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
    
    private func createClientEntity(id: UUID = UUID()) -> ClientEntity {
        let entity = ClientEntity(id: id, ndisNumber: "123456789", fullName: "Test Client", status: .active)
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
    
    private func createClientServiceEntity(id: UUID = UUID()) -> ClientServiceEntity {
        let entity = ClientServiceEntity(id: id, serviceName: "Test Service", unit: "hour", rate: 50.0)
        entity.supportItemNumber = "01_001_0107_1_1"
        entity.ndisCode = "01_001_0107_1_1"
        entity.startDate = Date()
        entity.endDate = Date().addingTimeInterval(365 * 24 * 60 * 60)
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
        
        // Set default properties
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
        entity.linkedSession = session
        entity.client = client
        entity.service = service
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
    
    private func createTravelChargeAuditLogEntity(id: UUID = UUID()) -> TravelChargeAuditLogEntity {
        let entity = TravelChargeAuditLogEntity(id: id)
        entity.action = "created"
        entity.timestamp = Date()
        entity.details = "Travel charge created"
        entity.summary = "System"
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
    
    private func createTravelChargeReviewItemEntity(
        id: UUID = UUID(),
        session: SessionEntity? = nil
    ) -> TravelChargeReviewItemEntity {
        let entity = TravelChargeReviewItemEntity(id: id)
        entity.session = session
        entity.hasViolations = false
        entity.violations = nil
        entity.timestamp = Date()
        entity.overrideReason = nil
        entity.status = .pending
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
}

// MARK: - Supporting Types

private struct TravelChargeMappingScenario {
    let name: String
    let entityProperties: [String: Any?]
    let expectedAmount: Double
    let expectedDistance: Double?
    let expectedTravelTime: TimeInterval?
    let expectedFromAddress: String?
    let expectedToAddress: String?
    let expectedStatus: TravelChargeStatus
}

private struct AuditLogMappingScenario {
    let name: String
    let entityProperties: [String: Any?]
    let expectedAction: String
    let expectedDetails: String?
    let expectedPerformedBy: String?
}

private struct ReviewItemMappingScenario {
    let name: String
    let entityProperties: [String: Any?]
    let expectedHasViolations: Bool
    let expectedViolationDescription: String?
    let expectedReviewedBy: String?
}
