import XCTest
import SwiftData
@testable import Data

@MainActor
final class AllDataComplianceRoundTripTests: XCTestCase {
    func testAllDataExportAndImportRoundTripsComplianceEntitiesAndLinks() throws {
        let sourceContext = try makeInMemoryContext()
        try insertComplianceFixture(into: sourceContext)

        let exportedData = try SwiftDataExportService.exportAllEntitiesToJSON(context: sourceContext)
        let exportedJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: exportedData) as? [String: Any])

        XCTAssertEqual((exportedJSON["ServiceAgreementEntity"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual((exportedJSON["SupportLogEntity"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual((exportedJSON["BulkClaimBatchEntity"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual((exportedJSON["BulkClaimLineEntity"] as? [[String: Any]])?.count, 1)

        let destinationContext = try makeInMemoryContext()
        let importResults = try AllDataImportService.importAllData(from: exportedData, context: destinationContext)
        let totalFailed = importResults.reduce(0) { $0 + $1.failed }
        XCTAssertEqual(totalFailed, 0)

        let importedAgreements = try destinationContext.fetch(FetchDescriptor<ServiceAgreementEntity>())
        let importedLogs = try destinationContext.fetch(FetchDescriptor<SupportLogEntity>())
        let importedBatches = try destinationContext.fetch(FetchDescriptor<BulkClaimBatchEntity>())
        let importedLines = try destinationContext.fetch(FetchDescriptor<BulkClaimLineEntity>())

        XCTAssertEqual(importedAgreements.count, 1)
        XCTAssertEqual(importedLogs.count, 1)
        XCTAssertEqual(importedBatches.count, 1)
        XCTAssertEqual(importedLines.count, 1)

        XCTAssertNotNil(importedAgreements.first?.client)
        XCTAssertNotNil(importedLogs.first?.client)
        XCTAssertNotNil(importedLogs.first?.session)
        XCTAssertNotNil(importedLines.first?.batch)
        XCTAssertNotNil(importedLines.first?.invoice)
        XCTAssertNotNil(importedLines.first?.invoiceItem)
        XCTAssertEqual(importedLines.first?.submissionStatus, BulkClaimSubmissionStatus.reconciled.rawValue)
        XCTAssertEqual(importedLines.first?.submissionRef, "SUB-ROUNDTRIP-001")
        XCTAssertEqual(importedLines.first?.reconciliationNotes, "Portal reconciliation matched.")
        XCTAssertNotNil(importedLines.first?.reconciledAt)
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = complianceSchema()
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func insertComplianceFixture(into context: ModelContext) throws {
        let baseDate = Date(timeIntervalSince1970: 1_738_800_000)

        let business = BusinessEntity(id: UUID(), abn: "53004085616")
        business.name = "Acme Support"
        business.defaultGstCode = GSTCode.p2.rawValue
        business.isRegisteredProvider = true
        business.ndiaOrganisationID = "100200300"

        let client = ClientEntity(
            id: UUID(),
            ndisNumber: "4300123456",
            fullName: "Jordan Participant",
            status: .active
        )

        let invoice = InvoiceEntity(id: UUID(), invoiceNumber: "INV-ROUNDTRIP-001")
        invoice.client = client
        invoice.business = business
        invoice.status = .readyToSend

        let session = SessionEntity(id: UUID())
        session.title = "Community access support"
        session.startTime = baseDate
        session.endTime = baseDate.addingTimeInterval(3_600)
        session.status = .completed
        session.client = client
        session.invoice = invoice

        let invoiceItem = InvoiceItemEntity(id: UUID(), itemDescription: "Personal activities support")
        invoiceItem.invoice = invoice
        invoiceItem.session = session
        invoiceItem.quantity = 1.0
        invoiceItem.rate = 120.0
        invoiceItem.serviceDate = baseDate
        invoiceItem.gstCode = GSTCode.p1.rawValue
        invoiceItem.ndisItemNumber = "01_011_0107_1_1"

        let agreement = ServiceAgreementEntity(id: UUID())
        agreement.client = client
        agreement.effectiveFrom = baseDate.addingTimeInterval(-86_400 * 30)
        agreement.cancellationPolicyType = CancellationPolicyType.twoClearBusinessDays.rawValue
        agreement.allowsProviderTravel = true
        agreement.allowsTelehealth = true
        agreement.allowsNonFaceToFace = true
        agreement.signatureMethod = SignatureMethod.attestation.rawValue
        agreement.participantSignatoryName = "Jordan Participant"
        agreement.signedAt = baseDate.addingTimeInterval(-86_400 * 20)

        let supportLog = SupportLogEntity(id: UUID())
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

        let batch = BulkClaimBatchEntity(id: UUID())
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

        let line = BulkClaimLineEntity(id: UUID())
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
