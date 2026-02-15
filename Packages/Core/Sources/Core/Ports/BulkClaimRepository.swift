import Foundation

public protocol BulkClaimRepository: Sendable {
    func createBatch(_ batch: BulkClaimBatch) async throws -> BulkClaimBatch
    func fetchBatches() async throws -> [BulkClaimBatch]
    func fetchBatch(by id: UUID) async throws -> BulkClaimBatch?
    func fetchLines(batchId: UUID) async throws -> [BulkClaimLine]
    func replaceLines(batchId: UUID, lines: [BulkClaimLine]) async throws
    func updateBatchLineReconciliation(
        batchId: UUID,
        submissionStatus: BulkClaimSubmissionStatus,
        submissionRef: String?,
        reconciliationNotes: String?,
        reconciledAt: Date?
    ) async throws -> Int
    func updateBatchStatus(id: UUID, status: BulkClaimBatchStatus, errorCount: Int) async throws
    func markExported(id: UUID, fileName: String, checksumSHA256: String, rowCount: Int) async throws
    func deleteBatch(id: UUID) async throws
}

public typealias BulkClaimRepositoryProtocol = BulkClaimRepository
