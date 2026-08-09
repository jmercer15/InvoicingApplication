import Core
import Foundation
import Testing

@Suite(.tags(.unit))
struct ModelFixturesTests {
    @Test func ndisBillingReportEmptyFixture() {
        let report = NDISBillingReport.empty
        #expect(report.invoice == nil)
        #expect(report.processedSessionsCount == 0)
    }

    @Test func stubNDISBillingIntegrationServiceReturnsConfiguredResponse() async throws {
        let invoice = minimalInvoiceSnapshot(invoiceNumber: "INV-STUB")
        let expected = NDISBillingReport(
            invoice: invoice,
            processedSessionsCount: 2,
            successfulSessionsCount: 1,
            failedSessions: []
        )
        let stub = StubNDISBillingIntegrationService(response: expected)
        let result = try await stub.generateNDISInvoice(for: [UUID()], clientId: UUID())
        #expect(result.processedSessionsCount == 2)
        #expect(result.invoice?.invoiceNumber == "INV-STUB")
    }
}

private func minimalInvoiceSnapshot(
    id: UUID = UUID(),
    invoiceNumber: String = "INV-001"
) -> InvoiceSnapshot {
    InvoiceSnapshot(
        invoiceNumber: invoiceNumber,
        id: id,
        totalAmount: 0,
        taxRate: 0,
        creditApplied: 0,
        discount: 0,
        date: Date(),
        dueDate: nil,
        issueDate: Date(),
        notes: nil,
        paidDate: nil,
        paymentTerms: nil,
        effectiveStatus: .reviewDraft,
        sentDate: nil,
        currencyCode: "AUD",
        isNDIAUploaded: false,
        ndiaUploadDate: nil,
        isBulkClaimed: false,
        businessName: nil,
        businessABN: nil,
        businessEmail: nil,
        businessAddressSnapshot: nil,
        businessPhone: nil,
        clientName: nil,
        clientNDISNumber: nil,
        clientEmail: nil,
        clientPhone: nil,
        clientAddressSnapshot: nil,
        billingAuthority: nil,
        billToName: nil,
        billToEmail: nil,
        billToAddressSnapshot: nil,
        payeeName: nil,
        payeeEmail: nil,
        payeePhone: nil,
        payeeAddressSnapshot: nil,
        bankName: nil,
        bankAccountName: nil,
        bankBSB: nil,
        bankAccountNumber: nil,
        invoiceEditorStateData: nil,
        invoiceEditorRevision: 0,
        itemSnapshots: [],
        clientId: nil,
        payeeId: nil,
        businessId: nil,
        sessionIds: []
    )
}
