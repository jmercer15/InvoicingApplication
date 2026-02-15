//
//  RelationshipDeletionTests.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//
//  Unit tests for relationship deletion scenarios
//  This test suite validates that all @Relationship delete rules work correctly
//  and that data integrity is maintained during deletion operations.
//

import XCTest
import SwiftData
@testable import Data
@testable import Core

/// Unit tests for relationship deletion scenarios
final class RelationshipDeletionTests: XCTestCase {
    
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
    
    // MARK: - Cascade Delete Rule Tests
    
    func testClientEntityCascadeDeleteWithClientServices() throws {
        // Create test ClientEntity
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        
        // Create test ClientServiceEntity
        let clientServiceEntity = ClientServiceEntity()
        clientServiceEntity.id = UUID()
        clientServiceEntity.client = clientEntity
        clientEntity.clientServices.append(clientServiceEntity)
        
        modelContext.insert(clientEntity)
        modelContext.insert(clientServiceEntity)
        try modelContext.save()
        
        // Verify client service exists
        let clientServiceDescriptor = FetchDescriptor<ClientServiceEntity>()
        let clientServices = try modelContext.fetch(clientServiceDescriptor)
        XCTAssertEqual(clientServices.count, 1)
        
        // Delete client entity
        modelContext.delete(clientEntity)
        try modelContext.save()
        
        // Verify client service is cascade deleted
        let remainingClientServices = try modelContext.fetch(clientServiceDescriptor)
        XCTAssertEqual(remainingClientServices.count, 0)
    }
    
    func testClientEntityCascadeDeleteWithCreditHistory() throws {
        // Create test ClientEntity
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        
        // Create test CreditHistoryEntryEntity
        let creditHistoryEntity = CreditHistoryEntryEntity()
        creditHistoryEntity.id = UUID()
        creditHistoryEntity.client = clientEntity
        clientEntity.creditHistory.append(creditHistoryEntity)
        
        modelContext.insert(clientEntity)
        modelContext.insert(creditHistoryEntity)
        try modelContext.save()
        
        // Verify credit history exists
        let creditHistoryDescriptor = FetchDescriptor<CreditHistoryEntryEntity>()
        let creditHistory = try modelContext.fetch(creditHistoryDescriptor)
        XCTAssertEqual(creditHistory.count, 1)
        
        // Delete client entity
        modelContext.delete(clientEntity)
        try modelContext.save()
        
        // Verify credit history is cascade deleted
        let remainingCreditHistory = try modelContext.fetch(creditHistoryDescriptor)
        XCTAssertEqual(remainingCreditHistory.count, 0)
    }
    
    func testClientEntityCascadeDeleteWithTravelCharges() throws {
        // Create test ClientEntity
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        
        // Create test TravelChargeEntity
        let travelChargeEntity = TravelChargeEntity(id: UUID())
        travelChargeEntity.client = clientEntity
        clientEntity.travelCharges.append(travelChargeEntity)
        
        modelContext.insert(clientEntity)
        modelContext.insert(travelChargeEntity)
        try modelContext.save()
        
        // Verify travel charge exists
        let travelChargeDescriptor = FetchDescriptor<TravelChargeEntity>()
        let travelCharges = try modelContext.fetch(travelChargeDescriptor)
        XCTAssertEqual(travelCharges.count, 1)
        
        // Delete client entity
        modelContext.delete(clientEntity)
        try modelContext.save()
        
        // Verify travel charge is cascade deleted
        let remainingTravelCharges = try modelContext.fetch(travelChargeDescriptor)
        XCTAssertEqual(remainingTravelCharges.count, 0)
    }
    
    // MARK: - Nullify Delete Rule Tests
    
    func testClientEntityNullifyDeleteWithSessions() throws {
        // Create test ClientEntity
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        
        // Create test SessionEntity
        let sessionEntity = SessionEntity(id: UUID())
        sessionEntity.title = "Test Session"
        sessionEntity.client = clientEntity
        clientEntity.sessions.append(sessionEntity)
        
        modelContext.insert(clientEntity)
        modelContext.insert(sessionEntity)
        try modelContext.save()
        
        // Verify session exists and has client reference
        let sessionDescriptor = FetchDescriptor<SessionEntity>()
        let sessions = try modelContext.fetch(sessionDescriptor)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertNotNil(sessions.first?.client)
        
        // Delete client entity
        modelContext.delete(clientEntity)
        try modelContext.save()
        
        // Verify session still exists but client reference is nullified
        let remainingSessions = try modelContext.fetch(sessionDescriptor)
        XCTAssertEqual(remainingSessions.count, 1)
        XCTAssertNil(remainingSessions.first?.client)
    }
    
    func testClientEntityNullifyDeleteWithInvoices() throws {
        // Create test ClientEntity
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        
        // Create test InvoiceEntity
        let invoiceEntity = InvoiceEntity()
        invoiceEntity.id = UUID()
        invoiceEntity.client = clientEntity
        clientEntity.invoices.append(invoiceEntity)
        
        modelContext.insert(clientEntity)
        modelContext.insert(invoiceEntity)
        try modelContext.save()
        
        // Verify invoice exists and has client reference
        let invoiceDescriptor = FetchDescriptor<InvoiceEntity>()
        let invoices = try modelContext.fetch(invoiceDescriptor)
        XCTAssertEqual(invoices.count, 1)
        XCTAssertNotNil(invoices.first?.client)
        
        // Delete client entity
        modelContext.delete(clientEntity)
        try modelContext.save()
        
        // Verify invoice still exists but client reference is nullified
        let remainingInvoices = try modelContext.fetch(invoiceDescriptor)
        XCTAssertEqual(remainingInvoices.count, 1)
        XCTAssertNil(remainingInvoices.first?.client)
    }
    
    func testPayeeEntityNullifyDeleteWithGuardedClients() throws {
        // Create test PayeeEntity
        let payeeEntity = PayeeEntity(id: UUID(), fullName: "Jane Doe")
        
        // Create test ClientEntity
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.payee = payeeEntity
        payeeEntity.guardedClients.append(clientEntity)
        
        modelContext.insert(payeeEntity)
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Verify client exists and has payee reference
        let clientDescriptor = FetchDescriptor<ClientEntity>()
        let clients = try modelContext.fetch(clientDescriptor)
        XCTAssertEqual(clients.count, 1)
        XCTAssertNotNil(clients.first?.payee)
        
        // Delete payee entity
        modelContext.delete(payeeEntity)
        try modelContext.save()
        
        // Verify client still exists but payee reference is nullified
        let remainingClients = try modelContext.fetch(clientDescriptor)
        XCTAssertEqual(remainingClients.count, 1)
        XCTAssertNil(remainingClients.first?.payee)
    }
    
    func testPayeeEntityNullifyDeleteWithInvoices() throws {
        // Create test PayeeEntity
        let payeeEntity = PayeeEntity(id: UUID(), fullName: "Jane Doe")
        
        // Create test InvoiceEntity
        let invoiceEntity = InvoiceEntity()
        invoiceEntity.id = UUID()
        invoiceEntity.payee = payeeEntity
        payeeEntity.invoices.append(invoiceEntity)
        
        modelContext.insert(payeeEntity)
        modelContext.insert(invoiceEntity)
        try modelContext.save()
        
        // Verify invoice exists and has payee reference
        let invoiceDescriptor = FetchDescriptor<InvoiceEntity>()
        let invoices = try modelContext.fetch(invoiceDescriptor)
        XCTAssertEqual(invoices.count, 1)
        XCTAssertNotNil(invoices.first?.payee)
        
        // Delete payee entity
        modelContext.delete(payeeEntity)
        try modelContext.save()
        
        // Verify invoice still exists but payee reference is nullified
        let remainingInvoices = try modelContext.fetch(invoiceDescriptor)
        XCTAssertEqual(remainingInvoices.count, 1)
        XCTAssertNil(remainingInvoices.first?.payee)
    }
    
    func testPlanManagerEntityNullifyDeleteWithClients() throws {
        // Create test PlanManagerEntity
        let planManagerEntity = PlanManagerEntity(abn: "12345678901")
        planManagerEntity.id = UUID()
        planManagerEntity.name = "Test Plan Manager"
        
        // Create test ClientEntity
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.planManager = planManagerEntity
        
        modelContext.insert(planManagerEntity)
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Verify client exists and has plan manager reference
        let clientDescriptor = FetchDescriptor<ClientEntity>()
        let clients = try modelContext.fetch(clientDescriptor)
        XCTAssertEqual(clients.count, 1)
        XCTAssertNotNil(clients.first?.planManager)
        
        // Delete plan manager entity
        modelContext.delete(planManagerEntity)
        try modelContext.save()
        
        // Verify client still exists but plan manager reference is nullified
        let remainingClients = try modelContext.fetch(clientDescriptor)
        XCTAssertEqual(remainingClients.count, 1)
        XCTAssertNil(remainingClients.first?.planManager)
    }
    
    func testAddressEntityNullifyDeleteWithClients() throws {
        // Create test AddressEntity
        let addressEntity = AddressEntity()
        addressEntity.id = UUID()
        addressEntity.streetNumber = "123"
        addressEntity.streetName = "Main St"
        addressEntity.city = "Sydney"
        addressEntity.state = "NSW"
        addressEntity.postcode = "2000"
        addressEntity.country = "Australia"
        
        // Create test ClientEntity
        let clientEntity = ClientEntity(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.address = addressEntity
        
        modelContext.insert(addressEntity)
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Verify client exists and has address reference
        let clientDescriptor = FetchDescriptor<ClientEntity>()
        let clients = try modelContext.fetch(clientDescriptor)
        XCTAssertEqual(clients.count, 1)
        XCTAssertNotNil(clients.first?.address)
        
        // Delete address entity
        modelContext.delete(addressEntity)
        try modelContext.save()
        
        // Verify client still exists but address reference is nullified
        let remainingClients = try modelContext.fetch(clientDescriptor)
        XCTAssertEqual(remainingClients.count, 1)
        XCTAssertNil(remainingClients.first?.address)
    }
    
    func testAddressEntityNullifyDeleteWithPayees() throws {
        // Create test AddressEntity
        let addressEntity = AddressEntity()
        addressEntity.id = UUID()
        addressEntity.streetNumber = "123"
        addressEntity.streetName = "Main St"
        addressEntity.city = "Sydney"
        addressEntity.state = "NSW"
        addressEntity.postcode = "2000"
        addressEntity.country = "Australia"
        
        // Create test PayeeEntity
        let payeeEntity = PayeeEntity(id: UUID(), fullName: "Jane Doe")
        payeeEntity.address = addressEntity
        
        modelContext.insert(addressEntity)
        modelContext.insert(payeeEntity)
        try modelContext.save()
        
        // Verify payee exists and has address reference
        let payeeDescriptor = FetchDescriptor<PayeeEntity>()
        let payees = try modelContext.fetch(payeeDescriptor)
        XCTAssertEqual(payees.count, 1)
        XCTAssertNotNil(payees.first?.address)
        
        // Delete address entity
        modelContext.delete(addressEntity)
        try modelContext.save()
        
        // Verify payee still exists but address reference is nullified
        let remainingPayees = try modelContext.fetch(payeeDescriptor)
        XCTAssertEqual(remainingPayees.count, 1)
        XCTAssertNil(remainingPayees.first?.address)
    }
    
    func testAddressEntityNullifyDeleteWithPlanManagers() throws {
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
        planManagerEntity.address = addressEntity
        
        modelContext.insert(addressEntity)
        modelContext.insert(planManagerEntity)
        try modelContext.save()
        
        // Verify plan manager exists and has address reference
        let planManagerDescriptor = FetchDescriptor<PlanManagerEntity>()
        let planManagers = try modelContext.fetch(planManagerDescriptor)
        XCTAssertEqual(planManagers.count, 1)
        XCTAssertNotNil(planManagers.first?.address)
        
        // Delete address entity
        modelContext.delete(addressEntity)
        try modelContext.save()
        
        // Verify plan manager still exists but address reference is nullified
        let remainingPlanManagers = try modelContext.fetch(planManagerDescriptor)
        XCTAssertEqual(remainingPlanManagers.count, 1)
        XCTAssertNil(remainingPlanManagers.first?.address)
    }
    
    func testAddressEntityNullifyDeleteWithSessions() throws {
        // Create test AddressEntity
        let addressEntity = AddressEntity()
        addressEntity.id = UUID()
        addressEntity.streetNumber = "123"
        addressEntity.streetName = "Main St"
        addressEntity.city = "Sydney"
        addressEntity.state = "NSW"
        addressEntity.postcode = "2000"
        addressEntity.country = "Australia"
        
        // Create test SessionEntity
        let sessionEntity = SessionEntity(id: UUID())
        sessionEntity.title = "Test Session"
        sessionEntity.address = addressEntity
        
        modelContext.insert(addressEntity)
        modelContext.insert(sessionEntity)
        try modelContext.save()
        
        // Verify session exists and has address reference
        let sessionDescriptor = FetchDescriptor<SessionEntity>()
        let sessions = try modelContext.fetch(sessionDescriptor)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertNotNil(sessions.first?.address)
        
        // Delete address entity
        modelContext.delete(addressEntity)
        try modelContext.save()
        
        // Verify session still exists but address reference is nullified
        let remainingSessions = try modelContext.fetch(sessionDescriptor)
        XCTAssertEqual(remainingSessions.count, 1)
        XCTAssertNil(remainingSessions.first?.address)
    }
    
    // MARK: - Complex Relationship Deletion Tests
    
    func testComplexRelationshipDeletionScenario() throws {
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
        planManagerEntity.address = addressEntity
        
        // Create test PayeeEntity
        let payeeEntity = PayeeEntity(id: UUID(), fullName: "Jane Doe")
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
        
        // Create test ClientServiceEntity
        let clientServiceEntity = ClientServiceEntity()
        clientServiceEntity.id = UUID()
        clientServiceEntity.client = clientEntity
        clientEntity.clientServices.append(clientServiceEntity)
        
        // Create test SessionEntity
        let sessionEntity = SessionEntity(id: UUID())
        sessionEntity.title = "Test Session"
        sessionEntity.client = clientEntity
        sessionEntity.address = addressEntity
        clientEntity.sessions.append(sessionEntity)
        
        // Create test TravelChargeEntity
        let travelChargeEntity = TravelChargeEntity(id: UUID())
        travelChargeEntity.client = clientEntity
        travelChargeEntity.linkedSession = sessionEntity
        clientEntity.travelCharges.append(travelChargeEntity)
        
        // Insert all entities
        modelContext.insert(addressEntity)
        modelContext.insert(planManagerEntity)
        modelContext.insert(payeeEntity)
        modelContext.insert(clientEntity)
        modelContext.insert(clientServiceEntity)
        modelContext.insert(sessionEntity)
        modelContext.insert(travelChargeEntity)
        try modelContext.save()
        
        // Verify all entities exist
        let clientDescriptor = FetchDescriptor<ClientEntity>()
        let payeeDescriptor = FetchDescriptor<PayeeEntity>()
        let planManagerDescriptor = FetchDescriptor<PlanManagerEntity>()
        let addressDescriptor = FetchDescriptor<AddressEntity>()
        let sessionDescriptor = FetchDescriptor<SessionEntity>()
        let travelChargeDescriptor = FetchDescriptor<TravelChargeEntity>()
        let clientServiceDescriptor = FetchDescriptor<ClientServiceEntity>()
        
        let clients = try modelContext.fetch(clientDescriptor)
        let payees = try modelContext.fetch(payeeDescriptor)
        let planManagers = try modelContext.fetch(planManagerDescriptor)
        let addresses = try modelContext.fetch(addressDescriptor)
        let sessions = try modelContext.fetch(sessionDescriptor)
        let travelCharges = try modelContext.fetch(travelChargeDescriptor)
        let clientServices = try modelContext.fetch(clientServiceDescriptor)
        
        XCTAssertEqual(clients.count, 1)
        XCTAssertEqual(payees.count, 1)
        XCTAssertEqual(planManagers.count, 1)
        XCTAssertEqual(addresses.count, 1)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(travelCharges.count, 1)
        XCTAssertEqual(clientServices.count, 1)
        
        // Delete client entity
        modelContext.delete(clientEntity)
        try modelContext.save()
        
        // Verify cascade deletions
        let remainingClients = try modelContext.fetch(clientDescriptor)
        let remainingClientServices = try modelContext.fetch(clientServiceDescriptor)
        let remainingTravelCharges = try modelContext.fetch(travelChargeDescriptor)
        
        XCTAssertEqual(remainingClients.count, 0)
        XCTAssertEqual(remainingClientServices.count, 0)
        XCTAssertEqual(remainingTravelCharges.count, 0)
        
        // Verify nullify deletions
        let remainingPayees = try modelContext.fetch(payeeDescriptor)
        let remainingPlanManagers = try modelContext.fetch(planManagerDescriptor)
        let remainingAddresses = try modelContext.fetch(addressDescriptor)
        let remainingSessions = try modelContext.fetch(sessionDescriptor)
        
        XCTAssertEqual(remainingPayees.count, 1)
        XCTAssertEqual(remainingPlanManagers.count, 1)
        XCTAssertEqual(remainingAddresses.count, 1)
        XCTAssertEqual(remainingSessions.count, 1)
        
        // Verify nullified references
        XCTAssertNil(remainingSessions.first?.client)
        XCTAssertNil(remainingSessions.first?.address)
    }
    
    // MARK: - Performance Tests
    
    func testRelationshipDeletionPerformance() throws {
        // Create large dataset with relationships
        let clients = (0..<1000).map { index in
            let client = ClientEntity(
                id: UUID(),
                ndisNumber: "\(index)",
                fullName: "Client \(index)",
                status: "active"
            )
            
            // Create related entities
            let clientService = ClientServiceEntity()
            clientService.id = UUID()
            clientService.client = client
            client.clientServices.append(clientService)
            
            let session = SessionEntity(id: UUID())
            session.title = "Session \(index)"
            session.client = client
            client.sessions.append(session)
            
            let travelCharge = TravelChargeEntity(id: UUID())
            travelCharge.client = client
            travelCharge.linkedSession = session
            client.travelCharges.append(travelCharge)
            
            return client
        }
        
        // Insert all entities
        clients.forEach { modelContext.insert($0) }
        try modelContext.save()
        
        // Measure deletion performance
        measure {
            // Delete all clients
            clients.forEach { modelContext.delete($0) }
            try! modelContext.save()
        }
    }
}
