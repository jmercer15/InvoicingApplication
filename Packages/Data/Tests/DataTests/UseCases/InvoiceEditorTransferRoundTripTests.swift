import Core
import Foundation
import SwiftData
import Testing
import PersistenceModels
@testable import Data

@MainActor
@Suite struct InvoiceEditorTransferRoundTripTests {
    @Test func ExpandedExportModelStillDecodesLegacyInvoicePayload() throws {
        let data = Data(#"{"invoiceNumber":"INV-LEGACY","totalAmount":42}"#.utf8)
        let invoice = try JSONDecoder().decode(ExportModels.InvoiceJSON.self, from: data)

        #expect(invoice.invoiceNumber == "INV-LEGACY")
        #expect(invoice.totalAmount == 42)
        #expect(invoice.currencyCode == "AUD")
        #expect(invoice.items.isEmpty)
    }

    @Test func InvoiceExportImportPreservesEditorDomainAndLineItems() async throws {
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
        #expect(firstResult.failed == 0)
        try destinationContext.save()

        var imported = try #require(destinationContext.fetch(FetchDescriptor<Invoice>()).first)
        #expect(imported.invoiceEditorRevision == 0)
        #expect(imported.currencyCode == "AUD")
        #expect(imported.taxRate == 10)
        #expect(imported.discount == 5)
        #expect(imported.creditApplied == 2)
        #expect(imported.businessPhone == "07 3000 0000")
        #expect(imported.clientPhone == "0400 000 000")
        #expect(imported.bankBSB == "123-456")
        #expect(imported.invoiceEditorStateData == source.invoiceEditorStateData)
        #expect(imported.invoiceEditorConfiguration.title == "Support Invoice")
        #expect(!(imported.invoiceEditorConfiguration.billParticipantDirectly))
        #expect(imported.invoiceEditorConfiguration.billToPhone == "07 3111 1111")
        #expect(imported.invoiceEditorConfiguration.discountAmount == 12)
        #expect(!(imported.invoiceEditorConfiguration.showsTaxSummary))
        #expect(imported.itemsArray.count == 1)
        #expect(imported.itemsArray[0].position == 3)
        #expect(imported.itemsArray[0].taxRate == 10)
        #expect(imported.itemsArray[0].unit == "hour")

        let secondResult = try InvoiceImport.importInvoices(
            data: data,
            fileName: "invoice.json",
            context: destinationContext
        )
        #expect(secondResult.failed == 0)
        try destinationContext.save()

        imported = try #require(destinationContext.fetch(FetchDescriptor<Invoice>()).first)
        #expect(imported.invoiceEditorRevision == 1)
        #expect(imported.itemsArray.count == 1)
    }
}
