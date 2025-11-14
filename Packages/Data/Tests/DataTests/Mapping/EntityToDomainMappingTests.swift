//
//  EntityToDomainMappingTests.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//
//  Comprehensive unit tests for all entity-to-domain mappings
//  This test suite validates that all entity-to-domain model conversions
//  work correctly and maintain data integrity.
//

import XCTest
import SwiftData
@testable import Data
@testable import Core

/// Comprehensive unit tests for entity-to-domain mappings
final class EntityToDomainMappingTests: XCTestCase {
    
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
    
    // MARK: - ClientEntity to Client Tests
    
    func testClientEntityToClientMapping() throws {
        // Create test ClientEntity
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.email = "john@example.com"
        clientEntity.notes = "Test notes"
        clientEntity.phone = "0412345678"
        clientEntity.creditAmount = 100.0
        clientEntity.isMinor = false
        clientEntity.hasNdisPlan = true
        clientEntity.planManagementType = "plan_managed"
        clientEntity.billingAuthority = "NDIA"
        clientEntity.sendInvoicesToClient = true
        clientEntity.sendInvoicesToPayee = false
        clientEntity.sendInvoicesToPlanManager = true
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Test mapping
        let client = Client(from: clientEntity)
        
        // Verify all properties are mapped correctly
        XCTAssertEqual(client.id, clientEntity.id)
        XCTAssertEqual(client.ndisNumber, clientEntity.ndisNumber)
        XCTAssertEqual(client.fullName, clientEntity.fullName)
        XCTAssertEqual(client.status, clientEntity.status)
        XCTAssertEqual(client.email, clientEntity.email)
        XCTAssertEqual(client.notes, clientEntity.notes)
        XCTAssertEqual(client.phone, clientEntity.phone)
        XCTAssertEqual(client.creditAmount, clientEntity.creditAmount)
        XCTAssertEqual(client.isMinor, clientEntity.isMinor)
        XCTAssertEqual(client.hasNdisPlan, clientEntity.hasNdisPlan)
        XCTAssertEqual(client.planManagementType, clientEntity.planManagementType)
        XCTAssertEqual(client.billingAuthority, clientEntity.billingAuthority)
        XCTAssertEqual(client.sendInvoicesToClient, clientEntity.sendInvoicesToClient)
        XCTAssertEqual(client.sendInvoicesToPayee, clientEntity.sendInvoicesToPayee)
        XCTAssertEqual(client.sendInvoicesToPlanManager, clientEntity.sendInvoicesToPlanManager)
    }
    
    func testClientEntityToClientMappingWithRelationships() throws {
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
        
        // Create test ClientEntity
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.address = addressEntity
        clientEntity.planManager = planManagerEntity
        clientEntity.payee = payeeEntity
        
        modelContext.insert(addressEntity)
        modelContext.insert(planManagerEntity)
        modelContext.insert(payeeEntity)
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Test mapping
        let client = Client(from: clientEntity)
        
        // Verify relationships are mapped correctly
        XCTAssertNotNil(client.address)
        XCTAssertEqual(client.address?.id, addressEntity.id)
        XCTAssertEqual(client.address?.street, "123 Main St")
        XCTAssertEqual(client.address?.city, "Sydney")
        XCTAssertEqual(client.address?.state, "NSW")
        XCTAssertEqual(client.address?.postcode, "2000")
        XCTAssertEqual(client.address?.country, "Australia")
        
        XCTAssertNotNil(client.planManager)
        XCTAssertEqual(client.planManager?.id, planManagerEntity.id)
        XCTAssertEqual(client.planManager?.name, "Test Plan Manager")
        XCTAssertEqual(client.planManager?.email, "pm@example.com")
        XCTAssertEqual(client.planManager?.phone, "0412345679")
        XCTAssertEqual(client.planManager?.abn, "12345678901")
        
        XCTAssertNotNil(client.payee)
        XCTAssertEqual(client.payee?.id, payeeEntity.id)
        XCTAssertEqual(client.payee?.fullName, "Jane Doe")
        XCTAssertEqual(client.payee?.email, "jane@example.com")
        XCTAssertEqual(client.payee?.phone, "0412345680")
        XCTAssertEqual(client.payee?.status, "active")
    }
    
    // MARK: - PayeeEntity to Payee Tests
    
    func testPayeeEntityToPayeeMapping() throws {
        // Create test PayeeEntity
        let payeeEntity = PayeeEntity(id: UUID(), fullName: "Jane Doe")
        payeeEntity.email = "jane@example.com"
        payeeEntity.phone = "0412345680"
        payeeEntity.status = "active"
        payeeEntity.relationToClient = "parent"
        payeeEntity.payeeID = 12345
        
        modelContext.insert(payeeEntity)
        try modelContext.save()
        
        // Test mapping
        let payee = Payee(from: payeeEntity)
        
        // Verify all properties are mapped correctly
        XCTAssertEqual(payee.id, payeeEntity.id)
        XCTAssertEqual(payee.fullName, payeeEntity.fullName)
        XCTAssertEqual(payee.email, payeeEntity.email)
        XCTAssertEqual(payee.phone, payeeEntity.phone)
        XCTAssertEqual(payee.status, payeeEntity.status)
    }
    
    // MARK: - PlanManagerEntity to PlanManager Tests
    
    func testPlanManagerEntityToPlanManagerMapping() throws {
        // Create test PlanManagerEntity
        let planManagerEntity = PlanManagerEntity(abn: "12345678901")
        planManagerEntity.id = UUID()
        planManagerEntity.name = "Test Plan Manager"
        planManagerEntity.email = "pm@example.com"
        planManagerEntity.phone = "0412345679"
        
        modelContext.insert(planManagerEntity)
        try modelContext.save()
        
        // Test mapping
        let planManager = PlanManager(from: planManagerEntity)
        
        // Verify all properties are mapped correctly
        XCTAssertEqual(planManager.id, planManagerEntity.id)
        XCTAssertEqual(planManager.name, planManagerEntity.name)
        XCTAssertEqual(planManager.email, planManagerEntity.email)
        XCTAssertEqual(planManager.phone, planManagerEntity.phone)
        XCTAssertEqual(planManager.abn, planManagerEntity.abn)
    }
    
    // MARK: - AddressEntity to Address Tests
    
    func testAddressEntityToAddressMapping() throws {
        // Create test AddressEntity
        let addressEntity = AddressEntity()
        addressEntity.id = UUID()
        addressEntity.streetNumber = "123"
        addressEntity.streetName = "Main St"
        addressEntity.city = "Sydney"
        addressEntity.state = "NSW"
        addressEntity.postcode = "2000"
        addressEntity.country = "Australia"
        addressEntity.unitNumber = "Unit 1"
        addressEntity.poBox = "PO Box 123"
        
        modelContext.insert(addressEntity)
        try modelContext.save()
        
        // Test mapping
        let address = Address(from: addressEntity)
        
        // Verify all properties are mapped correctly
        XCTAssertEqual(address.id, addressEntity.id)
        XCTAssertEqual(address.street, "123 Main St")
        XCTAssertEqual(address.city, addressEntity.city)
        XCTAssertEqual(address.state, addressEntity.state)
        XCTAssertEqual(address.postcode, addressEntity.postcode)
        XCTAssertEqual(address.country, addressEntity.country)
    }
    
    // MARK: - SessionEntity to Session Tests
    
    func testSessionEntityToSessionMapping() throws {
        // Create test SessionEntity
        let sessionEntity = SessionEntity(id: UUID())
        sessionEntity.title = "Test Session"
        sessionEntity.startTime = Date()
        sessionEntity.endTime = Date().addingTimeInterval(3600)
        sessionEntity.isAllDay = false
        sessionEntity.location = "Test Location"
        sessionEntity.notes = "Test Notes"
        sessionEntity.status = "active"
        sessionEntity.isTravel = false
        sessionEntity.groupID = UUID()
        sessionEntity.groupedPosition = 1
        sessionEntity.attendeesCount = 2
        sessionEntity.derivedFromEKEventID = "test-event-id"
        sessionEntity.googleColorId = "test-color-id"
        sessionEntity.sessionLatitude = -33.8688
        sessionEntity.sessionLongitude = 151.2093
        sessionEntity.eventIdentifier = "test-event-identifier"
        sessionEntity.calendarIdentifier = "test-calendar-identifier"
        sessionEntity.lastModifiedDate = Date()
        sessionEntity.lastSyncTag = "test-sync-tag"
        sessionEntity.recurrenceRuleData = Data()
        
        modelContext.insert(sessionEntity)
        try modelContext.save()
        
        // Test mapping
        let session = Session.from(entity: sessionEntity)
        
        // Verify all properties are mapped correctly
        XCTAssertEqual(session.id, sessionEntity.id)
        XCTAssertEqual(session.title, sessionEntity.title)
        XCTAssertEqual(session.startTime, sessionEntity.startTime)
        XCTAssertEqual(session.endTime, sessionEntity.endTime)
        XCTAssertEqual(session.isAllDay, sessionEntity.isAllDay)
        XCTAssertEqual(session.location, sessionEntity.location)
        XCTAssertEqual(session.notes, sessionEntity.notes)
        XCTAssertEqual(session.status, sessionEntity.status)
        XCTAssertEqual(session.isTravel, sessionEntity.isTravel)
        XCTAssertEqual(session.groupID, sessionEntity.groupID)
        XCTAssertEqual(session.groupedPosition, sessionEntity.groupedPosition)
        XCTAssertEqual(session.attendeesCount, sessionEntity.attendeesCount)
        XCTAssertEqual(session.derivedFromEKEventID, sessionEntity.derivedFromEKEventID)
        XCTAssertEqual(session.googleColorId, sessionEntity.googleColorId)
        XCTAssertEqual(session.sessionLatitude, sessionEntity.sessionLatitude)
        XCTAssertEqual(session.sessionLongitude, sessionEntity.sessionLongitude)
        XCTAssertEqual(session.eventIdentifier, sessionEntity.eventIdentifier)
        XCTAssertEqual(session.calendarIdentifier, sessionEntity.calendarIdentifier)
        XCTAssertEqual(session.lastModifiedDate, sessionEntity.lastModifiedDate)
        XCTAssertEqual(session.lastSyncTag, sessionEntity.lastSyncTag)
        XCTAssertEqual(session.recurrenceRuleData, sessionEntity.recurrenceRuleData)
    }
    
    // MARK: - TravelChargeEntity to TravelCharge Tests
    
    func testTravelChargeEntityToTravelChargeMapping() throws {
        // Create test TravelChargeEntity
        let travelChargeEntity = TravelChargeEntity(id: UUID())
        travelChargeEntity.mmmZoneName = "Zone 1"
        travelChargeEntity.travelDistance = 10.5
        travelChargeEntity.travelDuration = 30.0
        travelChargeEntity.vehicleType = "car"
        travelChargeEntity.parkingCost = 5.0
        travelChargeEntity.tollCost = 2.0
        travelChargeEntity.participantCount = 1
        travelChargeEntity.splitCosts = false
        travelChargeEntity.chargeType = "travel"
        travelChargeEntity.travelDirection = "outbound"
        travelChargeEntity.location = "Home to Office"
        travelChargeEntity.notes = "Status: pending"
        travelChargeEntity.lastModifiedDate = Date()
        travelChargeEntity.ekCreationDate = Date()
        
        modelContext.insert(travelChargeEntity)
        try modelContext.save()
        
        // Test mapping
        let travelCharge = TravelCharge(from: travelChargeEntity)
        
        // Verify all properties are mapped correctly
        XCTAssertEqual(travelCharge.id, travelChargeEntity.id)
        XCTAssertEqual(travelCharge.amount, travelChargeEntity.parkingCost)
        XCTAssertEqual(travelCharge.distance, travelChargeEntity.travelDistance)
        XCTAssertEqual(travelCharge.travelTime, travelChargeEntity.travelDuration)
        XCTAssertEqual(travelCharge.notes, travelChargeEntity.notes)
        XCTAssertEqual(travelCharge.lastModifiedDate, travelChargeEntity.lastModifiedDate)
        XCTAssertEqual(travelCharge.createdDate, travelChargeEntity.ekCreationDate)
        XCTAssertEqual(travelCharge.status, .pending)
    }
    
    // MARK: - NDISItemEntity to NDISItem Tests
    
    func testNDISItemEntityToNDISItemMapping() throws {
        // Create test RegionalPriceEntity
        let regionalPriceEntity = RegionalPriceEntity()
        regionalPriceEntity.id = UUID()
        regionalPriceEntity.regionIdentifier = "NSW"
        regionalPriceEntity.amount = 50.0
        
        // Create test NDISItemEntity
        let ndisItemEntity = NDISItemEntity()
        ndisItemEntity.id = UUID()
        ndisItemEntity.itemNumber = "01_001_0107_1_1"
        ndisItemEntity.name = "Test NDIS Item"
        ndisItemEntity.description = "Test description"
        ndisItemEntity.regionalPrices = [regionalPriceEntity]
        
        modelContext.insert(regionalPriceEntity)
        modelContext.insert(ndisItemEntity)
        try modelContext.save()
        
        // Test mapping
        let ndisItem = NDISItem(from: ndisItemEntity)
        
        // Verify all properties are mapped correctly
        XCTAssertEqual(ndisItem.id, ndisItemEntity.id)
        XCTAssertEqual(ndisItem.itemNumber, ndisItemEntity.itemNumber)
        XCTAssertEqual(ndisItem.name, ndisItemEntity.name)
        XCTAssertEqual(ndisItem.description, ndisItemEntity.description)
        XCTAssertEqual(ndisItem.price, 50.0) // Should extract price from regional prices using priority order
    }
    
    // MARK: - Edge Case Tests
    
    func testMappingWithNilValues() throws {
        // Create test ClientEntity with nil values
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        // Leave optional properties as nil
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Test mapping
        let client = Client(from: clientEntity)
        
        // Verify nil values are handled correctly
        XCTAssertNil(client.email)
        XCTAssertNil(client.notes)
        XCTAssertNil(client.phone)
        XCTAssertNil(client.planManagementType)
        XCTAssertNil(client.billingAuthority)
        XCTAssertNil(client.address)
        XCTAssertNil(client.planManager)
        XCTAssertNil(client.payee)
        XCTAssertNil(client.sendInvoicesToClient)
        XCTAssertNil(client.sendInvoicesToPayee)
        XCTAssertNil(client.sendInvoicesToPlanManager)
    }
    
    func testMappingWithEmptyStrings() throws {
        // Create test ClientEntity with empty strings
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.email = ""
        clientEntity.notes = ""
        clientEntity.phone = ""
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Test mapping
        let client = Client(from: clientEntity)
        
        // Verify empty strings are preserved
        XCTAssertEqual(client.email, "")
        XCTAssertEqual(client.notes, "")
        XCTAssertEqual(client.phone, "")
    }
    
    func testMappingWithZeroValues() throws {
        // Create test ClientEntity with zero values
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.creditAmount = 0.0
        clientEntity.isMinor = false
        clientEntity.hasNdisPlan = false
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Test mapping
        let client = Client(from: clientEntity)
        
        // Verify zero values are preserved
        XCTAssertEqual(client.creditAmount, 0.0)
        XCTAssertEqual(client.isMinor, false)
        XCTAssertEqual(client.hasNdisPlan, false)
    }
    
    // MARK: - Performance Tests
    
    func testMappingPerformance() throws {
        // Create multiple test entities
        let entities = (0..<1000).map { _ in
            let entity = ClientEntity(
                id: UUID(),
                ndisNumber: "123456789",
                fullName: "John Doe",
                status: "active"
            )
            entity.email = "john@example.com"
            entity.notes = "Test notes"
            entity.phone = "0412345678"
            return entity
        }
        
        entities.forEach { modelContext.insert($0) }
        try modelContext.save()
        
        // Measure mapping performance
        measure {
            let clients = entities.map { Client(from: $0) }
            XCTAssertEqual(clients.count, 1000)
        }
    }
}
