import XCTest
import SwiftData
import Core
@testable import Data

@MainActor
final class BulkClaimWorkspaceOperationsTests: XCTestCase {
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var bulkClaimBuilderActor: BulkClaimBuilderActor!
    private var operations: BulkClaimWorkspaceOperations!

    override func setUp() async throws {
        try await super.setUp()
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        modelContainer = container
        modelContext = context
        bulkClaimBuilderActor = BulkClaimBuilderActor(modelContainer: modelContainer)
        operations = BulkClaimWorkspaceOperations(
            bulkClaimBuilderActor: bulkClaimBuilderActor,
            modelContainer: modelContainer
        )
    }

    override func tearDown() async throws {
        operations = nil
        bulkClaimBuilderActor = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    func testConformsToModelActorAndAppliesClaimReconciliation() async throws {
        let batch = BulkClaimBatch(id: UUID())
        batch.status = "draft"
        modelContext.insert(batch)
        
        let line = BulkClaimLine(id: UUID())
        line.claimReference = "REF-123"
        line.batch = batch
        modelContext.insert(line)
        
        try modelContext.save()

        let updatedCount = try await operations.applyClaimReconciliation(
            batchId: batch.id,
            submissionStatus: .reconciled,
            submissionRef: "REF-XYZ",
            notes: "Manual test reconciliation"
        )
        
        XCTAssertEqual(updatedCount, 1)
        
        let lineID = line.id
        let descriptor = FetchDescriptor<BulkClaimLine>(predicate: #Predicate { $0.id == lineID })
        let refreshedLine = try modelContext.fetch(descriptor).first
        XCTAssertEqual(refreshedLine?.submissionStatus, BulkClaimSubmissionStatus.reconciled.rawValue)
        XCTAssertEqual(refreshedLine?.submissionRef, "REF-XYZ")
        XCTAssertEqual(refreshedLine?.reconciliationNotes, "Manual test reconciliation")
    }
}
