import Foundation
import PersistenceModels

/// Main-context claim history reads for Settings import/export UI.
@MainActor
public protocol ImportExportClaimPersisting: AnyObject {
    func fetchBulkClaimLineEntities(batchId: UUID) throws -> [BulkClaimLine]
    func fetchClaimBatch(by id: UUID) throws -> BulkClaimBatch
    func fetchClaimHistoryBatches() -> [BulkClaimBatch]
    func fetchClaimHistoryLines() -> [BulkClaimLine]
    func fetchClaimHistoryClients() -> [Client]
    func fetchClaimHistoryInvoices() -> [Invoice]
}
