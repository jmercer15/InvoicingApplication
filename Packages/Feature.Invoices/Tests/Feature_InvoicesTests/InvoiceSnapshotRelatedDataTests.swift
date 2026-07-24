import Core
import Data
@testable import Feature_Invoices
import SwiftData
import XCTest

@MainActor
final class InvoiceSnapshotRelatedDataTests: XCTestCase {
    private var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        modelContext = context
    }

    override func tearDown() async throws {
        modelContext = nil
        try await super.tearDown()
    }

    func testSnapshotRelatedData_planManagerPickerOverridesClientDefault() throws {
        let client = Client(id: UUID(), fullName: "Participant One")
        client.email = "participant@example.com"
        client.billingAuthority = .client

        let defaultPM = PlanManager(id: UUID(), abn: "11111111111")
        defaultPM.name = "Default PM"
        defaultPM.email = "default-pm@example.com"

        let selectedPM = PlanManager(id: UUID(), abn: "22222222222")
        selectedPM.name = "Selected PM"
        selectedPM.email = "selected-pm@example.com"

        client.planManager = defaultPM
        modelContext.insert(client)
        modelContext.insert(defaultPM)
        modelContext.insert(selectedPM)

        let invoice = Invoice(id: UUID(), invoiceNumber: "INV-PM-001")
        invoice.client = client
        invoice.billingAuthority = .planManager
        modelContext.insert(invoice)
        try modelContext.save()

        invoice.snapshotRelatedData(billingPlanManager: selectedPM)

        XCTAssertEqual(invoice.billToName, "Selected PM")
        XCTAssertEqual(invoice.billToEmail, "selected-pm@example.com")
        XCTAssertNotEqual(invoice.billToName, defaultPM.name)
    }

    func testSnapshotRelatedData_payeePickerOverridesClientWhenParentGuardian() throws {
        let client = Client(id: UUID(), fullName: "Minor Client")
        client.email = "minor@example.com"
        client.billingAuthority = .parentGuardian

        let clientPayee = Payee(id: UUID(), fullName: "Default Guardian")
        clientPayee.email = "default-guardian@example.com"

        let selectedPayee = Payee(id: UUID(), fullName: "Selected Guardian")
        selectedPayee.email = "selected-guardian@example.com"

        client.payee = clientPayee
        modelContext.insert(client)
        modelContext.insert(clientPayee)
        modelContext.insert(selectedPayee)

        let invoice = Invoice(id: UUID(), invoiceNumber: "INV-PAYEE-001")
        invoice.client = client
        invoice.billingAuthority = .parentGuardian
        modelContext.insert(invoice)
        try modelContext.save()

        invoice.snapshotRelatedData(billingPayee: selectedPayee)

        XCTAssertEqual(invoice.billToName, "Selected Guardian")
        XCTAssertEqual(invoice.billToEmail, "selected-guardian@example.com")
        XCTAssertEqual(invoice.payeeName, "Selected Guardian")
        XCTAssertEqual(invoice.payeeEmail, "selected-guardian@example.com")
    }

    func testSnapshotRelatedData_clientAuthorityUsesClientBillTo() throws {
        let client = Client(id: UUID(), fullName: "Direct Client")
        client.email = "direct@example.com"
        client.billingAuthority = .client

        let address = Address()
        address.streetNumber = "10"
        address.streetName = "Main St"
        address.city = "Sydney"
        address.state = "NSW"
        address.postcode = "2000"
        client.address = address

        modelContext.insert(address)
        modelContext.insert(client)

        let invoice = Invoice(id: UUID(), invoiceNumber: "INV-CLIENT-001")
        invoice.client = client
        invoice.billingAuthority = .client
        modelContext.insert(invoice)
        try modelContext.save()

        invoice.snapshotRelatedData()

        XCTAssertEqual(invoice.billToName, "Direct Client")
        XCTAssertEqual(invoice.billToEmail, "direct@example.com")
        XCTAssertEqual(invoice.clientName, "Direct Client")
        XCTAssertNotNil(invoice.billToAddressSnapshot)
        XCTAssertTrue(invoice.billToAddressSnapshot?.fullFormattedAddress.contains("Main St") == true)
    }
}
