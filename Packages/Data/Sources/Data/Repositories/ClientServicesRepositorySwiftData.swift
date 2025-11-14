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
        let entities = try await MainActor.run {
            try modelContext.fetch(descriptor)
        }
        return entities.map { ClientService(from: $0) }
    }
    
    public func fetch(by id: UUID) async throws -> ClientService? {
        let entity = try await MainActor.run {
            let predicate = #Predicate<ClientServiceEntity> { clientService in
                clientService.id == id
            }
            let descriptor = FetchDescriptor<ClientServiceEntity>(predicate: predicate)
            return try modelContext.fetch(descriptor).first
        }
        return entity.map { ClientService(from: $0) }
    }
    
    public func create(_ clientService: ClientService) async throws -> ClientService {
        // Fetch NDIS item outside MainActor.run since it's async
        let ndisItem = try? await resolveNDISItem(for: clientService)
        
        return try await MainActor.run {
            // Fetch client entity within MainActor context to avoid Sendable issues
            let clientPredicate = #Predicate<ClientEntity> { client in
                client.id == clientService.clientId
            }
            let clientDescriptor = FetchDescriptor<ClientEntity>(predicate: clientPredicate)
            guard let clientEntity = try modelContext.fetch(clientDescriptor).first else {
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
            entity.ndisItem = ndisItem
            
            if entity.modelContext == nil {
            modelContext.insert(entity)
            }
            
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            return ClientService(from: entity)
        }
    }
    
    public func update(_ clientService: ClientService) async throws -> ClientService {
        // Fetch NDIS item outside MainActor.run since it's async
        let ndisItem = try? await resolveNDISItem(for: clientService)
        
        return try await MainActor.run {
            // Fetch service entity within MainActor context
            let servicePredicate = #Predicate<ClientServiceEntity> { service in
                service.id == clientService.id
            }
            let serviceDescriptor = FetchDescriptor<ClientServiceEntity>(predicate: servicePredicate)
            guard let entity = try modelContext.fetch(serviceDescriptor).first else {
                throw RepositoryError.entityNotFound
            }
            
            entity.update(from: clientService)
            
            // Fetch client entity if needed, all within MainActor context
            if entity.client?.id != clientService.clientId {
                let clientPredicate = #Predicate<ClientEntity> { client in
                    client.id == clientService.clientId
                }
                let clientDescriptor = FetchDescriptor<ClientEntity>(predicate: clientPredicate)
                if let newClient = try modelContext.fetch(clientDescriptor).first {
                    entity.client = newClient
                } else {
                    // Client not found, clear relationship
                    entity.client = nil
                }
            }
            
            entity.ndisItem = ndisItem
            
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            return ClientService(from: entity)
        }
    }
    
    public func delete(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<ClientServiceEntity> { $0.id == id }
            let descriptor = FetchDescriptor<ClientServiceEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            modelContext.delete(entity)
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
        }
    }
    
    // MARK: - Helpers
    
    func fetchClientServiceEntity(by id: UUID) async throws -> ClientServiceEntity? {
        return try await MainActor.run {
            let predicate = #Predicate<ClientServiceEntity> { clientService in
                clientService.id == id
            }
            let descriptor = FetchDescriptor<ClientServiceEntity>(predicate: predicate)
            return try modelContext.fetch(descriptor).first
        }
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
