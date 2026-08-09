import Core
import Foundation

/// Builds bulk-claim batch snapshots from persisted billable draft identifiers.
@MainActor
public protocol ClaimBatchBuilding: Sendable {
    func buildBatch(
        fromDraftIDs draftIDs: [UUID],
        fromDate: Date,
        toDate: Date,
        claimReferenceStrategy: String
    ) async throws -> (batch: BulkClaimBatchSnapshot, lines: [BulkClaimLineSnapshot])
}
