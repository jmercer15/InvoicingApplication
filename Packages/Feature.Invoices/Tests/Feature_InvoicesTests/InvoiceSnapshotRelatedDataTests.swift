import Core
import Data
import PersistenceModels
@testable import Feature_Invoices
import SwiftData
import Foundation
import Testing
@MainActor
@Suite struct InvoiceSnapshotRelatedDataTests {
    private let modelContext: ModelContext

    init() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        self.modelContext = context
    }

    @Test func SnapshotRelatedData_planManagerPickerOverridesClientDefault() throws {
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

        #expect(invoice.billToName == "Selected PM")
        #expect(invoice.billToEmail == "selected-pm@example.com")
        #expect(invoice.billToName != defaultPM.name)
    }

    @Test func SnapshotRelatedData_payeePickerOverridesClientWhenParentGuardian() throws {
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

        #expect(invoice.billToName == "Selected Guardian")
        #expect(invoice.billToEmail == "selected-guardian@example.com")
        #expect(invoice.payeeName == "Selected Guardian")
        #expect(invoice.payeeEmail == "selected-guardian@example.com")
    }

    @Test func SnapshotRelatedData_clientAuthorityUsesClientBillTo() throws {
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

        #expect(invoice.billToName == "Direct Client")
        #expect(invoice.billToEmail == "direct@example.com")
        #expect(invoice.clientName == "Direct Client")
        #expect(invoice.billToAddressSnapshot != nil)
        #expect(invoice.billToAddressSnapshot?.fullFormattedAddress.contains("Main St") == true)
    }
}
