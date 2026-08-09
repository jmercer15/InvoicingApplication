import Core
import Foundation

/// Settings import/export catalog operations and data wipe facade.
public protocol ImportExportCoordinating: Sendable {
    func fetchAvailableEffectiveDates() async throws -> [Date]
    func importNDISItemsFromCSV(url: URL, fileName: String) async throws -> ImportResult
    func importNDISItemsFromExcel(url: URL, fileName: String) async throws -> ImportResult
    func importSpecificData(source: ImportSource, data: Data, fileName: String) async throws -> ImportResult
    func importFromFile(url: URL, source: ImportSource) async throws -> ImportResult
    func importAllData(url: URL) async throws -> ImportResult
    func importAllData(fileData: Data, fileName: String) async throws -> ImportResult
    func export(
        source: ImportSource,
        redaction: ExportRedactionPreset,
        dateString: String?,
        encryption: ExportEncryptionOptions?
    ) async throws -> (data: Data, fileName: String)
    func exportAllData(
        redaction: ExportRedactionPreset,
        dateString: String?,
        encryption: ExportEncryptionOptions?
    ) async throws -> (data: Data, fileName: String)
    func recalculateCurrentStatus() async throws -> (updated: Int, total: Int)
    func clearAllNDISItems() async throws -> (deletedItems: Int, deletedPrices: Int)
    func wipeAllData() async throws -> (totalDeleted: Int, deletedByEntity: [String: Int])
    func applyClaimReconciliation(
        batchId: UUID,
        submissionStatus: BulkClaimSubmissionStatus,
        submissionRef: String?,
        notes: String?
    ) async throws -> Int
    func buildClaimBatch(
        fromDraftIDs draftIDs: [UUID],
        fromDate: Date,
        toDate: Date,
        includeTravel: Bool,
        includeCancellations: Bool,
        claimReferenceStrategy: String
    ) async throws -> (batch: BulkClaimBatchSnapshot, lines: [BulkClaimLineSnapshot])
    func createClaimBatch(
        fromDate: Date,
        toDate: Date,
        includeTravel: Bool,
        includeCancellations: Bool,
        claimReferenceStrategy: String
    ) async throws -> (batchId: UUID, summary: BulkClaimValidationSummary)
    func validateClaimBatch(batchId: UUID) async throws -> BulkClaimValidationSummary
    func summarizeClaimBatch(batchId: UUID) async throws -> BulkClaimValidationSummary
    func prepareClaimBatchCSVExport(
        batchId: UUID,
        dateString: String?
    ) async throws -> (data: Data, fileName: String, summary: BulkClaimValidationSummary)
}
