import Core
import PersistenceModels
import Foundation
import SwiftData

@MainActor
protocol BillableDraftMainContextPersisting {
    func updateDraftStatus(_ draft: BillableDraft, status: DraftStatus) throws
    func fetchSession(id: UUID) throws -> Session?
    func fetchClient(id: UUID) throws -> Client?
    func fetchClientService(id: UUID) throws -> ClientService?
}

@MainActor
struct SwiftDataBillableDraftMainContextPersistence: BillableDraftMainContextPersisting {
    let modelContext: ModelContext

    func updateDraftStatus(_ draft: BillableDraft, status: DraftStatus) throws {
        draft.draftStatus = status.rawValue
        draft.updatedAt = Date()
        try modelContext.save()
    }

    func fetchSession(id: UUID) throws -> Session? {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func fetchClient(id: UUID) throws -> Client? {
        var descriptor = FetchDescriptor<Client>(
            predicate: #Predicate<Client> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func fetchClientService(id: UUID) throws -> ClientService? {
        var descriptor = FetchDescriptor<ClientService>(
            predicate: #Predicate<ClientService> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
