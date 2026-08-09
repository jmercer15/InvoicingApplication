import Foundation
import Testing
import SwiftData
import Core
import PersistenceModels
@testable import Data

@MainActor
@Suite struct BulkClaimWorkspaceOperationsTests {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let bulkClaimBuilderActor: BulkClaimBuilderActor
    private let operations: BulkClaimWorkspaceOperations

    init() throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        self.modelContainer = container
        self.modelContext = context
        self.bulkClaimBuilderActor = BulkClaimBuilderActor(modelContainer: container)
        self.operations = BulkClaimWorkspaceOperations(
            bulkClaimBuilderActor: bulkClaimBuilderActor,
            modelContainer: container
        )
    }

    @Test func ConformsToModelActorAndAppliesClaimReconciliation() async throws {
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
        
        #expect(updatedCount == 1)
        
        let lineID = line.id
        let descriptor = FetchDescriptor<BulkClaimLine>(predicate: #Predicate { $0.id == lineID })
        let refreshedLine = try modelContext.fetch(descriptor).first
        #expect(refreshedLine?.submissionStatus == BulkClaimSubmissionStatus.reconciled.rawValue)
        #expect(refreshedLine?.submissionRef == "REF-XYZ")
        #expect(refreshedLine?.reconciliationNotes == "Manual test reconciliation")
    }
}
