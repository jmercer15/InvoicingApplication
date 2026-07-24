import XCTest
import SwiftData
@testable import Data
@testable import Core

@MainActor
final class DrainLegacyInvoiceAddressRelationshipsMigrationTests: XCTestCase {
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        modelContainer = container
        modelContext = context
    }

    override func tearDown() async throws {
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    func testExecuteBackfillsMissingSnapshotsAndClearsLegacyRelationships() throws {
        let invoice = Invoice(invoiceNumber: "INV-003")
        invoice.businessAddress = makeAddress(streetNumber: "10", streetName: "Queen St", city: "Brisbane", state: "QLD", postcode: "4000")
        invoice.clientAddress = makeAddress(streetNumber: "11", streetName: "George St", city: "Sydney", state: "NSW", postcode: "2000")
        invoice.billToAddress = makeAddress(streetNumber: "12", streetName: "Collins St", city: "Melbourne", state: "VIC", postcode: "3000")
        invoice.payeeAddress = makeAddress(streetNumber: "13", streetName: "St Georges Tce", city: "Perth", state: "WA", postcode: "6000")

        modelContext.insert(invoice)
        try modelContext.save()

        try DrainLegacyInvoiceAddressRelationships_v1.execute(modelContext: modelContext)

        XCTAssertEqual(invoice.businessAddressSnapshot?.streetName, "Queen St")
        XCTAssertEqual(invoice.clientAddressSnapshot?.city, "Sydney")
        XCTAssertEqual(invoice.billToAddressSnapshot?.state, "VIC")
        XCTAssertEqual(invoice.payeeAddressSnapshot?.postcode, "6000")
        XCTAssertNil(invoice.businessAddress)
        XCTAssertNil(invoice.clientAddress)
        XCTAssertNil(invoice.billToAddress)
        XCTAssertNil(invoice.payeeAddress)
    }

    func testExecutePreservesExistingSnapshotsWhileClearingLegacyRelationships() throws {
        let invoice = Invoice(invoiceNumber: "INV-004")
        invoice.businessAddress = makeAddress(streetNumber: "20", streetName: "Legacy Ln", city: "Brisbane", state: "QLD", postcode: "4000")
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

        try DrainLegacyInvoiceAddressRelationships_v1.execute(modelContext: modelContext)

        XCTAssertEqual(invoice.businessAddressSnapshot?.streetName, "Snapshot Rd")
        XCTAssertEqual(invoice.businessAddressSnapshot?.state, "ACT")
        XCTAssertNil(invoice.businessAddress)
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
