import Core
import Foundation
import SwiftData

@MainActor
protocol ImportExportClaimPersisting {
    func fetchBulkClaimLineEntities(batchId: UUID) throws -> [BulkClaimLine]
    func fetchClaimBatch(by id: UUID) throws -> BulkClaimBatch
    func fetchClaimHistoryBatches() -> [BulkClaimBatch]
    func fetchClaimHistoryLines() -> [BulkClaimLine]
    func fetchClaimHistoryClients() -> [Client]
    func fetchClaimHistoryInvoices() -> [Invoice]
}

@MainActor
struct SwiftDataImportExportClaimPersistence: ImportExportClaimPersisting {
    let modelContext: ModelContext

    func fetchBulkClaimLineEntities(batchId: UUID) throws -> [BulkClaimLine] {
        let lines = try modelContext.fetch(
            FetchDescriptor<BulkClaimLine>(predicate: #Predicate { $0.batch?.id == batchId })
        )
        return lines.sorted { $0.supportsDeliveredFrom < $1.supportsDeliveredFrom }
    }

    func fetchClaimBatch(by id: UUID) throws -> BulkClaimBatch {
        let descriptor = FetchDescriptor<BulkClaimBatch>(predicate: #Predicate { $0.id == id })
        guard let batch = try modelContext.fetch(descriptor).first else {
            throw NSError(
                domain: "ImportExportViewModel",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Claim batch not found for id \(id.uuidString)."]
            )
        }
        return batch
    }

    func fetchClaimHistoryBatches() -> [BulkClaimBatch] {
        let descriptor = FetchDescriptor<BulkClaimBatch>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchClaimHistoryLines() -> [BulkClaimLine] {
        let descriptor = FetchDescriptor<BulkClaimLine>(sortBy: [SortDescriptor(\.supportsDeliveredFrom)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchClaimHistoryClients() -> [Client] {
        let descriptor = FetchDescriptor<Client>(sortBy: [SortDescriptor(\.fullName)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchClaimHistoryInvoices() -> [Invoice] {
        let descriptor = FetchDescriptor<Invoice>(sortBy: [SortDescriptor(\.issueDate, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
