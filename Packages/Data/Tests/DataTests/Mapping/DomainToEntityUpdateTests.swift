//
//  DomainToEntityUpdateTests.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//
//  Unit tests for all domain-to-entity update methods
//  This test suite validates that all domain model to entity update operations
//  work correctly and maintain data integrity.
//

import XCTest
import SwiftData
@testable import Data
@testable import Core

/// Unit tests for domain-to-entity update methods
final class DomainToEntityUpdateTests: XCTestCase {
    
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
    
    // MARK: - Client to ClientEntity Update Tests
    
    func testClientToClientEntityUpdate() throws {
        // Create test ClientEntity
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.email = "old@example.com"
        clientEntity.notes = "Old notes"
        clientEntity.phone = "0412345678"
        clientEntity.creditAmount = 50.0
        clientEntity.isMinor = false
        clientEntity.hasNdisPlan = false
        clientEntity.planManagementType = "self_managed"
        clientEntity.billingAuthority = "NDIA"
        clientEntity.sendInvoicesToClient = false
        clientEntity.sendInvoicesToPayee = true
        clientEntity.sendInvoicesToPlanManager = false
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Create updated Client domain model
        let updatedClient = Client(
            id: clientEntity.id,
            ndisNumber: "987654321",
            fullName: "Jane Smith",
            status: "inactive",
            email: "new@example.com",
            notes: "New notes",
            phone: "0498765432",
            creditAmount: 200.0,
            isMinor: true,
            hasNdisPlan: true,
            planManagementType: "plan_managed",
            billingAuthority: "NDIA",
            address: nil,
            planManager: nil,
            payee: nil,
            sendInvoicesToClient: true,
            sendInvoicesToPayee: false,
            sendInvoicesToPlanManager: true
        )
        
        // Test update
        clientEntity.update(from: updatedClient)
        try modelContext.save()
        
        // Verify all properties are updated correctly
        XCTAssertEqual(clientEntity.ndisNumber, "987654321")
        XCTAssertEqual(clientEntity.fullName, "Jane Smith")
        XCTAssertEqual(clientEntity.status, "inactive")
        XCTAssertEqual(clientEntity.email, "new@example.com")
        XCTAssertEqual(clientEntity.notes, "New notes")
        XCTAssertEqual(clientEntity.phone, "0498765432")
        XCTAssertEqual(clientEntity.creditAmount, 200.0)
        XCTAssertEqual(clientEntity.isMinor, true)
        XCTAssertEqual(clientEntity.hasNdisPlan, true)
        XCTAssertEqual(clientEntity.planManagementType, "plan_managed")
        XCTAssertEqual(clientEntity.billingAuthority, "NDIA")
        XCTAssertEqual(clientEntity.sendInvoicesToClient, true)
        XCTAssertEqual(clientEntity.sendInvoicesToPayee, false)
        XCTAssertEqual(clientEntity.sendInvoicesToPlanManager, true)
    }
    
    func testClientToClientEntityUpdateWithNilValues() throws {
        // Create test ClientEntity with values
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.email = "old@example.com"
        clientEntity.notes = "Old notes"
        clientEntity.phone = "0412345678"
        clientEntity.planManagementType = "self_managed"
        clientEntity.billingAuthority = "NDIA"
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Create updated Client domain model with nil values
        let updatedClient = Client(
            id: clientEntity.id,
            ndisNumber: "987654321",
            fullName: "Jane Smith",
            status: "inactive",
            email: nil,
            notes: nil,
            phone: nil,
            creditAmount: 0.0,
            isMinor: false,
            hasNdisPlan: false,
            planManagementType: nil,
            billingAuthority: nil,
            address: nil,
            planManager: nil,
            payee: nil,
            sendInvoicesToClient: nil,
            sendInvoicesToPayee: nil,
            sendInvoicesToPlanManager: nil
        )
        
        // Test update
        clientEntity.update(from: updatedClient)
        try modelContext.save()
        
        // Verify nil values are set correctly
        XCTAssertEqual(clientEntity.ndisNumber, "987654321")
        XCTAssertEqual(clientEntity.fullName, "Jane Smith")
        XCTAssertEqual(clientEntity.status, "inactive")
        XCTAssertNil(clientEntity.email)
        XCTAssertNil(clientEntity.notes)
        XCTAssertNil(clientEntity.phone)
        XCTAssertEqual(clientEntity.creditAmount, 0.0)
        XCTAssertEqual(clientEntity.isMinor, false)
        XCTAssertEqual(clientEntity.hasNdisPlan, false)
        XCTAssertNil(clientEntity.planManagementType)
        XCTAssertNil(clientEntity.billingAuthority)
        XCTAssertNil(clientEntity.sendInvoicesToClient)
        XCTAssertNil(clientEntity.sendInvoicesToPayee)
        XCTAssertNil(clientEntity.sendInvoicesToPlanManager)
    }
    
    // MARK: - Payee to PayeeEntity Update Tests
    
    func testPayeeToPayeeEntityUpdate() throws {
        // Create test PayeeEntity
        let payeeEntity = PayeeEntity(id: UUID(), fullName: "Old Name")
        payeeEntity.email = "old@example.com"
        payeeEntity.phone = "0412345678"
        payeeEntity.status = "inactive"
        payeeEntity.relationToClient = "guardian"
        payeeEntity.payeeID = 12345
        
        modelContext.insert(payeeEntity)
        try modelContext.save()
        
        // Create updated Payee domain model
        let updatedPayee = Payee(
            id: payeeEntity.id,
            fullName: "New Name",
            email: "new@example.com",
            phone: "0498765432",
            address: nil,
            status: "active"
        )
        
        // Test update
        payeeEntity.update(from: updatedPayee)
        try modelContext.save()
        
        // Verify all properties are updated correctly
        XCTAssertEqual(payeeEntity.fullName, "New Name")
        XCTAssertEqual(payeeEntity.email, "new@example.com")
        XCTAssertEqual(payeeEntity.phone, "0498765432")
        XCTAssertEqual(payeeEntity.status, "active")
    }
    
    // MARK: - PlanManager to PlanManagerEntity Update Tests
    
    func testPlanManagerToPlanManagerEntityUpdate() throws {
        // Create test PlanManagerEntity
        let planManagerEntity = PlanManagerEntity(abn: "12345678901")
        planManagerEntity.id = UUID()
        planManagerEntity.name = "Old Name"
        planManagerEntity.email = "old@example.com"
        planManagerEntity.phone = "0412345678"
        
        modelContext.insert(planManagerEntity)
        try modelContext.save()
        
        // Create updated PlanManager domain model
        let updatedPlanManager = PlanManager(
            id: planManagerEntity.id,
            name: "New Name",
            email: "new@example.com",
            phone: "0498765432",
            address: nil,
            abn: "98765432109"
        )
        
        // Test update
        planManagerEntity.update(from: updatedPlanManager)
        try modelContext.save()
        
        // Verify all properties are updated correctly
        XCTAssertEqual(planManagerEntity.name, "New Name")
        XCTAssertEqual(planManagerEntity.email, "new@example.com")
        XCTAssertEqual(planManagerEntity.phone, "0498765432")
        XCTAssertEqual(planManagerEntity.abn, "98765432109")
    }
    
    // MARK: - Address to AddressEntity Update Tests
    
    func testAddressToAddressEntityUpdate() throws {
        // Create test AddressEntity
        let addressEntity = AddressEntity()
        addressEntity.id = UUID()
        addressEntity.streetNumber = "123"
        addressEntity.streetName = "Old St"
        addressEntity.city = "Old City"
        addressEntity.state = "Old State"
        addressEntity.postcode = "2000"
        addressEntity.country = "Old Country"
        addressEntity.unitNumber = "Unit 1"
        addressEntity.poBox = "PO Box 123"
        
        modelContext.insert(addressEntity)
        try modelContext.save()
        
        // Create updated Address domain model
        let updatedAddress = Address(
            id: addressEntity.id,
            unitNumber: "",
            streetNumber: "456",
            streetName: "New St",
            suburb: "",
            city: "New City",
            state: "New State",
            postcode: "3000",
            country: "New Country",
            poBox: "",
            latitude: 0.0,
            longitude: 0.0
        )
        
        // Test update
        addressEntity.update(from: updatedAddress)
        try modelContext.save()
        
        // Verify all properties are updated correctly
        XCTAssertEqual(addressEntity.streetNumber, "456")
        XCTAssertEqual(addressEntity.streetName, "New St")
        XCTAssertEqual(addressEntity.city, "New City")
        XCTAssertEqual(addressEntity.state, "New State")
        XCTAssertEqual(addressEntity.postcode, "3000")
        XCTAssertEqual(addressEntity.country, "New Country")
    }
    
    // MARK: - Session to SessionEntity Update Tests
    
    func testSessionToSessionEntityUpdate() throws {
        // Create test SessionEntity
        let sessionEntity = SessionEntity(id: UUID())
        sessionEntity.title = "Old Title"
        sessionEntity.startTime = Date()
        sessionEntity.endTime = Date().addingTimeInterval(3600)
        sessionEntity.isAllDay = false
        sessionEntity.location = "Old Location"
        sessionEntity.notes = "Old Notes"
        sessionEntity.status = "old_status"
        sessionEntity.isTravel = false
        sessionEntity.groupID = UUID()
        sessionEntity.groupedPosition = 1
        sessionEntity.attendeesCount = 2
        sessionEntity.derivedFromEKEventID = "old-event-id"
        sessionEntity.googleColorId = "old-color-id"
        sessionEntity.sessionLatitude = -33.8688
        sessionEntity.sessionLongitude = 151.2093
        sessionEntity.eventIdentifier = "old-event-identifier"
        sessionEntity.calendarIdentifier = "old-calendar-identifier"
        sessionEntity.lastModifiedDate = Date()
        sessionEntity.lastSyncTag = "old-sync-tag"
        sessionEntity.recurrenceRuleData = Data()
        
        modelContext.insert(sessionEntity)
        try modelContext.save()
        
        // Create updated Session domain model
        let updatedSession = Session(
            id: sessionEntity.id,
            title: "New Title",
            startTime: Date().addingTimeInterval(3600),
            endTime: Date().addingTimeInterval(7200),
            isAllDay: true,
            location: "New Location",
            notes: "New Notes",
            status: "new_status",
            isTravel: true,
            clientId: nil,
            clientServiceId: nil,
            addressId: nil,
            groupID: UUID(),
            groupedPosition: 2,
            eventIdentifier: "new-event-identifier",
            calendarIdentifier: "new-calendar-identifier",
            lastModifiedDate: Date().addingTimeInterval(3600),
            lastSyncTag: "new-sync-tag",
            recurrenceRuleData: Data(),
            attendeesCount: 3,
            derivedFromEKEventID: "new-event-id",
            googleColorId: "new-color-id",
            sessionLatitude: -34.9285,
            sessionLongitude: 138.6007
        )
        
        // Test update
        sessionEntity.update(from: updatedSession)
        try modelContext.save()
        
        // Verify all properties are updated correctly
        XCTAssertEqual(sessionEntity.title, "New Title")
        XCTAssertEqual(sessionEntity.startTime, updatedSession.startTime)
        XCTAssertEqual(sessionEntity.endTime, updatedSession.endTime)
        XCTAssertEqual(sessionEntity.isAllDay, true)
        XCTAssertEqual(sessionEntity.location, "New Location")
        XCTAssertEqual(sessionEntity.notes, "New Notes")
        XCTAssertEqual(sessionEntity.status, "new_status")
        XCTAssertEqual(sessionEntity.isTravel, true)
        XCTAssertEqual(sessionEntity.groupID, updatedSession.groupID)
        XCTAssertEqual(sessionEntity.groupedPosition, 2)
        XCTAssertEqual(sessionEntity.attendeesCount, 3)
        XCTAssertEqual(sessionEntity.derivedFromEKEventID, "new-event-id")
        XCTAssertEqual(sessionEntity.googleColorId, "new-color-id")
        XCTAssertEqual(sessionEntity.sessionLatitude, -34.9285)
        XCTAssertEqual(sessionEntity.sessionLongitude, 138.6007)
        XCTAssertEqual(sessionEntity.eventIdentifier, "new-event-identifier")
        XCTAssertEqual(sessionEntity.calendarIdentifier, "new-calendar-identifier")
        XCTAssertEqual(sessionEntity.lastModifiedDate, updatedSession.lastModifiedDate)
        XCTAssertEqual(sessionEntity.lastSyncTag, "new-sync-tag")
        XCTAssertEqual(sessionEntity.recurrenceRuleData, updatedSession.recurrenceRuleData)
    }
    
    // MARK: - TravelCharge to TravelChargeEntity Update Tests
    
    func testTravelChargeToTravelChargeEntityUpdate() throws {
        // Create test TravelChargeEntity
        let travelChargeEntity = TravelChargeEntity(id: UUID())
        travelChargeEntity.mmmZoneName = "Old Zone"
        travelChargeEntity.travelDistance = 5.0
        travelChargeEntity.travelDuration = 15.0
        travelChargeEntity.vehicleType = "bike"
        travelChargeEntity.parkingCost = 2.0
        travelChargeEntity.tollCost = 1.0
        travelChargeEntity.participantCount = 1
        travelChargeEntity.splitCosts = true
        travelChargeEntity.chargeType = "old_charge"
        travelChargeEntity.travelDirection = "inbound"
        travelChargeEntity.location = "Old Location"
        travelChargeEntity.notes = "Status: pending"
        travelChargeEntity.lastModifiedDate = Date()
        travelChargeEntity.ekCreationDate = Date()
        
        modelContext.insert(travelChargeEntity)
        try modelContext.save()
        
        // Create updated TravelCharge domain model
        let updatedTravelCharge = TravelCharge(
            id: travelChargeEntity.id,
            sessionId: UUID(),
            amount: 10.0,
            distance: 20.0,
            travelTime: 45.0,
            fromAddress: "Home",
            toAddress: "Office",
            status: .approved,
            createdDate: Date().addingTimeInterval(3600),
            lastModifiedDate: Date().addingTimeInterval(3600),
            notes: "Status: approved"
        )
        
        // Test update
        travelChargeEntity.update(from: updatedTravelCharge)
        try modelContext.save()
        
        // Verify all properties are updated correctly
        XCTAssertEqual(travelChargeEntity.travelDistance, 20.0)
        XCTAssertEqual(travelChargeEntity.travelDuration, 45.0)
        XCTAssertEqual(travelChargeEntity.parkingCost, 10.0)
        XCTAssertEqual(travelChargeEntity.notes, "Status: approved")
        XCTAssertEqual(travelChargeEntity.lastModifiedDate, updatedTravelCharge.lastModifiedDate)
        XCTAssertEqual(travelChargeEntity.location, "Home to Office")
    }
    
    // MARK: - Edge Case Tests
    
    func testUpdateWithEmptyStrings() throws {
        // Create test ClientEntity
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.email = "old@example.com"
        clientEntity.notes = "Old notes"
        clientEntity.phone = "0412345678"
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Create updated Client domain model with empty strings
        let updatedClient = Client(
            id: clientEntity.id,
            ndisNumber: "987654321",
            fullName: "Jane Smith",
            status: "inactive",
            email: "",
            notes: "",
            phone: "",
            creditAmount: 0.0,
            isMinor: false,
            hasNdisPlan: false,
            planManagementType: nil,
            billingAuthority: nil,
            address: nil,
            planManager: nil,
            payee: nil,
            sendInvoicesToClient: nil,
            sendInvoicesToPayee: nil,
            sendInvoicesToPlanManager: nil
        )
        
        // Test update
        clientEntity.update(from: updatedClient)
        try modelContext.save()
        
        // Verify empty strings are preserved
        XCTAssertEqual(clientEntity.email, "")
        XCTAssertEqual(clientEntity.notes, "")
        XCTAssertEqual(clientEntity.phone, "")
    }
    
    func testUpdateWithZeroValues() throws {
        // Create test ClientEntity
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.creditAmount = 100.0
        clientEntity.isMinor = true
        clientEntity.hasNdisPlan = true
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Create updated Client domain model with zero values
        let updatedClient = Client(
            id: clientEntity.id,
            ndisNumber: "987654321",
            fullName: "Jane Smith",
            status: "inactive",
            email: nil,
            notes: nil,
            phone: nil,
            creditAmount: 0.0,
            isMinor: false,
            hasNdisPlan: false,
            planManagementType: nil,
            billingAuthority: nil,
            address: nil,
            planManager: nil,
            payee: nil,
            sendInvoicesToClient: nil,
            sendInvoicesToPayee: nil,
            sendInvoicesToPlanManager: nil
        )
        
        // Test update
        clientEntity.update(from: updatedClient)
        try modelContext.save()
        
        // Verify zero values are preserved
        XCTAssertEqual(clientEntity.creditAmount, 0.0)
        XCTAssertEqual(clientEntity.isMinor, false)
        XCTAssertEqual(clientEntity.hasNdisPlan, false)
    }
    
    // MARK: - Performance Tests
    
    func testUpdatePerformance() throws {
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
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Create updated Client domain model
        let updatedClient = Client(
            id: clientEntity.id,
            ndisNumber: "987654321",
            fullName: "Jane Smith",
            status: "inactive",
            email: "jane@example.com",
            notes: "Updated notes",
            phone: "0498765432",
            creditAmount: 100.0,
            isMinor: false,
            hasNdisPlan: true,
            planManagementType: "plan_managed",
            billingAuthority: "NDIA",
            address: nil,
            planManager: nil,
            payee: nil,
            sendInvoicesToClient: true,
            sendInvoicesToPayee: false,
            sendInvoicesToPlanManager: true
        )
        
        // Measure update performance
        measure {
            clientEntity.update(from: updatedClient)
        }
    }
}
