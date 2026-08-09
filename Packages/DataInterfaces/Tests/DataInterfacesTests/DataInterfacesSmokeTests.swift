import Core
import PersistenceModels
import Foundation
import SwiftData
import Testing
@testable import DataInterfaces

@MainActor
struct DataInterfacesSmokeTests {
    @Test
    func invoiceDigestingRequiresInvoiceNumbers() async throws {
        let digest = StubInvoiceDigesting(numbers: ["INV-001", "INV-002"])
        let numbers = try await digest.allInvoiceNumbers()
        #expect(numbers == ["INV-001", "INV-002"])
    }

    @Test
    func clientRelationshipDeletingProtocolSupportsCascadeFlag() async throws {
        let deleter = StubClientRelationshipDeleter()
        let client = Client(id: UUID(), fullName: "Cascade Client")
        try await deleter.deleteClient(id: client.id, deleteSessions: true)
        #expect(deleter.lastDeleteSessionsFlag == true)
        #expect(deleter.deletedClientIDs == [client.id])
    }

    @Test
    func referenceDataFetchingReturnsPersistentIdentifiers() async throws {
        let fetcher = StubReferenceDataFetching(itemIDs: [])
        let ids = try await fetcher.fetchAllNDISItemIDs()
        #expect(ids.isEmpty)
    }
}
