import Core
import SwiftData
import XCTest
@testable import Data

@MainActor
final class InvoiceEditorTransferRoundTripTests: XCTestCase {
    func testExpandedExportModelStillDecodesLegacyInvoicePayload() throws {
        let data = Data(#"{"invoiceNumber":"INV-LEGACY","totalAmount":42}"#.utf8)
        let invoice = try JSONDecoder().decode(ExportModels.InvoiceJSON.self, from: data)

        XCTAssertEqual(invoice.invoiceNumber, "INV-LEGACY")
        XCTAssertEqual(invoice.totalAmount, 42)
        XCTAssertEqual(invoice.currencyCode, "AUD")
        XCTAssertTrue(invoice.items.isEmpty)
    }

    func testInvoiceExportImportPreservesEditorDomainAndLineItems() async throws {
        let sourceContainer = try ModelContainerFactory.makeInMemoryContainer()
        let sourceContext = ModelContext(sourceContainer)
        let source = Invoice(invoiceNumber: "INV-TRANSFER-001")
        source.clientName = "Transfer Client"
        source.businessName = "Transfer Provider"
        source.businessPhone = "07 3000 0000"
        source.clientPhone = "0400 000 000"
        source.currencyCode = "AUD"
        source.taxRate = 10
        source.discount = 5
        source.creditApplied = 2
        source.bankBSB = "123-456"
        source.invoiceEditorStateData = try InvoiceEditorConfiguration(
            title: "Support Invoice",
            billParticipantDirectly: false,
            billToPhone: "07 3111 1111",
            discountAmount: 12,
            showsTaxSummary: false
        ).encoded()

        let line = InvoiceItem(itemDescription: "Support service")
        line.position = 3
        line.quantity = 2
        line.rate = 100
        line.taxRate = 10
        line.unit = "hour"
        line.invoice = source
        source.items = [line]
        source.recalculateStoredTotal()
        sourceContext.insert(source)
        sourceContext.insert(line)
        try sourceContext.save()

        let data = try await DataExporterActor(modelContainer: sourceContainer).exportInvoices()

        let destinationContainer = try ModelContainerFactory.makeInMemoryContainer()
        let destinationContext = ModelContext(destinationContainer)
        let client = Client(ndisNumber: "4300000000", fullName: "Transfer Client", status: .active)
        destinationContext.insert(client)
        try destinationContext.save()

        let firstResult = try InvoiceImport.importInvoices(
            data: data,
            fileName: "invoice.json",
            context: destinationContext
        )
        XCTAssertEqual(firstResult.failed, 0)
        try destinationContext.save()

        var imported = try XCTUnwrap(destinationContext.fetch(FetchDescriptor<Invoice>()).first)
        XCTAssertEqual(imported.invoiceEditorRevision, 0)
        XCTAssertEqual(imported.currencyCode, "AUD")
        XCTAssertEqual(imported.taxRate, 10)
        XCTAssertEqual(imported.discount, 5)
        XCTAssertEqual(imported.creditApplied, 2)
        XCTAssertEqual(imported.businessPhone, "07 3000 0000")
        XCTAssertEqual(imported.clientPhone, "0400 000 000")
        XCTAssertEqual(imported.bankBSB, "123-456")
        XCTAssertEqual(imported.invoiceEditorStateData, source.invoiceEditorStateData)
        XCTAssertEqual(imported.invoiceEditorConfiguration.title, "Support Invoice")
        XCTAssertFalse(imported.invoiceEditorConfiguration.billParticipantDirectly)
        XCTAssertEqual(imported.invoiceEditorConfiguration.billToPhone, "07 3111 1111")
        XCTAssertEqual(imported.invoiceEditorConfiguration.discountAmount, 12)
        XCTAssertFalse(imported.invoiceEditorConfiguration.showsTaxSummary)
        XCTAssertEqual(imported.itemsArray.count, 1)
        XCTAssertEqual(imported.itemsArray[0].position, 3)
        XCTAssertEqual(imported.itemsArray[0].taxRate, 10)
        XCTAssertEqual(imported.itemsArray[0].unit, "hour")

        let secondResult = try InvoiceImport.importInvoices(
            data: data,
            fileName: "invoice.json",
            context: destinationContext
        )
        XCTAssertEqual(secondResult.failed, 0)
        try destinationContext.save()

        imported = try XCTUnwrap(destinationContext.fetch(FetchDescriptor<Invoice>()).first)
        XCTAssertEqual(imported.invoiceEditorRevision, 1)
        XCTAssertEqual(imported.itemsArray.count, 1)
    }
}
