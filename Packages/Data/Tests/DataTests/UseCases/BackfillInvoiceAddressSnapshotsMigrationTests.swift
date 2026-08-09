import Foundation
import Testing
import SwiftData
import PersistenceModels
@testable import Data
@testable import Core

@MainActor
@Suite struct BackfillInvoiceAddressSnapshotsMigrationTests {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init() throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        self.modelContainer = container
        self.modelContext = context
    }

    @Test func ExecuteBackfillsAllInvoiceAddressSnapshotsFromLegacyRelationships() throws {
        let invoice = Invoice(invoiceNumber: "INV-001")
        invoice.businessAddress = makeAddress(
            streetNumber: "1",
            streetName: "Queen St",
            city: "Brisbane",
            state: "QLD",
            postcode: "4000"
        )
        invoice.clientAddress = makeAddress(
            streetNumber: "2",
            streetName: "George St",
            city: "Sydney",
            state: "NSW",
            postcode: "2000"
        )
        invoice.billToAddress = makeAddress(
            streetNumber: "3",
            streetName: "Collins St",
            city: "Melbourne",
            state: "VIC",
            postcode: "3000"
        )
        invoice.payeeAddress = makeAddress(
            streetNumber: "4",
            streetName: "St Georges Tce",
            city: "Perth",
            state: "WA",
            postcode: "6000"
        )

        modelContext.insert(invoice)
        try modelContext.save()

        try BackfillInvoiceAddressSnapshots_v1.execute(modelContext: modelContext)

        #expect(invoice.businessAddressSnapshot?.streetName == "Queen St")
        #expect(invoice.clientAddressSnapshot?.city == "Sydney")
        #expect(invoice.billToAddressSnapshot?.state == "VIC")
        #expect(invoice.payeeAddressSnapshot?.postcode == "6000")
    }

    @Test func ExecuteDoesNotOverwriteExistingSnapshots() throws {
        let invoice = Invoice(invoiceNumber: "INV-002")
        invoice.businessAddress = makeAddress(
            streetNumber: "9",
            streetName: "Adelaide St",
            city: "Brisbane",
            state: "QLD",
            postcode: "4000"
        )
        invoice.businessAddressSnapshot = AddressSnapshot(
            id: UUID(),
            country: "Australia",
            postcode: "2600",
            state: "ACT",
            streetName: "Snapshot Rd",
            streetNumber: "Existing",
            city: "Existing City",
            suburb: "Legacy",
            unitNumber: "Suite 5",
            poBox: "",
            fullAddressText: "Existing Snapshot Rd, Existing City ACT 2600",
            latitude: 0,
            longitude: 0
        )

        modelContext.insert(invoice)
        try modelContext.save()

        try BackfillInvoiceAddressSnapshots_v1.execute(modelContext: modelContext)

        #expect(invoice.businessAddressSnapshot?.streetName == "Snapshot Rd")
        #expect(invoice.businessAddressSnapshot?.state == "ACT")
    }

    private func makeAddress(
        streetNumber: String,
        streetName: String,
        city: String,
        state: String,
        postcode: String
    ) -> Address {
        let address = Address()
        address.streetNumber = streetNumber
        address.streetName = streetName
        address.city = city
        address.state = state
        address.postcode = postcode
        address.country = "Australia"
        return address
    }
}
