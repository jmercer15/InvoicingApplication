import XCTest
import SwiftData
import Core
@testable import Data

@MainActor
final class BulkClaimRepositoryTests: XCTestCase {
    private var modelContext: ModelContext!
    private var repository: BulkClaimRepositorySwiftData!

    override func setUp() async throws {
        try await super.setUp()
        let schema = complianceSchema()
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(container)
        repository = BulkClaimRepositorySwiftData(modelContext: modelContext)
    }

    override func tearDown() async throws {
        repository = nil
        modelContext = nil
        try await super.tearDown()
    }

    func testReplaceLinesUpdatesRowCountErrorCountAndStatus() async throws {
        let batch = try await repository.createBatch(makeBatch())
        let valid = makeLine(batchId: batch.id, isValid: true)
        let invalid = makeLine(batchId: batch.id, isValid: false)

        try await repository.replaceLines(batchId: batch.id, lines: [valid, invalid])

        let updatedBatch = try await repository.fetchBatch(by: batch.id)
        let lines = try await repository.fetchLines(batchId: batch.id)

        XCTAssertEqual(updatedBatch?.rowCount, 2)
        XCTAssertEqual(updatedBatch?.errorCount, 1)
        XCTAssertEqual(updatedBatch?.status, BulkClaimBatchStatus.failed.rawValue)
        XCTAssertEqual(lines.count, 2)
    }

    func testReplaceLinesAllValidSetsValidatedStatus() async throws {
        let batch = try await repository.createBatch(makeBatch())
        let line = makeLine(batchId: batch.id, isValid: true)

        try await repository.replaceLines(batchId: batch.id, lines: [line])

        let updatedBatch = try await repository.fetchBatch(by: batch.id)

        XCTAssertEqual(updatedBatch?.rowCount, 1)
        XCTAssertEqual(updatedBatch?.errorCount, 0)
        XCTAssertEqual(updatedBatch?.status, BulkClaimBatchStatus.validated.rawValue)
    }

    func testMarkExportedPersistsFileMetadata() async throws {
        let batch = try await repository.createBatch(makeBatch())

        try await repository.markExported(
            id: batch.id,
            fileName: "claims-2026-02-14.csv",
            checksumSHA256: "abc123",
            rowCount: 10
        )

        let exported = try await repository.fetchBatch(by: batch.id)

        XCTAssertEqual(exported?.status, BulkClaimBatchStatus.exported.rawValue)
        XCTAssertEqual(exported?.exportFileName, "claims-2026-02-14.csv")
        XCTAssertEqual(exported?.checksumSHA256, "abc123")
        XCTAssertEqual(exported?.rowCount, 10)
        XCTAssertNotNil(exported?.exportedAt)
    }

    func testFetchBatchesReturnsNewestFirst() async throws {
        let older = try await repository.createBatch(
            BulkClaimBatch(
                id: UUID(),
                createdAt: Date().addingTimeInterval(-60),
                fromDate: Date().addingTimeInterval(-86_400 * 2),
                toDate: Date().addingTimeInterval(-86_400)
            )
        )
        let newer = try await repository.createBatch(
            BulkClaimBatch(
                id: UUID(),
                createdAt: Date(),
                fromDate: Date().addingTimeInterval(-86_400),
                toDate: Date()
            )
        )

        let batches = try await repository.fetchBatches()

        XCTAssertEqual(batches.count, 2)
        XCTAssertEqual(batches.first?.id, newer.id)
        XCTAssertEqual(batches.last?.id, older.id)
    }

    func testReconciliationFieldsRoundTripOnLines() async throws {
        let batch = try await repository.createBatch(makeBatch())
        let reconciledAt = Date()
        let line = BulkClaimLine(
            id: UUID(),
            batchId: batch.id,
            registrationNumber: "1234567890",
            ndisNumber: "4300123456",
            supportsDeliveredFrom: Date().addingTimeInterval(-3_600),
            supportsDeliveredTo: Date(),
            supportNumber: "01_011_0107_1_1",
            quantity: 1.0,
            unitPrice: 100.0,
            gstCode: GSTCode.p2.rawValue,
            isValid: true,
            submissionStatus: BulkClaimSubmissionStatus.reconciled.rawValue,
            submissionRef: "SUB-REF-001",
            reconciliationNotes: "Matched remittance advice.",
            reconciledAt: reconciledAt
        )

        try await repository.replaceLines(batchId: batch.id, lines: [line])
        let fetched = try await repository.fetchLines(batchId: batch.id).first

        XCTAssertEqual(fetched?.submissionStatus, BulkClaimSubmissionStatus.reconciled.rawValue)
        XCTAssertEqual(fetched?.submissionRef, "SUB-REF-001")
        XCTAssertEqual(fetched?.reconciliationNotes, "Matched remittance advice.")
        XCTAssertNotNil(fetched?.reconciledAt)
        XCTAssertEqual(fetched?.reconciledAt, reconciledAt)
    }

    func testUpdateBatchLineReconciliationKeepsBatchExportedStatus() async throws {
        let batch = try await repository.createBatch(makeBatch())
        try await repository.replaceLines(batchId: batch.id, lines: [makeLine(batchId: batch.id, isValid: true)])
        try await repository.markExported(
            id: batch.id,
            fileName: "claims-export.csv",
            checksumSHA256: "hash-value",
            rowCount: 1
        )

        let reconciledAt = Date()
        let updatedCount = try await repository.updateBatchLineReconciliation(
            batchId: batch.id,
            submissionStatus: .reconciled,
            submissionRef: "SUB-123",
            reconciliationNotes: "Matched in portal.",
            reconciledAt: reconciledAt
        )

        let refreshedBatch = try await repository.fetchBatch(by: batch.id)
        let lines = try await repository.fetchLines(batchId: batch.id)

        XCTAssertEqual(updatedCount, 1)
        XCTAssertEqual(refreshedBatch?.status, BulkClaimBatchStatus.exported.rawValue)
        XCTAssertEqual(lines.first?.submissionStatus, BulkClaimSubmissionStatus.reconciled.rawValue)
        XCTAssertEqual(lines.first?.submissionRef, "SUB-123")
        XCTAssertEqual(lines.first?.reconciliationNotes, "Matched in portal.")
        XCTAssertEqual(lines.first?.reconciledAt, reconciledAt)
    }

    private func makeBatch() -> BulkClaimBatch {
        BulkClaimBatch(
            id: UUID(),
            fromDate: Date().addingTimeInterval(-86_400 * 7),
            toDate: Date()
        )
    }

    private func makeLine(batchId: UUID, isValid: Bool) -> BulkClaimLine {
        BulkClaimLine(
            id: UUID(),
            batchId: batchId,
            registrationNumber: "1234567890",
            ndisNumber: "4300123456",
            supportsDeliveredFrom: Date().addingTimeInterval(-3_600),
            supportsDeliveredTo: Date(),
            supportNumber: "01_011_0107_1_1",
            claimReference: "INV-TEST-001",
            quantity: 1.0,
            hours: nil,
            unitPrice: 100.0,
            gstCode: GSTCode.p2.rawValue,
            authorisedBy: nil,
            participantApproved: nil,
            inKindFundingProgram: nil,
            claimTypeCode: nil,
            cancellationReason: nil,
            abnOfSupportProvider: nil,
            invoiceId: nil,
            invoiceItemId: nil,
            isValid: isValid,
            validationErrorSummary: isValid ? nil : "Invalid test line"
        )
    }
}
