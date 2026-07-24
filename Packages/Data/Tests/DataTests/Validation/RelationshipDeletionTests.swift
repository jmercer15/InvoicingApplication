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
        do {
            let (container, context) = try ModelContainerFactory.makeInMemoryContext()
            modelContainer = container
            modelContext = context
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
    
    func testClientCascadeDeleteWithClientServices() throws {
        // Create test Client
        let clientEntity = Client(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        
        // Create test ClientService
        let clientServiceEntity = ClientService(serviceName: "Test Service", unit: "hour", rate: 100)
        clientServiceEntity.client = clientEntity
        clientEntity.clientServices = [clientServiceEntity]
        
        modelContext.insert(clientEntity)
        modelContext.insert(clientServiceEntity)
        try modelContext.save()
        
        // Verify client service exists
        let clientServiceDescriptor = FetchDescriptor<ClientService>()
        let clientServices = try modelContext.fetch(clientServiceDescriptor)
        XCTAssertEqual(clientServices.count, 1)
        
        // Delete client entity
        modelContext.delete(clientEntity)
        try modelContext.save()
        
        // Verify client service is cascade deleted
        let remainingClientServices = try modelContext.fetch(clientServiceDescriptor)
        XCTAssertEqual(remainingClientServices.count, 0)
    }
    
    func testClientCascadeDeleteWithCreditHistory() throws {
        // Create test Client
        let clientEntity = Client(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        
        // Create test CreditHistoryEntry
        let creditHistoryEntity = CreditHistoryEntry()
        creditHistoryEntity.id = UUID()
        creditHistoryEntity.client = clientEntity
        clientEntity.creditHistory = [creditHistoryEntity]
        
        modelContext.insert(clientEntity)
        modelContext.insert(creditHistoryEntity)
        try modelContext.save()
        
        // Verify credit history exists
        let creditHistoryDescriptor = FetchDescriptor<CreditHistoryEntry>()
        let creditHistory = try modelContext.fetch(creditHistoryDescriptor)
        XCTAssertEqual(creditHistory.count, 1)
        
        // Delete client entity
        modelContext.delete(clientEntity)
        try modelContext.save()
        
        // Verify credit history is cascade deleted
        let remainingCreditHistory = try modelContext.fetch(creditHistoryDescriptor)
        XCTAssertEqual(remainingCreditHistory.count, 0)
    }
    
    func testClientCascadeDeleteWithTravelCharges() throws {
        // Create test Client
        let clientEntity = Client(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        
        // Create test TravelCharge
        let travelChargeEntity = TravelCharge(id: UUID())
        travelChargeEntity.client = clientEntity
        clientEntity.travelCharges = [travelChargeEntity]
        
        modelContext.insert(clientEntity)
        modelContext.insert(travelChargeEntity)
        try modelContext.save()
        
        // Verify travel charge exists
        let travelChargeDescriptor = FetchDescriptor<TravelCharge>()
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
    
    func testClientNullifyDeleteWithSessions() throws {
        // Create test Client
        let clientEntity = Client(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        
        // Create test Session
        let sessionEntity = Session(id: UUID())
        sessionEntity.title = "Test Session"
        sessionEntity.client = clientEntity
        clientEntity.sessions = [sessionEntity]
        
        modelContext.insert(clientEntity)
        modelContext.insert(sessionEntity)
        try modelContext.save()
        
        // Verify session exists and has client reference
        let sessionDescriptor = FetchDescriptor<Session>()
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
    
    func testClientNullifyDeleteWithInvoices() throws {
        // Create test Client
        let clientEntity = Client(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        
        // Create test Invoice
        let invoiceEntity = Invoice(invoiceNumber: "INV-CLIENT-001")
        invoiceEntity.client = clientEntity
        clientEntity.invoices = [invoiceEntity]
        
        modelContext.insert(clientEntity)
        modelContext.insert(invoiceEntity)
        try modelContext.save()
        
        // Verify invoice exists and has client reference
        let invoiceDescriptor = FetchDescriptor<Invoice>()
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
    
    func testPayeeNullifyDeleteWithGuardedClients() throws {
        // Create test Payee
        let payeeEntity = Payee(id: UUID(), fullName: "Jane Doe")
        
        // Create test Client
        let clientEntity = Client(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.payee = payeeEntity
        payeeEntity.guardedClients = [clientEntity]
        
        modelContext.insert(payeeEntity)
        modelContext.insert(clientEntity)
        try modelContext.save()
        
        // Verify client exists and has payee reference
        let clientDescriptor = FetchDescriptor<Client>()
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
    
    func testPayeeNullifyDeleteWithInvoices() throws {
        // Create test Payee
        let payeeEntity = Payee(id: UUID(), fullName: "Jane Doe")
        
        // Create test Invoice
        let invoiceEntity = Invoice(invoiceNumber: "INV-PAYEE-001")
        invoiceEntity.payee = payeeEntity
        payeeEntity.invoices = [invoiceEntity]
        
        modelContext.insert(payeeEntity)
        modelContext.insert(invoiceEntity)
        try modelContext.save()
        
        // Verify invoice exists and has payee reference
        let invoiceDescriptor = FetchDescriptor<Invoice>()
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
    
    func testPlanManagerNullifyDeleteWithClients() throws {
        // Create test PlanManager
        let planManagerEntity = PlanManager(abn: "12345678901")
        planManagerEntity.id = UUID()
        planManagerEntity.name = "Test Plan Manager"
        
        // Create test Client
        let clientEntity = Client(
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
        let clientDescriptor = FetchDescriptor<Client>()
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
    
    func testAddressNullifyDeleteWithClients() throws {
        // Create test Address
        let addressEntity = Address()
        addressEntity.id = UUID()
        addressEntity.streetNumber = "123"
        addressEntity.streetName = "Main St"
        addressEntity.city = "Sydney"
        addressEntity.state = "NSW"
        addressEntity.postcode = "2000"
        addressEntity.country = "Australia"
        
        // Create test Client
        let clientEntity = Client(
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
        let clientDescriptor = FetchDescriptor<Client>()
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
    
    func testAddressNullifyDeleteWithPayees() throws {
        // Create test Address
        let addressEntity = Address()
        addressEntity.id = UUID()
        addressEntity.streetNumber = "123"
        addressEntity.streetName = "Main St"
        addressEntity.city = "Sydney"
        addressEntity.state = "NSW"
        addressEntity.postcode = "2000"
        addressEntity.country = "Australia"
        
        // Create test Payee
        let payeeEntity = Payee(id: UUID(), fullName: "Jane Doe")
        payeeEntity.address = addressEntity
        
        modelContext.insert(addressEntity)
        modelContext.insert(payeeEntity)
        try modelContext.save()
        
        // Verify payee exists and has address reference
        let payeeDescriptor = FetchDescriptor<Payee>()
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
    
    func testAddressNullifyDeleteWithPlanManagers() throws {
        // Create test Address
        let addressEntity = Address()
        addressEntity.id = UUID()
        addressEntity.streetNumber = "123"
        addressEntity.streetName = "Main St"
        addressEntity.city = "Sydney"
        addressEntity.state = "NSW"
        addressEntity.postcode = "2000"
        addressEntity.country = "Australia"
        
        // Create test PlanManager
        let planManagerEntity = PlanManager(abn: "12345678901")
        planManagerEntity.id = UUID()
        planManagerEntity.name = "Test Plan Manager"
        planManagerEntity.address = addressEntity
        
        modelContext.insert(addressEntity)
        modelContext.insert(planManagerEntity)
        try modelContext.save()
        
        // Verify plan manager exists and has address reference
        let planManagerDescriptor = FetchDescriptor<PlanManager>()
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
    
    func testAddressNullifyDeleteWithSessions() throws {
        // Create test Address
        let addressEntity = Address()
        addressEntity.id = UUID()
        addressEntity.streetNumber = "123"
        addressEntity.streetName = "Main St"
        addressEntity.city = "Sydney"
        addressEntity.state = "NSW"
        addressEntity.postcode = "2000"
        addressEntity.country = "Australia"
        
        // Create test Session
        let sessionEntity = Session(id: UUID())
        sessionEntity.title = "Test Session"
        sessionEntity.address = addressEntity
        
        modelContext.insert(addressEntity)
        modelContext.insert(sessionEntity)
        try modelContext.save()
        
        // Verify session exists and has address reference
        let sessionDescriptor = FetchDescriptor<Session>()
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
        // Create test Address
        let addressEntity = Address()
        addressEntity.id = UUID()
        addressEntity.streetNumber = "123"
        addressEntity.streetName = "Main St"
        addressEntity.city = "Sydney"
        addressEntity.state = "NSW"
        addressEntity.postcode = "2000"
        addressEntity.country = "Australia"
        
        // Create test PlanManager
        let planManagerEntity = PlanManager(abn: "12345678901")
        planManagerEntity.id = UUID()
        planManagerEntity.name = "Test Plan Manager"
        planManagerEntity.address = addressEntity
        
        // Create test Payee
        let payeeEntity = Payee(id: UUID(), fullName: "Jane Doe")
        payeeEntity.address = addressEntity
        
        // Create test Client
        let clientEntity = Client(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "John Doe",
            status: "active"
        )
        clientEntity.address = addressEntity
        clientEntity.planManager = planManagerEntity
        clientEntity.payee = payeeEntity
        
        // Create test ClientService
        let clientServiceEntity = ClientService(serviceName: "Test Service", unit: "hour", rate: 100)
        clientServiceEntity.client = clientEntity
        clientEntity.clientServices = [clientServiceEntity]
        
        // Create test Session
        let sessionEntity = Session(id: UUID())
        sessionEntity.title = "Test Session"
        sessionEntity.client = clientEntity
        sessionEntity.address = addressEntity
        clientEntity.sessions = [sessionEntity]
        
        // Create test TravelCharge
        let travelChargeEntity = TravelCharge(id: UUID())
        travelChargeEntity.client = clientEntity
        travelChargeEntity.linkedSession = sessionEntity
        clientEntity.travelCharges = [travelChargeEntity]
        
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
        let clientDescriptor = FetchDescriptor<Client>()
        let payeeDescriptor = FetchDescriptor<Payee>()
        let planManagerDescriptor = FetchDescriptor<PlanManager>()
        let addressDescriptor = FetchDescriptor<Address>()
        let sessionDescriptor = FetchDescriptor<Session>()
        let travelChargeDescriptor = FetchDescriptor<TravelCharge>()
        let clientServiceDescriptor = FetchDescriptor<ClientService>()
        
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
        XCTAssertNotNil(remainingSessions.first?.address)
    }
    
    // MARK: - Performance Tests
    
    func testRelationshipDeletionPerformance() throws {
        // Create large dataset with relationships
        let clients = (0..<1000).map { index in
            let client = Client(
                id: UUID(),
                ndisNumber: "\(index)",
                fullName: "Client \(index)",
                status: "active"
            )
            
            // Create related entities
            let clientService = ClientService(serviceName: "Service \(index)", unit: "hour", rate: 100)
            clientService.client = client
            client.clientServices = [clientService]
            
            let session = Session(id: UUID())
            session.title = "Session \(index)"
            session.client = client
            client.sessions = [session]
            
            let travelCharge = TravelCharge(id: UUID())
            travelCharge.client = client
            travelCharge.linkedSession = session
            client.travelCharges = [travelCharge]
            
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
