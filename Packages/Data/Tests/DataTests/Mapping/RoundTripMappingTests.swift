//
//  RoundTripMappingTests.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//
//  Round-trip mapping tests (entity -> domain -> entity)
//  This test suite validates that data integrity is maintained when converting
//  from entity to domain model and back to entity.
//

import XCTest
import SwiftData
@testable import Data
@testable import Core

/// Round-trip mapping tests (entity -> domain -> entity)
final class RoundTripMappingTests: XCTestCase {
    
    var modelContext: ModelContext!
    var modelContainer: ModelContainer!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory model container for testing
        let schema = Schema([
            ClientEntity.self,
            PayeeEntity.self,
            PlanManagerEntity.self,
            AddressEntity.self,
            SessionEntity.self,
            TravelChargeEntity.self,
            InvoiceEntity.self,
            InvoiceItemEntity.self,
            ClientServiceEntity.self,
            NDISItemEntity.self,
            RegionalPriceEntity.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = ModelContext(modelContainer)
        } catch {
            XCTFail("Failed to create model container: \(error)")
        }
    }
    
    override func tearDown() {
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }
    
    // MARK: - Client Round-Trip Tests
    
    func testClientRoundTripMapping() throws {
        // Create original ClientEntity
        let originalEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        originalEntity.email = "john@example.com"
        originalEntity.notes = "Test notes"
        originalEntity.phone = "0412345678"
        originalEntity.creditAmount = 100.0
        originalEntity.isMinor = false
        originalEntity.hasNdisPlan = true
        originalEntity.planManagementType = "plan_managed"
        originalEntity.billingAuthority = "NDIA"
        originalEntity.sendInvoicesToClient = true
        originalEntity.sendInvoicesToPayee = false
        originalEntity.sendInvoicesToPlanManager = true
        
        modelContext.insert(originalEntity)
        try modelContext.save()
        
        // Convert to domain model
        let domainModel = Client(from: originalEntity)
        
        // Create new entity and update from domain model
        let newEntity = ClientEntity(
            id: domainModel.id,
            ndisNumber: domainModel.ndisNumber,
            fullName: domainModel.fullName,
            status: domainModel.status
        )
        newEntity.update(from: domainModel)
        
        // Verify round-trip integrity
        XCTAssertEqual(newEntity.id, originalEntity.id)
        XCTAssertEqual(newEntity.ndisNumber, originalEntity.ndisNumber)
        XCTAssertEqual(newEntity.fullName, originalEntity.fullName)
        XCTAssertEqual(newEntity.status, originalEntity.status)
        XCTAssertEqual(newEntity.email, originalEntity.email)
        XCTAssertEqual(newEntity.notes, originalEntity.notes)
        XCTAssertEqual(newEntity.phone, originalEntity.phone)
        XCTAssertEqual(newEntity.creditAmount, originalEntity.creditAmount)
        XCTAssertEqual(newEntity.isMinor, originalEntity.isMinor)
        XCTAssertEqual(newEntity.hasNdisPlan, originalEntity.hasNdisPlan)
        XCTAssertEqual(newEntity.planManagementType, originalEntity.planManagementType)
        XCTAssertEqual(newEntity.billingAuthority, originalEntity.billingAuthority)
        XCTAssertEqual(newEntity.sendInvoicesToClient, originalEntity.sendInvoicesToClient)
        XCTAssertEqual(newEntity.sendInvoicesToPayee, originalEntity.sendInvoicesToPayee)
        XCTAssertEqual(newEntity.sendInvoicesToPlanManager, originalEntity.sendInvoicesToPlanManager)
    }
    
    func testClientRoundTripMappingWithRelationships() throws {
        // Create test AddressEntity
        let addressEntity = AddressEntity()
        addressEntity.id = UUID()
        addressEntity.streetNumber = "123"
        addressEntity.streetName = "Main St"
        addressEntity.city = "Sydney"
        addressEntity.state = "NSW"
        addressEntity.postcode = "2000"
        addressEntity.country = "Australia"
        
        // Create test PlanManagerEntity
        let planManagerEntity = PlanManagerEntity(abn: "12345678901")
        planManagerEntity.id = UUID()
        planManagerEntity.name = "Test Plan Manager"
        planManagerEntity.email = "pm@example.com"
        planManagerEntity.phone = "0412345679"
        planManagerEntity.address = addressEntity
        
        // Create test PayeeEntity
        let payeeEntity = PayeeEntity(id: UUID(), fullName: "Jane Doe")
        payeeEntity.email = "jane@example.com"
        payeeEntity.phone = "0412345680"
        payeeEntity.status = "active"
        payeeEntity.address = addressEntity
        
        // Create original ClientEntity
        let originalEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        originalEntity.address = addressEntity
        originalEntity.planManager = planManagerEntity
        originalEntity.payee = payeeEntity
        
        modelContext.insert(addressEntity)
        modelContext.insert(planManagerEntity)
        modelContext.insert(payeeEntity)
        modelContext.insert(originalEntity)
        try modelContext.save()
        
        // Convert to domain model
        let domainModel = Client(from: originalEntity)
        
        // Create new entity and update from domain model
        let newEntity = ClientEntity(
            id: domainModel.id,
            ndisNumber: domainModel.ndisNumber,
            fullName: domainModel.fullName,
            status: domainModel.status
        )
        newEntity.update(from: domainModel)
        
        // Verify round-trip integrity
        XCTAssertEqual(newEntity.id, originalEntity.id)
        XCTAssertEqual(newEntity.ndisNumber, originalEntity.ndisNumber)
        XCTAssertEqual(newEntity.fullName, originalEntity.fullName)
        XCTAssertEqual(newEntity.status, originalEntity.status)
        
        // Note: Relationships are not updated in the update method,
        // so we only verify the basic properties
    }
    
    // MARK: - Payee Round-Trip Tests
    
    func testPayeeRoundTripMapping() throws {
        // Create original PayeeEntity
        let originalEntity = PayeeEntity(id: UUID(), fullName: "Jane Doe")
        originalEntity.email = "jane@example.com"
        originalEntity.phone = "0412345680"
        originalEntity.status = "active"
        originalEntity.relationToClient = "parent"
        originalEntity.payeeID = 12345
        
        modelContext.insert(originalEntity)
        try modelContext.save()
        
        // Convert to domain model
        let domainModel = Payee(from: originalEntity)
        
        // Create new entity and update from domain model
        let newEntity = PayeeEntity(id: domainModel.id, fullName: domainModel.fullName)
        newEntity.update(from: domainModel)
        
        // Verify round-trip integrity
        XCTAssertEqual(newEntity.id, originalEntity.id)
        XCTAssertEqual(newEntity.fullName, originalEntity.fullName)
        XCTAssertEqual(newEntity.email, originalEntity.email)
        XCTAssertEqual(newEntity.phone, originalEntity.phone)
        XCTAssertEqual(newEntity.status, originalEntity.status)
    }
    
    // MARK: - PlanManager Round-Trip Tests
    
    func testPlanManagerRoundTripMapping() throws {
        // Create original PlanManagerEntity
        let originalEntity = PlanManagerEntity(abn: "12345678901")
        originalEntity.id = UUID()
        originalEntity.name = "Test Plan Manager"
        originalEntity.email = "pm@example.com"
        originalEntity.phone = "0412345679"
        
        modelContext.insert(originalEntity)
        try modelContext.save()
        
        // Convert to domain model
        let domainModel = PlanManager(from: originalEntity)
        
        // Create new entity and update from domain model
        let newEntity = PlanManagerEntity(abn: domainModel.abn)
        newEntity.id = domainModel.id
        newEntity.update(from: domainModel)
        
        // Verify round-trip integrity
        XCTAssertEqual(newEntity.id, originalEntity.id)
        XCTAssertEqual(newEntity.name, originalEntity.name)
        XCTAssertEqual(newEntity.email, originalEntity.email)
        XCTAssertEqual(newEntity.phone, originalEntity.phone)
        XCTAssertEqual(newEntity.abn, originalEntity.abn)
    }
    
    // MARK: - Address Round-Trip Tests
    
    func testAddressRoundTripMapping() throws {
        // Create original AddressEntity
        let originalEntity = AddressEntity()
        originalEntity.id = UUID()
        originalEntity.streetNumber = "123"
        originalEntity.streetName = "Main St"
        originalEntity.city = "Sydney"
        originalEntity.state = "NSW"
        originalEntity.postcode = "2000"
        originalEntity.country = "Australia"
        originalEntity.unitNumber = "Unit 1"
        originalEntity.poBox = "PO Box 123"
        
        modelContext.insert(originalEntity)
        try modelContext.save()
        
        // Convert to domain model
        let domainModel = Address(from: originalEntity)
        
        // Create new entity and update from domain model
        let newEntity = AddressEntity()
        newEntity.id = domainModel.id
        newEntity.update(from: domainModel)
        
        // Verify round-trip integrity
        XCTAssertEqual(newEntity.id, originalEntity.id)
        XCTAssertEqual(newEntity.streetNumber, originalEntity.streetNumber)
        XCTAssertEqual(newEntity.streetName, originalEntity.streetName)
        XCTAssertEqual(newEntity.city, originalEntity.city)
        XCTAssertEqual(newEntity.state, originalEntity.state)
        XCTAssertEqual(newEntity.postcode, originalEntity.postcode)
        XCTAssertEqual(newEntity.country, originalEntity.country)
    }
    
    // MARK: - Session Round-Trip Tests
    
    func testSessionRoundTripMapping() throws {
        // Create original SessionEntity
        let originalEntity = SessionEntity(id: UUID())
        originalEntity.title = "Test Session"
        originalEntity.startTime = Date()
        originalEntity.endTime = Date().addingTimeInterval(3600)
        originalEntity.isAllDay = false
        originalEntity.location = "Test Location"
        originalEntity.notes = "Test Notes"
        originalEntity.status = "active"
        originalEntity.isTravel = false
        originalEntity.groupID = UUID()
        originalEntity.groupedPosition = 1
        originalEntity.attendeesCount = 2
        originalEntity.derivedFromEKEventID = "test-event-id"
        originalEntity.googleColorId = "test-color-id"
        originalEntity.sessionLatitude = -33.8688
        originalEntity.sessionLongitude = 151.2093
        originalEntity.eventIdentifier = "test-event-identifier"
        originalEntity.calendarIdentifier = "test-calendar-identifier"
        originalEntity.lastModifiedDate = Date()
        originalEntity.lastSyncTag = "test-sync-tag"
        originalEntity.recurrenceRuleData = Data()
        
        modelContext.insert(originalEntity)
        try modelContext.save()
        
        // Convert to domain model
        let domainModel = Session.from(entity: originalEntity)
        
        // Create new entity and update from domain model
        let newEntity = SessionEntity(id: domainModel.id)
        newEntity.update(from: domainModel)
        
        // Verify round-trip integrity
        XCTAssertEqual(newEntity.id, originalEntity.id)
        XCTAssertEqual(newEntity.title, originalEntity.title)
        XCTAssertEqual(newEntity.startTime, originalEntity.startTime)
        XCTAssertEqual(newEntity.endTime, originalEntity.endTime)
        XCTAssertEqual(newEntity.isAllDay, originalEntity.isAllDay)
        XCTAssertEqual(newEntity.location, originalEntity.location)
        XCTAssertEqual(newEntity.notes, originalEntity.notes)
        XCTAssertEqual(newEntity.status, originalEntity.status)
        XCTAssertEqual(newEntity.isTravel, originalEntity.isTravel)
        XCTAssertEqual(newEntity.groupID, originalEntity.groupID)
        XCTAssertEqual(newEntity.groupedPosition, originalEntity.groupedPosition)
        XCTAssertEqual(newEntity.attendeesCount, originalEntity.attendeesCount)
        XCTAssertEqual(newEntity.derivedFromEKEventID, originalEntity.derivedFromEKEventID)
        XCTAssertEqual(newEntity.googleColorId, originalEntity.googleColorId)
        XCTAssertEqual(newEntity.sessionLatitude, originalEntity.sessionLatitude)
        XCTAssertEqual(newEntity.sessionLongitude, originalEntity.sessionLongitude)
        XCTAssertEqual(newEntity.eventIdentifier, originalEntity.eventIdentifier)
        XCTAssertEqual(newEntity.calendarIdentifier, originalEntity.calendarIdentifier)
        XCTAssertEqual(newEntity.lastModifiedDate, originalEntity.lastModifiedDate)
        XCTAssertEqual(newEntity.lastSyncTag, originalEntity.lastSyncTag)
        XCTAssertEqual(newEntity.recurrenceRuleData, originalEntity.recurrenceRuleData)
    }
    
    // MARK: - TravelCharge Round-Trip Tests
    
    func testTravelChargeRoundTripMapping() throws {
        // Create original TravelChargeEntity
        let originalEntity = TravelChargeEntity(id: UUID())
        originalEntity.mmmZoneName = "Zone 1"
        originalEntity.travelDistance = 10.5
        originalEntity.travelDuration = 30.0
        originalEntity.vehicleType = "car"
        originalEntity.parkingCost = 5.0
        originalEntity.tollCost = 2.0
        originalEntity.participantCount = 1
        originalEntity.splitCosts = false
        originalEntity.chargeType = "travel"
        originalEntity.travelDirection = "outbound"
        originalEntity.location = "Home to Office"
        originalEntity.notes = "Status: pending"
        originalEntity.lastModifiedDate = Date()
        originalEntity.ekCreationDate = Date()
        
        modelContext.insert(originalEntity)
        try modelContext.save()
        
        // Convert to domain model
        let domainModel = TravelCharge(from: originalEntity)
        
        // Create new entity and update from domain model
        let newEntity = TravelChargeEntity(id: domainModel.id)
        newEntity.update(from: domainModel)
        
        // Verify round-trip integrity
        XCTAssertEqual(newEntity.id, originalEntity.id)
        XCTAssertEqual(newEntity.travelDistance, originalEntity.travelDistance)
        XCTAssertEqual(newEntity.travelDuration, originalEntity.travelDuration)
        XCTAssertEqual(newEntity.parkingCost, originalEntity.parkingCost)
        XCTAssertEqual(newEntity.notes, originalEntity.notes)
        XCTAssertEqual(newEntity.lastModifiedDate, originalEntity.lastModifiedDate)
        XCTAssertEqual(newEntity.location, originalEntity.location)
    }
    
    // MARK: - Edge Case Tests
    
    func testRoundTripMappingWithNilValues() throws {
        // Create original ClientEntity with nil values
        let originalEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        // Leave optional properties as nil
        
        modelContext.insert(originalEntity)
        try modelContext.save()
        
        // Convert to domain model
        let domainModel = Client(from: originalEntity)
        
        // Create new entity and update from domain model
        let newEntity = ClientEntity(
            id: domainModel.id,
            ndisNumber: domainModel.ndisNumber,
            fullName: domainModel.fullName,
            status: domainModel.status
        )
        newEntity.update(from: domainModel)
        
        // Verify round-trip integrity with nil values
        XCTAssertEqual(newEntity.id, originalEntity.id)
        XCTAssertEqual(newEntity.ndisNumber, originalEntity.ndisNumber)
        XCTAssertEqual(newEntity.fullName, originalEntity.fullName)
        XCTAssertEqual(newEntity.status, originalEntity.status)
        XCTAssertNil(newEntity.email)
        XCTAssertNil(newEntity.notes)
        XCTAssertNil(newEntity.phone)
        XCTAssertNil(newEntity.planManagementType)
        XCTAssertNil(newEntity.billingAuthority)
        XCTAssertNil(newEntity.sendInvoicesToClient)
        XCTAssertNil(newEntity.sendInvoicesToPayee)
        XCTAssertNil(newEntity.sendInvoicesToPlanManager)
    }
    
    func testRoundTripMappingWithEmptyStrings() throws {
        // Create original ClientEntity with empty strings
        let originalEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        originalEntity.email = ""
        originalEntity.notes = ""
        originalEntity.phone = ""
        
        modelContext.insert(originalEntity)
        try modelContext.save()
        
        // Convert to domain model
        let domainModel = Client(from: originalEntity)
        
        // Create new entity and update from domain model
        let newEntity = ClientEntity(
            id: domainModel.id,
            ndisNumber: domainModel.ndisNumber,
            fullName: domainModel.fullName,
            status: domainModel.status
        )
        newEntity.update(from: domainModel)
        
        // Verify round-trip integrity with empty strings
        XCTAssertEqual(newEntity.email, "")
        XCTAssertEqual(newEntity.notes, "")
        XCTAssertEqual(newEntity.phone, "")
    }
    
    func testRoundTripMappingWithZeroValues() throws {
        // Create original ClientEntity with zero values
        let originalEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        originalEntity.creditAmount = 0.0
        originalEntity.isMinor = false
        originalEntity.hasNdisPlan = false
        
        modelContext.insert(originalEntity)
        try modelContext.save()
        
        // Convert to domain model
        let domainModel = Client(from: originalEntity)
        
        // Create new entity and update from domain model
        let newEntity = ClientEntity(
            id: domainModel.id,
            ndisNumber: domainModel.ndisNumber,
            fullName: domainModel.fullName,
            status: domainModel.status
        )
        newEntity.update(from: domainModel)
        
        // Verify round-trip integrity with zero values
        XCTAssertEqual(newEntity.creditAmount, 0.0)
        XCTAssertEqual(newEntity.isMinor, false)
        XCTAssertEqual(newEntity.hasNdisPlan, false)
    }
    
    // MARK: - Performance Tests
    
    func testRoundTripMappingPerformance() throws {
        // Create original ClientEntity
        let originalEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        originalEntity.email = "john@example.com"
        originalEntity.notes = "Test notes"
        originalEntity.phone = "0412345678"
        originalEntity.creditAmount = 100.0
        originalEntity.isMinor = false
        originalEntity.hasNdisPlan = true
        originalEntity.planManagementType = "plan_managed"
        originalEntity.billingAuthority = "NDIA"
        originalEntity.sendInvoicesToClient = true
        originalEntity.sendInvoicesToPayee = false
        originalEntity.sendInvoicesToPlanManager = true
        
        modelContext.insert(originalEntity)
        try modelContext.save()
        
        // Measure round-trip mapping performance
        measure {
            // Convert to domain model
            let domainModel = Client(from: originalEntity)
            
            // Create new entity and update from domain model
            let newEntity = ClientEntity(
                id: domainModel.id,
                ndisNumber: domainModel.ndisNumber,
                fullName: domainModel.fullName,
                status: domainModel.status
            )
            newEntity.update(from: domainModel)
            
            // Verify basic properties
            XCTAssertEqual(newEntity.id, originalEntity.id)
            XCTAssertEqual(newEntity.ndisNumber, originalEntity.ndisNumber)
            XCTAssertEqual(newEntity.fullName, originalEntity.fullName)
            XCTAssertEqual(newEntity.status, originalEntity.status)
        }
    }
}
