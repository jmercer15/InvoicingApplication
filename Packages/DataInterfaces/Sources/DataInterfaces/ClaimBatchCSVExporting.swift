import Core
import Foundation
import PersistenceModels

/// Prepares NDIA BPR CSV payloads and checksums for Settings claim export.
public protocol ClaimBatchCSVExporting: Sendable {
    func csvData(lines: [BulkClaimLine]) -> Data
    func suggestedFileName(at date: Date) -> String
}

/// SHA-256 verification for bulk-claim CSV exports.
public protocol BulkClaimExportHashVerifying: Sendable {
    func hash(for data: Data) -> String
    func verify(snapshots: [BulkClaimLineSnapshot], expectedSHA256: String) -> Bool
}
