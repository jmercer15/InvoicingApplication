import Foundation
import PersistenceModels
import SwiftData
import Testing
@testable import Data

@MainActor
@Suite struct ImportIdentitySafetyTests {
    @Test func clientImportDoesNotUpdateSameNameRecordWithoutStableIdentifier() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let existing = Client(fullName: "Jordan Example")
        existing.email = "existing@example.com"
        context.insert(existing)
        try context.save()

        let payload = "[{\"fullName\":\"Jordan Example\",\"email\":\"imported@example.com\"}]"
        let result = try ClientImport.importClients(data: Data(payload.utf8), fileName: "clients.json", context: context)

        let clients = try context.fetch(FetchDescriptor<Client>())
        #expect(result.successful == 1)
        #expect(clients.count == 2)
        #expect(existing.email == "existing@example.com")
    }

    @Test func clientImportUpdatesByNDISNumberInsteadOfName() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let existing = Client(ndisNumber: "431234567", fullName: "Old Name")
        context.insert(existing)
        try context.save()

        let payload = "[{\"fullName\":\"New Name\",\"ndis_number\":\"431234567\",\"email\":\"updated@example.com\"}]"
        let result = try ClientImport.importClients(data: Data(payload.utf8), fileName: "clients.json", context: context)

        let clients = try context.fetch(FetchDescriptor<Client>())
        #expect(result.successful == 1)
        #expect(clients.count == 1)
        #expect(existing.fullName == "New Name")
        #expect(existing.email == "updated@example.com")
    }

    @Test func serviceImportRejectsNameOnlyClientReference() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let client = Client(fullName: "Jordan Example")
        context.insert(client)
        try context.save()

        let payload = "[{\"Parent Name\":\"Parent\",\"Student Name\":\"Jordan Example\",\"Task Name\":\"Support\",\"Code\":\"N/A\",\"Rate\":\"10\",\"Unit\":\"hour\"}]"
        let result = try ServiceImport.importServices(data: Data(payload.utf8), fileName: "services.json", context: context)

        #expect(result.successful == 0)
        #expect(result.failed == 1)
        #expect(result.messages.contains { $0.contains("name matching is not supported") })
    }
}
