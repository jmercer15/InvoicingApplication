import Core
import PersistenceModels
import Foundation

/// Reference data for the claim-batch build wizard (domain DTOs, no live models).
public struct ClaimBatchWizardReferenceData: Sendable, Equatable {
    public let clients: [ClientSnapshot]
    public let unbilledDrafts: [BillableDraftSnapshot]

    public init(clients: [ClientSnapshot], unbilledDrafts: [BillableDraftSnapshot]) {
        self.clients = clients
        self.unbilledDrafts = unbilledDrafts
    }
}

/// Main-context claim batch reads and writes for Settings workflows.
///
/// Implemented by `SwiftDataClaimBatchMainContextPersistence` in the Data package.
@MainActor
public protocol ClaimBatchPersisting: AnyObject, Sendable {
    func fetchBatch(id: UUID) throws -> BulkClaimBatch?
    func fetchLines(forBatch batchId: UUID) throws -> [BulkClaimLine]
    func fetchWizardReferenceData() throws -> ClaimBatchWizardReferenceData
    func draftId(containingClaimableLineId lineId: UUID) throws -> UUID?
    func insertBatch(_ snapshot: BulkClaimBatchSnapshot, lines: [BulkClaimLineSnapshot]) throws -> BulkClaimBatch
    func markSubmitted(batch: BulkClaimBatch) throws
    func saveValidationChanges() throws
    func markExported(batch: BulkClaimBatch, fileName: String, checksumSHA256: String, lineCount: Int) throws
}
