import Foundation
import Testing
import SwiftData
@testable import Data
import Core
import PersistenceModels

@MainActor
@Suite struct AllDataComplianceRoundTripTests {
    @Test func AllDataExportAndImportRoundTripsComplianceEntitiesAndLinks() throws {
        let sourceContext = try makeInMemoryContext()
        try insertComplianceFixture(into: sourceContext)

        let exportedData = try SwiftDataExportService.exportAllEntitiesToJSON(context: sourceContext)
        let exportedJSON = try #require(JSONSerialization.jsonObject(with: exportedData) as? [String: Any])

        #expect((exportedJSON["ServiceAgreement"] as? [[String: Any]])?.count == 1)
        #expect((exportedJSON["SupportLog"] as? [[String: Any]])?.count == 1)
        #expect((exportedJSON["BulkClaimBatch"] as? [[String: Any]])?.count == 1)
        #expect((exportedJSON["BulkClaimLine"] as? [[String: Any]])?.count == 1)

        let destinationContext = try makeInMemoryContext()
        let importResults = try AllDataImportService.importAllData(from: exportedData, context: destinationContext)
        let totalFailed = importResults.reduce(0) { $0 + $1.failed }
        #expect(totalFailed == 0)

        let importedAgreements = try destinationContext.fetch(FetchDescriptor<ServiceAgreement>())
        let importedLogs = try destinationContext.fetch(FetchDescriptor<SupportLog>())
        let importedBatches = try destinationContext.fetch(FetchDescriptor<BulkClaimBatch>())
        let importedLines = try destinationContext.fetch(FetchDescriptor<BulkClaimLine>())
        let importedInvoices = try destinationContext.fetch(FetchDescriptor<Invoice>())
        let importedInvoiceItems = try destinationContext.fetch(FetchDescriptor<InvoiceItem>())

        #expect(importedAgreements.count == 1)
        #expect(importedLogs.count == 1)
        #expect(importedBatches.count == 1)
        #expect(importedLines.count == 1)

        #expect(importedAgreements.first?.client != nil)
        #expect(importedLogs.first?.client != nil)
        #expect(importedLogs.first?.session != nil)
        #expect(importedLines.first?.batch != nil)
        #expect(importedLines.first?.invoice != nil)
        #expect(importedLines.first?.invoiceItem != nil)
        #expect(importedLines.first?.submissionStatus == BulkClaimSubmissionStatus.reconciled.rawValue)
        #expect(importedLines.first?.submissionRef == "SUB-ROUNDTRIP-001")
        #expect(importedLines.first?.reconciliationNotes == "Portal reconciliation matched.")
        #expect(importedLines.first?.reconciledAt != nil)
        let importedInvoice = try #require(importedInvoices.first)
        #expect(importedInvoice.currencyCode == "AUD")
        #expect(importedInvoice.taxRate == 10)
        #expect(importedInvoice.discount == 5)
        #expect(importedInvoice.creditApplied == 3)
        #expect(importedInvoice.businessPhone == "07 3000 0000")
        #expect(importedInvoice.clientPhone == "0400 000 000")
        #expect(importedInvoice.bankBSB == "123-456")
        #expect(importedInvoice.invoiceEditorStateData == Data("layout-v2".utf8))
        let importedItem = try #require(importedInvoiceItems.first)
        #expect(importedItem.position == 2)
        #expect(importedItem.unit == "hour")
        #expect(importedItem.taxRate == 10)
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        return context
    }

    private func insertComplianceFixture(into context: ModelContext) throws {
        let baseDate = Date(timeIntervalSince1970: 1_738_800_000)

        let business = Business(id: UUID(), abn: "53004085616")
        business.name = "Acme Support"
        business.defaultGstCode = GSTCode.p2.rawValue
        business.isRegisteredProvider = true
        business.ndiaOrganisationID = "100200300"

        let client = Client(
            id: UUID(),
            ndisNumber: "4300123456",
            fullName: "Jordan Participant",
            status: .active
        )

        let invoice = Invoice(id: UUID(), invoiceNumber: "INV-ROUNDTRIP-001")
        invoice.client = client
        invoice.business = business
        invoice.status = .readyToSend
        invoice.currencyCode = "AUD"
        invoice.taxRate = 10
        invoice.discount = 5
        invoice.creditApplied = 3
        invoice.businessPhone = "07 3000 0000"
        invoice.clientPhone = "0400 000 000"
        invoice.bankBSB = "123-456"
        invoice.invoiceEditorStateData = Data("layout-v2".utf8)

        let session = Session(id: UUID())
        session.title = "Community access support"
        session.startTime = baseDate
        session.endTime = baseDate.addingTimeInterval(3_600)
        session.status = .completed
        session.client = client
        session.invoice = invoice

        let invoiceItem = InvoiceItem(id: UUID(), itemDescription: "Personal activities support")
        invoiceItem.invoice = invoice
        invoiceItem.session = session
        invoiceItem.quantity = 1.0
        invoiceItem.rate = 120.0
        invoiceItem.position = 2
        invoiceItem.unit = "hour"
        invoiceItem.taxRate = 10
        invoiceItem.serviceDate = baseDate
        invoiceItem.gstCode = GSTCode.p1.rawValue
        invoiceItem.ndisItemNumber = "01_011_0107_1_1"

        let agreement = ServiceAgreement(id: UUID())
        agreement.client = client
        agreement.effectiveFrom = baseDate.addingTimeInterval(-86_400 * 30)
        agreement.cancellationPolicyType = CancellationPolicyType.twoClearBusinessDays.rawValue
        agreement.allowsProviderTravel = true
        agreement.allowsTelehealth = true
        agreement.allowsNonFaceToFace = true
        agreement.signatureMethod = SignatureMethod.attestation.rawValue
        agreement.participantSignatoryName = "Jordan Participant"
        agreement.signedAt = baseDate.addingTimeInterval(-86_400 * 20)

        let supportLog = SupportLog(id: UUID())
        supportLog.client = client
        supportLog.session = session
        supportLog.participantName = "Jordan Participant"
        supportLog.participantNdisNumber = "4300123456"
        supportLog.supportItemNumber = "01_011_0107_1_1"
        supportLog.serviceDescription = "Community access support"
        supportLog.location = "Townsville"
        supportLog.deliveredFrom = baseDate
        supportLog.deliveredTo = baseDate.addingTimeInterval(3_600)
        supportLog.quantityHours = 1.0
        supportLog.deliveredBy = "Case Worker"
        supportLog.attestedBy = "Case Worker"
        supportLog.attestedAt = baseDate.addingTimeInterval(3_600)
        supportLog.signatureMethod = SignatureMethod.signature.rawValue
        supportLog.signedBy = "Jordan Participant"
        supportLog.signedAt = baseDate.addingTimeInterval(3_660)

        let batch = BulkClaimBatch(id: UUID())
        batch.createdAt = baseDate.addingTimeInterval(10_000)
        batch.fromDate = baseDate.addingTimeInterval(-86_400 * 7)
        batch.toDate = baseDate
        batch.status = BulkClaimBatchStatus.exported.rawValue
        batch.includeTravel = true
        batch.includeCancellations = true
        batch.claimReferenceStrategy = "invoice_number"
        batch.exportFileName = "NDIS-Claims-RoundTrip.csv"
        batch.exportedAt = baseDate.addingTimeInterval(12_000)
        batch.rowCount = 1
        batch.errorCount = 0
        batch.checksumSHA256 = "0123456789abcdef"

        let line = BulkClaimLine(id: UUID())
        line.batch = batch
        line.invoice = invoice
        line.invoiceItem = invoiceItem
        line.registrationNumber = "100200300"
        line.ndisNumber = "4300123456"
        line.supportsDeliveredFrom = baseDate
        line.supportsDeliveredTo = baseDate.addingTimeInterval(3_600)
        line.supportNumber = "01_011_0107_1_1"
        line.claimReference = "INV-ROUNDTRIP-001"
        line.quantity = 1.0
        line.unitPrice = 120.0
        line.gstCode = GSTCode.p1.rawValue
        line.claimTypeCode = BPRClaimTypeCode.thlt.rawValue
        line.isValid = true
        line.submissionStatus = BulkClaimSubmissionStatus.reconciled.rawValue
        line.submissionRef = "SUB-ROUNDTRIP-001"
        line.reconciliationNotes = "Portal reconciliation matched."
        line.reconciledAt = baseDate.addingTimeInterval(12_500)

        context.insert(business)
        context.insert(client)
        context.insert(invoice)
        context.insert(session)
        context.insert(invoiceItem)
        context.insert(agreement)
        context.insert(supportLog)
        context.insert(batch)
        context.insert(line)

        try context.save()
    }
}
