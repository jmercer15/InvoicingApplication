import Core
import DataInterfaces
import Foundation
import PersistenceModels
import SwiftData

extension ClaimBatchBuilderService: ClaimBatchBuilding {}

extension BPRPreflightValidator: ClaimBatchPreflightValidating {}

extension BPRCSVWriter: ClaimBatchCSVExporting {
    public func suggestedFileName(at date: Date) -> String {
        "BPR_Export_\(ExportMachineFormatting.bprExportTimestamp(date)).csv"
    }
}

extension BulkClaimExportHashVerifier: BulkClaimExportHashVerifying {}

extension ClaimReconciliationService: ClaimReconciling {}

extension BPRFParser: BPRFParsing {}

extension ImportExportCoordinator: ImportExportCoordinating {}

@MainActor
public final class SwiftDataImportExportClaimPersistence: ImportExportClaimPersisting {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchBulkClaimLineEntities(batchId: UUID) throws -> [BulkClaimLine] {
        let lines = try modelContext.fetch(
            FetchDescriptor<BulkClaimLine>(predicate: #Predicate { $0.batch?.id == batchId })
        )
        return lines.sorted { $0.supportsDeliveredFrom < $1.supportsDeliveredFrom }
    }

    public func fetchClaimBatch(by id: UUID) throws -> BulkClaimBatch {
        let descriptor = FetchDescriptor<BulkClaimBatch>(predicate: #Predicate { $0.id == id })
        guard let batch = try modelContext.fetch(descriptor).first else {
            throw NSError(
                domain: "ImportExportClaimPersisting",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Claim batch not found for id \(id.uuidString)."]
            )
        }
        return batch
    }

    public func fetchClaimHistoryBatches() -> [BulkClaimBatch] {
        let descriptor = FetchDescriptor<BulkClaimBatch>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func fetchClaimHistoryLines() -> [BulkClaimLine] {
        let descriptor = FetchDescriptor<BulkClaimLine>(sortBy: [SortDescriptor(\.supportsDeliveredFrom)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func fetchClaimHistoryClients() -> [Client] {
        let descriptor = FetchDescriptor<Client>(sortBy: [SortDescriptor(\.fullName)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func fetchClaimHistoryInvoices() -> [Invoice] {
        let descriptor = FetchDescriptor<Invoice>(sortBy: [SortDescriptor(\.issueDate, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

@ModelActor
public actor SessionWipeActor: CalendarSessionWiping {
    public func wipeAllSessions() async throws {
        try modelContext.delete(model: Session.self)
        try modelContext.save()
    }
}

@MainActor
public final class SwiftDataClientRelationshipDeleter: ClientRelationshipDeleting {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func deleteClient(id: UUID, deleteSessions: Bool) async throws {
        let clientID = id
        var descriptor = FetchDescriptor<Client>(predicate: #Predicate { $0.id == clientID })
        descriptor.fetchLimit = 1
        guard let client = try modelContext.fetch(descriptor).first else { return }
        if deleteSessions {
            try? modelContext.delete(
                model: Session.self,
                where: #Predicate { $0.client?.id == clientID }
            )
        }
        modelContext.delete(client)
        try modelContext.save()
    }

    public func deletePayee(id: UUID) async throws {
        let payeeID = id
        var descriptor = FetchDescriptor<Payee>(predicate: #Predicate { $0.id == payeeID })
        descriptor.fetchLimit = 1
        guard let payee = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(payee)
        try modelContext.save()
    }

    public func deletePlanManager(id: UUID) async throws {
        let planManagerID = id
        var descriptor = FetchDescriptor<PlanManager>(predicate: #Predicate { $0.id == planManagerID })
        descriptor.fetchLimit = 1
        guard let planManager = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(planManager)
        try modelContext.save()
    }
}
