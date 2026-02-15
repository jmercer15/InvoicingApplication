//
//  EdgeCaseMappingTests.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//
//  Edge case tests for mapping with nil values and empty relationships
//  This test suite validates that all mapping operations handle edge cases
//  correctly, including nil values, empty strings, and missing relationships.
//

import XCTest
import SwiftData
@testable import Data
@testable import Core

/// Edge case tests for mapping with nil values and empty relationships
final class EdgeCaseMappingTests: XCTestCase {
    
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
            RegionalPriceEntity.self,
            ServiceAgreementEntity.self,
            SupportLogEntity.self,
            BulkClaimBatchEntity.self,
            BulkClaimLineEntity.self
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
    
    // MARK: - Nil Values Tests
    
    func testClientMappingWithAllNilValues() throws {
        // Create ClientEntity with all optional properties as nil
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        // All optional properties are nil by default
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Test mapping to domain model
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
        
        // Verify non-nil values are preserved
        XCTAssertEqual(client.id, clientEntity.id)
        XCTAssertEqual(client.ndisNumber, clientEntity.ndisNumber)
        XCTAssertEqual(client.fullName, clientEntity.fullName)
        XCTAssertEqual(client.status, clientEntity.status)
        XCTAssertEqual(client.creditAmount, 0.0)
        XCTAssertEqual(client.isMinor, false)
        XCTAssertEqual(client.hasNdisPlan, false)
    }
    
    func testPayeeMappingWithAllNilValues() throws {
        // Create PayeeEntity with all optional properties as nil
        let payeeEntity = PayeeEntity(id: UUID(), fullName: "Jane Doe")
        // All optional properties are nil by default
        
        modelContext.insert(payeeEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let payee = Payee(from: payeeEntity)
        
        // Verify nil values are handled correctly
        XCTAssertNil(payee.email)
        XCTAssertNil(payee.phone)
        XCTAssertNil(payee.address)
        XCTAssertNil(payee.status)
        
        // Verify non-nil values are preserved
        XCTAssertEqual(payee.id, payeeEntity.id)
        XCTAssertEqual(payee.fullName, payeeEntity.fullName)
    }
    
    func testPlanManagerMappingWithAllNilValues() throws {
        // Create PlanManagerEntity with all optional properties as nil
        let planManagerEntity = PlanManagerEntity(abn: "12345678901")
        planManagerEntity.id = UUID()
        // All optional properties are nil by default
        
        modelContext.insert(planManagerEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let planManager = PlanManager(from: planManagerEntity)
        
        // Verify nil values are handled correctly
        XCTAssertNil(planManager.email)
        XCTAssertNil(planManager.phone)
        XCTAssertNil(planManager.address)
        
        // Verify non-nil values are preserved
        XCTAssertEqual(planManager.id, planManagerEntity.id)
        XCTAssertEqual(planManager.name, planManagerEntity.name)
        XCTAssertEqual(planManager.abn, planManagerEntity.abn)
    }
    
    func testAddressMappingWithAllNilValues() throws {
        // Create AddressEntity with all properties as empty strings
        let addressEntity = AddressEntity()
        addressEntity.id = UUID()
        // All string properties are empty strings by default
        
        modelContext.insert(addressEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let address = Address(from: addressEntity)
        
        // Verify empty strings are handled correctly
        XCTAssertEqual(address.street, "")
        XCTAssertEqual(address.city, "")
        XCTAssertEqual(address.state, "")
        XCTAssertEqual(address.postcode, "")
        XCTAssertEqual(address.country, "")
        
        // Verify non-nil values are preserved
        XCTAssertEqual(address.id, addressEntity.id)
    }
    
    // MARK: - Empty Strings Tests
    
    func testClientMappingWithEmptyStrings() throws {
        // Create ClientEntity with empty strings
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.email = ""
        clientEntity.notes = ""
        clientEntity.phone = ""
        clientEntity.planManagementType = ""
        clientEntity.billingAuthority = ""
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let client = Client(from: clientEntity)
        
        // Verify empty strings are preserved
        XCTAssertEqual(client.email, "")
        XCTAssertEqual(client.notes, "")
        XCTAssertEqual(client.phone, "")
        XCTAssertEqual(client.planManagementType, "")
        XCTAssertEqual(client.billingAuthority, "")
    }
    
    func testPayeeMappingWithEmptyStrings() throws {
        // Create PayeeEntity with empty strings
        let payeeEntity = PayeeEntity(id: UUID(), fullName: "Jane Doe")
        payeeEntity.email = ""
        payeeEntity.phone = ""
        payeeEntity.status = ""
        payeeEntity.relationToClient = ""
        
        modelContext.insert(payeeEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let payee = Payee(from: payeeEntity)
        
        // Verify empty strings are preserved
        XCTAssertEqual(payee.email, "")
        XCTAssertEqual(payee.phone, "")
        XCTAssertEqual(payee.status, "")
    }
    
    // MARK: - Zero Values Tests
    
    func testClientMappingWithZeroValues() throws {
        // Create ClientEntity with zero values
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
        
        // Test mapping to domain model
        let client = Client(from: clientEntity)
        
        // Verify zero values are preserved
        XCTAssertEqual(client.creditAmount, 0.0)
        XCTAssertEqual(client.isMinor, false)
        XCTAssertEqual(client.hasNdisPlan, false)
    }
    
    func testSessionMappingWithZeroValues() throws {
        // Create SessionEntity with zero values
        let sessionEntity = SessionEntity(id: UUID())
        sessionEntity.title = "Test Session"
        sessionEntity.groupedPosition = 0
        sessionEntity.attendeesCount = 0
        sessionEntity.sessionLatitude = 0.0
        sessionEntity.sessionLongitude = 0.0
        
        modelContext.insert(sessionEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let session = Session.from(entity: sessionEntity)
        
        // Verify zero values are preserved
        XCTAssertEqual(session.groupedPosition, 0)
        XCTAssertEqual(session.attendeesCount, 0)
        XCTAssertEqual(session.sessionLatitude, 0.0)
        XCTAssertEqual(session.sessionLongitude, 0.0)
    }
    
    // MARK: - Missing Relationships Tests
    
    func testClientMappingWithMissingRelationships() throws {
        // Create ClientEntity without relationships
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        // No relationships set
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let client = Client(from: clientEntity)
        
        // Verify missing relationships are handled correctly
        XCTAssertNil(client.address)
        XCTAssertNil(client.planManager)
        XCTAssertNil(client.payee)
    }
    
    func testPayeeMappingWithMissingAddress() throws {
        // Create PayeeEntity without address
        let payeeEntity = PayeeEntity(id: UUID(), fullName: "Jane Doe")
        // No address relationship set
        
        modelContext.insert(payeeEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let payee = Payee(from: payeeEntity)
        
        // Verify missing address is handled correctly
        XCTAssertNil(payee.address)
    }
    
    func testPlanManagerMappingWithMissingAddress() throws {
        // Create PlanManagerEntity without address
        let planManagerEntity = PlanManagerEntity(abn: "12345678901")
        planManagerEntity.id = UUID()
        planManagerEntity.name = "Test Plan Manager"
        // No address relationship set
        
        modelContext.insert(planManagerEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let planManager = PlanManager(from: planManagerEntity)
        
        // Verify missing address is handled correctly
        XCTAssertNil(planManager.address)
    }
    
    // MARK: - Data Type Edge Cases Tests
    
    func testSessionMappingWithDataEdgeCases() throws {
        // Create SessionEntity with edge case data
        let sessionEntity = SessionEntity(id: UUID())
        sessionEntity.title = "Test Session"
        sessionEntity.recurrenceRuleData = Data() // Empty data
        sessionEntity.alarmsData = Data() // Empty data
        
        modelContext.insert(sessionEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let session = Session.from(entity: sessionEntity)
        
        // Verify data edge cases are handled correctly
        XCTAssertEqual(session.recurrenceRuleData, Data())
    }
    
    func testTravelChargeMappingWithDataEdgeCases() throws {
        // Create TravelChargeEntity with edge case data
        let travelChargeEntity = TravelChargeEntity(id: UUID())
        travelChargeEntity.travelDistance = 0.0
        travelChargeEntity.travelDuration = 0.0
        travelChargeEntity.parkingCost = 0.0
        travelChargeEntity.tollCost = 0.0
        travelChargeEntity.participantCount = 0
        travelChargeEntity.splitCosts = false
        
        modelContext.insert(travelChargeEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let travelCharge = TravelCharge(from: travelChargeEntity)
        
        // Verify data edge cases are handled correctly
        XCTAssertEqual(travelCharge.amount, 0.0)
        XCTAssertEqual(travelCharge.distance, 0.0)
        XCTAssertEqual(travelCharge.travelTime, 0.0)
    }
    
    // MARK: - Date Edge Cases Tests
    
    func testSessionMappingWithDateEdgeCases() throws {
        // Create SessionEntity with edge case dates
        let sessionEntity = SessionEntity(id: UUID())
        sessionEntity.title = "Test Session"
        sessionEntity.startTime = Date(timeIntervalSince1970: 0) // Epoch
        sessionEntity.endTime = Date(timeIntervalSince1970: 0) // Epoch
        sessionEntity.lastModifiedDate = Date(timeIntervalSince1970: 0) // Epoch
        sessionEntity.ekCreationDate = Date(timeIntervalSince1970: 0) // Epoch
        
        modelContext.insert(sessionEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let session = Session.from(entity: sessionEntity)
        
        // Verify date edge cases are handled correctly
        XCTAssertEqual(session.startTime, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(session.endTime, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(session.lastModifiedDate, Date(timeIntervalSince1970: 0))
    }
    
    func testTravelChargeMappingWithDateEdgeCases() throws {
        // Create TravelChargeEntity with edge case dates
        let travelChargeEntity = TravelChargeEntity(id: UUID())
        travelChargeEntity.lastModifiedDate = Date(timeIntervalSince1970: 0) // Epoch
        travelChargeEntity.ekCreationDate = Date(timeIntervalSince1970: 0) // Epoch
        
        modelContext.insert(travelChargeEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let travelCharge = TravelCharge(from: travelChargeEntity)
        
        // Verify date edge cases are handled correctly
        XCTAssertEqual(travelCharge.lastModifiedDate, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(travelCharge.createdDate, Date(timeIntervalSince1970: 0))
    }
    
    // MARK: - String Edge Cases Tests
    
    func testClientMappingWithStringEdgeCases() throws {
        // Create ClientEntity with edge case strings
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.email = "test@example.com"
        clientEntity.notes = "Line 1\nLine 2\nLine 3" // Multi-line string
        clientEntity.phone = "+61 412 345 678" // Phone with formatting
        clientEntity.planManagementType = "plan_managed" // Underscore string
        clientEntity.billingAuthority = "NDIA" // Acronym
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let client = Client(from: clientEntity)
        
        // Verify string edge cases are handled correctly
        XCTAssertEqual(client.email, "test@example.com")
        XCTAssertEqual(client.notes, "Line 1\nLine 2\nLine 3")
        XCTAssertEqual(client.phone, "+61 412 345 678")
        XCTAssertEqual(client.planManagementType, "plan_managed")
        XCTAssertEqual(client.billingAuthority, "NDIA")
    }
    
    // MARK: - Boolean Edge Cases Tests
    
    func testClientMappingWithBooleanEdgeCases() throws {
        // Create ClientEntity with boolean edge cases
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.isMinor = true
        clientEntity.hasNdisPlan = true
        clientEntity.sendInvoicesToClient = true
        clientEntity.sendInvoicesToPayee = false
        clientEntity.sendInvoicesToPlanManager = true
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let client = Client(from: clientEntity)
        
        // Verify boolean edge cases are handled correctly
        XCTAssertEqual(client.isMinor, true)
        XCTAssertEqual(client.hasNdisPlan, true)
        XCTAssertEqual(client.sendInvoicesToClient, true)
        XCTAssertEqual(client.sendInvoicesToPayee, false)
        XCTAssertEqual(client.sendInvoicesToPlanManager, true)
    }
    
    // MARK: - Numeric Edge Cases Tests
    
    func testClientMappingWithNumericEdgeCases() throws {
        // Create ClientEntity with numeric edge cases
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.creditAmount = 999999.99 // Large positive number
        clientEntity.creditAmount = -999999.99 // Large negative number
        clientEntity.creditAmount = 0.01 // Small positive number
        clientEntity.creditAmount = -0.01 // Small negative number
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let client = Client(from: clientEntity)
        
        // Verify numeric edge cases are handled correctly
        XCTAssertEqual(client.creditAmount, -0.01) // Last assigned value
    }
    
    // MARK: - UUID Edge Cases Tests
    
    func testClientMappingWithUUIDEdgeCases() throws {
        // Create ClientEntity with UUID edge cases
        let nilUUID = UUID()
        let clientEntity = ClientEntity(
            id: nilUUID,
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.groupID = nilUUID // Same UUID
        
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Test mapping to domain model
        let client = Client(from: clientEntity)
        
        // Verify UUID edge cases are handled correctly
        XCTAssertEqual(client.id, nilUUID)
        XCTAssertEqual(client.groupID, nilUUID)
    }
}
