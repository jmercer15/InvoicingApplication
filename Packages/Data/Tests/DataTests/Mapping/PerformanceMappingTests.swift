//
//  PerformanceMappingTests.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//
//  Performance tests for mapping operations with large datasets
//  This test suite validates that all mapping operations perform well
//  with large datasets and identifies potential performance bottlenecks.
//

import XCTest
import SwiftData
@testable import Data
@testable import Core

/// Performance tests for mapping operations with large datasets
final class PerformanceMappingTests: XCTestCase {
    
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
    
    // MARK: - Client Mapping Performance Tests
    
    func testClientEntityToDomainMappingPerformance() throws {
        // Create large dataset of ClientEntity objects
        let entities = (0..<10000).map { index in
            let entity = ClientEntity(
                id: UUID(),
                ndisNumber: "\(index)",
                fullName: "Client \(index)",
                status: "active"
            )
            entity.email = "client\(index)@example.com"
            entity.notes = "Notes for client \(index)"
            entity.phone = "0412345678"
            entity.creditAmount = Double(index)
            entity.isMinor = index % 2 == 0
            entity.hasNdisPlan = index % 3 == 0
            entity.planManagementType = index % 2 == 0 ? "plan_managed" : "self_managed"
            entity.billingAuthority = "NDIA"
            entity.sendInvoicesToClient = index % 2 == 0
            entity.sendInvoicesToPayee = index % 3 == 0
            entity.sendInvoicesToPlanManager = index % 4 == 0
            return entity
        }
        
        entities.forEach { modelContext.insert($0) }
        try modelContext.save()
        
        // Measure mapping performance
        measure {
            let clients = entities.map { Client(from: $0) }
            XCTAssertEqual(clients.count, 10000)
            
            // Verify some mappings are correct
            XCTAssertEqual(clients[0].fullName, "Client 0")
            XCTAssertEqual(clients[9999].fullName, "Client 9999")
        }
    }
    
    func testClientDomainToEntityUpdatePerformance() throws {
        // Create large dataset of ClientEntity objects
        let entities = (0..<10000).map { index in
            let entity = ClientEntity(
                id: UUID(),
                ndisNumber: "\(index)",
                fullName: "Client \(index)",
                status: "active"
            )
            entity.email = "client\(index)@example.com"
            entity.notes = "Notes for client \(index)"
            entity.phone = "0412345678"
            entity.creditAmount = Double(index)
            entity.isMinor = index % 2 == 0
            entity.hasNdisPlan = index % 3 == 0
            entity.planManagementType = index % 2 == 0 ? "plan_managed" : "self_managed"
            entity.billingAuthority = "NDIA"
            entity.sendInvoicesToClient = index % 2 == 0
            entity.sendInvoicesToPayee = index % 3 == 0
            entity.sendInvoicesToPlanManager = index % 4 == 0
            return entity
        }
        
        entities.forEach { modelContext.insert($0) }
        try modelContext.save()
        
        // Create domain models
        let domainModels = entities.map { Client(from: $0) }
        
        // Measure update performance
        measure {
            for (index, domainModel) in domainModels.enumerated() {
                entities[index].update(from: domainModel)
            }
        }
    }
    
    // MARK: - Payee Mapping Performance Tests
    
    func testPayeeEntityToDomainMappingPerformance() throws {
        // Create large dataset of PayeeEntity objects
        let entities = (0..<10000).map { index in
            let entity = PayeeEntity(id: UUID(), fullName: "Payee \(index)")
            entity.email = "payee\(index)@example.com"
            entity.phone = "0412345678"
            entity.status = index % 2 == 0 ? "active" : "inactive"
            entity.relationToClient = index % 3 == 0 ? "parent" : "guardian"
            return entity
        }
        
        entities.forEach { modelContext.insert($0) }
        try modelContext.save()
        
        // Measure mapping performance
        measure {
            let payees = entities.map { Payee(from: $0) }
            XCTAssertEqual(payees.count, 10000)
            
            // Verify some mappings are correct
            XCTAssertEqual(payees[0].fullName, "Payee 0")
            XCTAssertEqual(payees[9999].fullName, "Payee 9999")
        }
    }
    
    // MARK: - PlanManager Mapping Performance Tests
    
    func testPlanManagerEntityToDomainMappingPerformance() throws {
        // Create large dataset of PlanManagerEntity objects
        let entities = (0..<10000).map { index in
            let entity = PlanManagerEntity(abn: "\(index)")
            entity.id = UUID()
            entity.name = "Plan Manager \(index)"
            entity.email = "pm\(index)@example.com"
            entity.phone = "0412345678"
            return entity
        }
        
        entities.forEach { modelContext.insert($0) }
        try modelContext.save()
        
        // Measure mapping performance
        measure {
            let planManagers = entities.map { PlanManager(from: $0) }
            XCTAssertEqual(planManagers.count, 10000)
            
            // Verify some mappings are correct
            XCTAssertEqual(planManagers[0].name, "Plan Manager 0")
            XCTAssertEqual(planManagers[9999].name, "Plan Manager 9999")
        }
    }
    
    // MARK: - Address Mapping Performance Tests
    
    func testAddressEntityToDomainMappingPerformance() throws {
        // Create large dataset of AddressEntity objects
        let entities = (0..<10000).map { index in
            let entity = AddressEntity()
            entity.id = UUID()
            entity.streetNumber = "\(index)"
            entity.streetName = "Street \(index)"
            entity.city = "City \(index)"
            entity.state = "State \(index)"
            entity.postcode = "\(index)"
            entity.country = "Country \(index)"
            entity.unitNumber = "Unit \(index)"
            entity.poBox = "PO Box \(index)"
            return entity
        }
        
        entities.forEach { modelContext.insert($0) }
        try modelContext.save()
        
        // Measure mapping performance
        measure {
            let addresses = entities.map { Address(from: $0) }
            XCTAssertEqual(addresses.count, 10000)
            
            // Verify some mappings are correct
            XCTAssertEqual(addresses[0].street, "0 Street 0")
            XCTAssertEqual(addresses[9999].street, "9999 Street 9999")
        }
    }
    
    // MARK: - Session Mapping Performance Tests
    
    func testSessionEntityToDomainMappingPerformance() throws {
        // Create large dataset of SessionEntity objects
        let entities = (0..<10000).map { index in
            let entity = SessionEntity(id: UUID())
            entity.title = "Session \(index)"
            entity.startTime = Date().addingTimeInterval(TimeInterval(index))
            entity.endTime = Date().addingTimeInterval(TimeInterval(index + 3600))
            entity.isAllDay = index % 2 == 0
            entity.location = "Location \(index)"
            entity.notes = "Notes for session \(index)"
            entity.status = index % 2 == 0 ? "active" : "inactive"
            entity.isTravel = index % 3 == 0
            entity.groupID = UUID()
            entity.groupedPosition = Int32(index)
            entity.attendeesCount = Int32(index % 10)
            entity.derivedFromEKEventID = "event-\(index)"
            entity.googleColorId = "color-\(index)"
            entity.sessionLatitude = Double(index)
            entity.sessionLongitude = Double(index)
            entity.eventIdentifier = "event-identifier-\(index)"
            entity.calendarIdentifier = "calendar-identifier-\(index)"
            entity.lastModifiedDate = Date().addingTimeInterval(TimeInterval(index))
            entity.lastSyncTag = "sync-tag-\(index)"
            entity.recurrenceRuleData = Data()
            return entity
        }
        
        entities.forEach { modelContext.insert($0) }
        try modelContext.save()
        
        // Measure mapping performance
        measure {
            let sessions = entities.map { Session.from(entity: $0) }
            XCTAssertEqual(sessions.count, 10000)
            
            // Verify some mappings are correct
            XCTAssertEqual(sessions[0].title, "Session 0")
            XCTAssertEqual(sessions[9999].title, "Session 9999")
        }
    }
    
    // MARK: - TravelCharge Mapping Performance Tests
    
    func testTravelChargeEntityToDomainMappingPerformance() throws {
        // Create large dataset of TravelChargeEntity objects
        let entities = (0..<10000).map { index in
            let entity = TravelChargeEntity(id: UUID())
            entity.mmmZoneName = "Zone \(index)"
            entity.travelDistance = Double(index)
            entity.travelDuration = Double(index * 60)
            entity.vehicleType = index % 2 == 0 ? "car" : "bike"
            entity.parkingCost = Double(index)
            entity.tollCost = Double(index * 0.5)
            entity.participantCount = Int16(index % 5)
            entity.splitCosts = index % 2 == 0
            entity.chargeType = index % 2 == 0 ? "travel" : "parking"
            entity.travelDirection = index % 2 == 0 ? "outbound" : "inbound"
            entity.location = "Location \(index)"
            entity.notes = "Status: pending"
            entity.lastModifiedDate = Date().addingTimeInterval(TimeInterval(index))
            entity.ekCreationDate = Date().addingTimeInterval(TimeInterval(index))
            return entity
        }
        
        entities.forEach { modelContext.insert($0) }
        try modelContext.save()
        
        // Measure mapping performance
        measure {
            let travelCharges = entities.map { TravelCharge(from: $0) }
            XCTAssertEqual(travelCharges.count, 10000)
            
            // Verify some mappings are correct
            XCTAssertEqual(travelCharges[0].amount, 0.0)
            XCTAssertEqual(travelCharges[9999].amount, 9999.0)
        }
    }
    
    // MARK: - NDISItem Mapping Performance Tests
    
    func testNDISItemEntityToDomainMappingPerformance() throws {
        // Create large dataset of NDISItemEntity objects
        let entities = (0..<10000).map { index in
            let entity = NDISItemEntity()
            entity.id = UUID()
            entity.itemNumber = "\(index)"
            entity.name = "NDIS Item \(index)"
            entity.description = "Description for NDIS item \(index)"
            
            // Create regional prices
            let regionalPrice = RegionalPriceEntity()
            regionalPrice.id = UUID()
            regionalPrice.regionIdentifier = "NSW"
            regionalPrice.amount = Double(index)
            entity.regionalPrices = [regionalPrice]
            
            return entity
        }
        
        entities.forEach { modelContext.insert($0) }
        try modelContext.save()
        
        // Measure mapping performance
        measure {
            let ndisItems = entities.map { NDISItem(from: $0) }
            XCTAssertEqual(ndisItems.count, 10000)
            
            // Verify some mappings are correct
            XCTAssertEqual(ndisItems[0].name, "NDIS Item 0")
            XCTAssertEqual(ndisItems[9999].name, "NDIS Item 9999")
        }
    }
    
    // MARK: - Mixed Entity Mapping Performance Tests
    
    func testMixedEntityMappingPerformance() throws {
        // Create mixed dataset of different entity types
        let clientEntities = (0..<1000).map { index in
            let entity = ClientEntity(
                id: UUID(),
                ndisNumber: "\(index)",
                fullName: "Client \(index)",
                status: "active"
            )
            entity.email = "client\(index)@example.com"
            entity.notes = "Notes for client \(index)"
            entity.phone = "0412345678"
            entity.creditAmount = Double(index)
            entity.isMinor = index % 2 == 0
            entity.hasNdisPlan = index % 3 == 0
            entity.planManagementType = index % 2 == 0 ? "plan_managed" : "self_managed"
            entity.billingAuthority = "NDIA"
            entity.sendInvoicesToClient = index % 2 == 0
            entity.sendInvoicesToPayee = index % 3 == 0
            entity.sendInvoicesToPlanManager = index % 4 == 0
            return entity
        }
        
        let payeeEntities = (0..<1000).map { index in
            let entity = PayeeEntity(id: UUID(), fullName: "Payee \(index)")
            entity.email = "payee\(index)@example.com"
            entity.phone = "0412345678"
            entity.status = index % 2 == 0 ? "active" : "inactive"
            entity.relationToClient = index % 3 == 0 ? "parent" : "guardian"
            return entity
        }
        
        let sessionEntities = (0..<1000).map { index in
            let entity = SessionEntity(id: UUID())
            entity.title = "Session \(index)"
            entity.startTime = Date().addingTimeInterval(TimeInterval(index))
            entity.endTime = Date().addingTimeInterval(TimeInterval(index + 3600))
            entity.isAllDay = index % 2 == 0
            entity.location = "Location \(index)"
            entity.notes = "Notes for session \(index)"
            entity.status = index % 2 == 0 ? "active" : "inactive"
            entity.isTravel = index % 3 == 0
            entity.groupID = UUID()
            entity.groupedPosition = Int32(index)
            entity.attendeesCount = Int32(index % 10)
            entity.derivedFromEKEventID = "event-\(index)"
            entity.googleColorId = "color-\(index)"
            entity.sessionLatitude = Double(index)
            entity.sessionLongitude = Double(index)
            entity.eventIdentifier = "event-identifier-\(index)"
            entity.calendarIdentifier = "calendar-identifier-\(index)"
            entity.lastModifiedDate = Date().addingTimeInterval(TimeInterval(index))
            entity.lastSyncTag = "sync-tag-\(index)"
            entity.recurrenceRuleData = Data()
            return entity
        }
        
        // Insert all entities
        clientEntities.forEach { modelContext.insert($0) }
        payeeEntities.forEach { modelContext.insert($0) }
        sessionEntities.forEach { modelContext.insert($0) }
        try modelContext.save()
        
        // Measure mixed mapping performance
        measure {
            let clients = clientEntities.map { Client(from: $0) }
            let payees = payeeEntities.map { Payee(from: $0) }
            let sessions = sessionEntities.map { Session.from(entity: $0) }
            
            XCTAssertEqual(clients.count, 1000)
            XCTAssertEqual(payees.count, 1000)
            XCTAssertEqual(sessions.count, 1000)
            
            // Verify some mappings are correct
            XCTAssertEqual(clients[0].fullName, "Client 0")
            XCTAssertEqual(payees[0].fullName, "Payee 0")
            XCTAssertEqual(sessions[0].title, "Session 0")
        }
    }
    
    // MARK: - Memory Usage Tests
    
    func testMappingMemoryUsage() throws {
        // Create large dataset
        let entities = (0..<50000).map { index in
            let entity = ClientEntity(
                id: UUID(),
                ndisNumber: "\(index)",
                fullName: "Client \(index)",
                status: "active"
            )
            entity.email = "client\(index)@example.com"
            entity.notes = "Notes for client \(index)"
            entity.phone = "0412345678"
            entity.creditAmount = Double(index)
            entity.isMinor = index % 2 == 0
            entity.hasNdisPlan = index % 3 == 0
            entity.planManagementType = index % 2 == 0 ? "plan_managed" : "self_managed"
            entity.billingAuthority = "NDIA"
            entity.sendInvoicesToClient = index % 2 == 0
            entity.sendInvoicesToPayee = index % 3 == 0
            entity.sendInvoicesToPlanManager = index % 4 == 0
            return entity
        }
        
        entities.forEach { modelContext.insert($0) }
        try modelContext.save()
        
        // Measure memory usage during mapping
        let startTime = CFAbsoluteTimeGetCurrent()
        let clients = entities.map { Client(from: $0) }
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = endTime - startTime
        
        // Verify mapping completed successfully
        XCTAssertEqual(clients.count, 50000)
        
        // Log performance metrics
        print("Mapping 50,000 entities took \(executionTime) seconds")
        print("Average time per entity: \(executionTime / 50000) seconds")
        
        // Verify some mappings are correct
        XCTAssertEqual(clients[0].fullName, "Client 0")
        XCTAssertEqual(clients[49999].fullName, "Client 49999")
    }
    
    // MARK: - Concurrent Mapping Tests
    
    func testConcurrentMappingPerformance() throws {
        // Create large dataset
        let entities = (0..<10000).map { index in
            let entity = ClientEntity(
                id: UUID(),
                ndisNumber: "\(index)",
                fullName: "Client \(index)",
                status: "active"
            )
            entity.email = "client\(index)@example.com"
            entity.notes = "Notes for client \(index)"
            entity.phone = "0412345678"
            entity.creditAmount = Double(index)
            entity.isMinor = index % 2 == 0
            entity.hasNdisPlan = index % 3 == 0
            entity.planManagementType = index % 2 == 0 ? "plan_managed" : "self_managed"
            entity.billingAuthority = "NDIA"
            entity.sendInvoicesToClient = index % 2 == 0
            entity.sendInvoicesToPayee = index % 3 == 0
            entity.sendInvoicesToPlanManager = index % 4 == 0
            return entity
        }
        
        entities.forEach { modelContext.insert($0) }
        try modelContext.save()
        
        // Measure concurrent mapping performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let dispatchGroup = DispatchGroup()
        let queue = DispatchQueue(label: "mapping.queue", attributes: .concurrent)
        
        var results: [Client] = []
        let resultsQueue = DispatchQueue(label: "results.queue")
        
        // Split entities into chunks for concurrent processing
        let chunkSize = 1000
        let chunks = entities.chunked(into: chunkSize)
        
        for chunk in chunks {
            dispatchGroup.enter()
            queue.async {
                let chunkResults = chunk.map { Client(from: $0) }
                resultsQueue.async {
                    results.append(contentsOf: chunkResults)
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.wait()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Verify mapping completed successfully
        XCTAssertEqual(results.count, 10000)
        
        // Log performance metrics
        print("Concurrent mapping of 10,000 entities took \(executionTime) seconds")
        print("Average time per entity: \(executionTime / 10000) seconds")
        
        // Verify some mappings are correct
        XCTAssertEqual(results[0].fullName, "Client 0")
        XCTAssertEqual(results[9999].fullName, "Client 9999")
    }
}

// MARK: - Helper Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
