import Foundation
import SwiftData
import Core

/// SwiftData-backed implementation of `ClientServicesRepository`
public final class ClientServicesRepositorySwiftData: ClientServicesRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    public func fetch(for clientId: UUID) async throws -> [ClientService] {
        let predicate = #Predicate<ClientServiceEntity> { clientService in
            clientService.client?.id == clientId
        }
        let descriptor = FetchDescriptor<ClientServiceEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.serviceName, order: .forward)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { ClientService(from: $0) }
    }
    
    public func create(_ clientService: ClientService) async throws -> ClientService {
        guard let clientEntity = try await fetchClientEntity(by: clientService.clientId) else {
            throw RepositoryError.entityNotFound
        }
        
        let entity = ClientServiceEntity(
            id: clientService.id,
            serviceName: clientService.serviceName,
            unit: clientService.unit,
            rate: clientService.rate
        )
        entity.client = clientEntity
        entity.status = clientService.status
        entity.isActive = clientService.isActive
        entity.startDate = clientService.startDate
        entity.endDate = clientService.endDate
        entity.ndisCode = clientService.ndisCode
        entity.ndisItem = try await resolveNDISItem(for: clientService)
        
        modelContext.insert(entity)
        try modelContext.save()
        return ClientService(from: entity)
    }
    
    public func update(_ clientService: ClientService) async throws -> ClientService {
        guard let entity = try await fetchClientServiceEntity(by: clientService.id) else {
            throw RepositoryError.entityNotFound
        }
        
        entity.update(from: clientService)
        
        if entity.client?.id != clientService.clientId {
            entity.client = try await fetchClientEntity(by: clientService.clientId)
        }
        
        entity.ndisItem = try await resolveNDISItem(for: clientService)
        
        try modelContext.save()
        return ClientService(from: entity)
    }
    
    public func delete(id: UUID) async throws {
        guard let entity = try await fetchClientServiceEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        modelContext.delete(entity)
        try modelContext.save()
    }
    
    // MARK: - Helpers
    
    private func fetchClientEntity(by id: UUID) async throws -> ClientEntity? {
        let predicate = #Predicate<ClientEntity> { client in
            client.id == id
        }
        let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
    
    private func fetchClientServiceEntity(by id: UUID) async throws -> ClientServiceEntity? {
        let predicate = #Predicate<ClientServiceEntity> { clientService in
            clientService.id == id
        }
        let descriptor = FetchDescriptor<ClientServiceEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
    
    private func fetchNDISItemEntity(by id: UUID) async throws -> NDISItemEntity? {
        let predicate = #Predicate<NDISItemEntity> { item in
            item.id == id
        }
        let descriptor = FetchDescriptor<NDISItemEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
    
    private func resolveNDISItem(for clientService: ClientService) async throws -> NDISItemEntity? {
        if let ndisItemId = clientService.ndisItemId {
            guard let item = try await fetchNDISItemEntity(by: ndisItemId) else {
                throw RepositoryError.entityNotFound
            }
            return item
        }
        return nil
    }
}
