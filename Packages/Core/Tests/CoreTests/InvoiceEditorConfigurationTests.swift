import Foundation
import XCTest
@testable import Core

final class InvoiceEditorConfigurationTests: XCTestCase {
    func testDecodesSharedFieldsFromRicherFeatureEnvelope() throws {
        let data = try XCTUnwrap(
            """
            {
              "version": 3,
              "title": "Service Invoice",
              "billParticipantDirectly": false,
              "billToPhone": "07 3000 0000",
              "discountAmount": 12.5,
              "showsTaxSummary": false,
              "paperSize": "a4",
              "template": { "featureOwnedValue": true }
            }
            """.data(using: .utf8)
        )

        let configuration = InvoiceEditorConfiguration(data: data)

        XCTAssertEqual(configuration.version, 3)
        XCTAssertEqual(configuration.title, "Service Invoice")
        XCTAssertFalse(configuration.billParticipantDirectly)
        XCTAssertEqual(configuration.billToPhone, "07 3000 0000")
        XCTAssertEqual(configuration.discountAmount, Decimal(string: "12.5"))
        XCTAssertFalse(configuration.showsTaxSummary)
    }

    func testMissingOrInvalidStateUsesStableDefaults() {
        XCTAssertEqual(InvoiceEditorConfiguration(data: nil), InvoiceEditorConfiguration())
        XCTAssertEqual(
            InvoiceEditorConfiguration(data: Data("not-json".utf8)),
            InvoiceEditorConfiguration()
        )
    }

    func testCoreTotalsAndSnapshotHonorEditorFixedDiscount() throws {
        let invoice = Invoice(invoiceNumber: "INV-EDITOR-CONTRACT")
        invoice.invoiceEditorStateData = try InvoiceEditorConfiguration(
            discountAmount: 10,
            showsTaxSummary: false
        ).encoded()
        invoice.invoiceEditorRevision = 4

        let item = InvoiceItem(itemDescription: "Support")
        item.quantity = 1
        item.rate = 100
        item.taxRate = 10
        item.invoice = invoice
        invoice.items = [item]

        XCTAssertEqual(invoice.financialTotals.subtotal, 100)
        XCTAssertEqual(invoice.financialTotals.discount, 10)
        XCTAssertEqual(invoice.financialTotals.taxTotal, 9)
        XCTAssertEqual(invoice.financialTotals.grandTotal, 99)

        let snapshot = invoice.snapshot()
        XCTAssertEqual(snapshot.invoiceEditorStateData, invoice.invoiceEditorStateData)
        XCTAssertEqual(snapshot.invoiceEditorRevision, 4)
        XCTAssertEqual(snapshot.itemSnapshots.map(\.id), [item.id])
    }
}
