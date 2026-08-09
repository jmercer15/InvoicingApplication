import Core
import Foundation

/// Applies BPRF reconciliation results to persisted bulk-claim lines.
public protocol ClaimReconciling: Sendable {
    func applyBPRFResults(
        batchId: UUID,
        results: [BPRFResultLine]
    ) async throws -> (updatedLineCount: Int, unmatchedReferences: [String])
}
