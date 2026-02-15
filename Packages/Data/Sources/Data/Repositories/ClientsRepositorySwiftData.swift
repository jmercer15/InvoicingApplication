import Foundation
import SwiftData
import Core

/// SwiftData implementation of ClientsRepository
public final class ClientsRepositorySwiftData: ClientsRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    private let mapper: ClientMapper
    private let addressMapper: AddressMapper
    
    public init(modelContext: ModelContext, mapper: ClientMapper = ClientMapper(), addressMapper: AddressMapper = AddressMapper()) {
        self.modelContext = modelContext
        self.mapper = mapper
        self.addressMapper = addressMapper
    }
    
    // ... (fetchAll, fetchActive, fetch x2 unchanged)

    public func fetchAll() async throws -> [Client] {
        let descriptor = FetchDescriptor<ClientEntity>(
            sortBy: [SortDescriptor(\.fullName, order: .forward)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetchActive() async throws -> [Client] {
        let predicate = #Predicate<ClientEntity> { client in
            client.status.rawValue == "Active"
        }
        let descriptor = FetchDescriptor<ClientEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.fullName, order: .forward)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetch(by id: UUID) async throws -> Client? {
        let predicate = #Predicate<ClientEntity> { client in
            client.id == id
        }
        let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return self.mapper.mapToDomain(entity)
        }
    }
    
    public func fetch(by ndisNumber: String) async throws -> Client? {
        let predicate = #Predicate<ClientEntity> { client in
            client.ndisNumber == ndisNumber
        }
        let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return self.mapper.mapToDomain(entity)
        }
    }
    
    public func create(_ client: Client) async throws -> Client {
        // Check if entity already exists with this ID
        return try await MainActor.run {
            let predicate = #Predicate<ClientEntity> { c in c.id == client.id }
            let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
            if var existingEntity = try? modelContext.fetch(descriptor).first {
                // Entity already exists, update it instead
                self.mapper.updateEntity(&existingEntity, from: client)
                self.updateRelationships(entity: existingEntity, client: client)
                
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    throw RepositoryError.saveFailed
                }
                return self.mapper.mapToDomain(existingEntity)
            }
            
            // Check if entity with same NDIS number already exists (NDIS number is unique)
            let ndisPredicate = #Predicate<ClientEntity> { c in c.ndisNumber == client.ndisNumber }
            let ndisDescriptor = FetchDescriptor<ClientEntity>(predicate: ndisPredicate)
            if var existingByNDIS = try? modelContext.fetch(ndisDescriptor).first {
                // Update existing entity instead of creating duplicate
                self.mapper.updateEntity(&existingByNDIS, from: client)
                self.updateRelationships(entity: existingByNDIS, client: client)
                
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    throw RepositoryError.saveFailed
                }
                return self.mapper.mapToDomain(existingByNDIS)
            }
            
            // Create new entity
            var entity = ClientEntity(
                id: client.id,
                ndisNumber: client.ndisNumber,
                fullName: client.fullName,
                status: ClientStatus(rawValue: client.status) ?? .active
            )
            self.mapper.updateEntity(&entity, from: client)
            self.updateRelationships(entity: entity, client: client)
            
            // Only insert if not already in context
            if entity.modelContext == nil {
                modelContext.insert(entity)
            }
            
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            return self.mapper.mapToDomain(entity)
        }
    }
    
    public func update(_ client: Client) async throws -> Client {
        return try await MainActor.run {
            let predicate = #Predicate<ClientEntity> { c in c.id == client.id }
            let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
            guard var entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            self.mapper.updateEntity(&entity, from: client)
            self.updateRelationships(entity: entity, client: client)
            
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            return self.mapper.mapToDomain(entity)
        }
    }
    
    // Helper to update relationships
    private func updateRelationships(entity: ClientEntity, client: Client) {
        // Update Payee
        if let payeeId = client.payee?.id {
            let payeePredicate = #Predicate<PayeeEntity> { $0.id == payeeId }
            let payeeDescriptor = FetchDescriptor<PayeeEntity>(predicate: payeePredicate)
            if let payeeEntity = try? modelContext.fetch(payeeDescriptor).first {
                entity.payee = payeeEntity
            } else {
                entity.payee = nil
            }
        } else {
            entity.payee = nil
        }
        
        // Update Address
        if let address = client.address {
            // Check if entity already has an address
            if var addressEntity = entity.address {
                // Update existing address
                addressMapper.updateEntity(&addressEntity, from: address)
            } else {
                // Check if address entity exists in context (by ID)
                let addressId = address.id
                let addressPredicate = #Predicate<AddressEntity> { $0.id == addressId }
                let addressDescriptor = FetchDescriptor<AddressEntity>(predicate: addressPredicate)
                
                if var existingAddress = try? modelContext.fetch(addressDescriptor).first {
                    addressMapper.updateEntity(&existingAddress, from: address)
                    entity.address = existingAddress
                } else {
                    // Create new address entity
                    let newAddress = addressMapper.mapToEntity(address)
                    modelContext.insert(newAddress)
                    entity.address = newAddress
                }
            }
        } else {
            entity.address = nil
        }
    }
    
    public func delete(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<ClientEntity> { c in c.id == id }
            let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
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
    
    public func archive(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<ClientEntity> { c in c.id == id }
            let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            entity.status = .archived
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
        }
    }
    
    public func reactivate(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<ClientEntity> { c in c.id == id }
            let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            entity.status = .active
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
        }
    }
    
    public func updateStatus(id: UUID, status: String) async throws {
        try await MainActor.run {
            let predicate = #Predicate<ClientEntity> { c in c.id == id }
            let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            entity.status = ClientStatus(rawValue: status) ?? .active
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
        }
    }
    
    public func search(query: String) async throws -> [Client] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        let predicate = #Predicate<ClientEntity> { client in
            client.fullName.localizedStandardContains(trimmedQuery) ||
            client.ndisNumber.localizedStandardContains(trimmedQuery) ||
            client.email?.localizedStandardContains(trimmedQuery) == true
        }
        let descriptor = FetchDescriptor<ClientEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.fullName, order: .forward)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetch(limit: Int, offset: Int) async throws -> [Client] {
        var descriptor = FetchDescriptor<ClientEntity>(
            sortBy: [SortDescriptor(\.fullName, order: .forward)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func count() async throws -> Int {
        let descriptor = FetchDescriptor<ClientEntity>()
        return try await MainActor.run {
            try modelContext.fetchCount(descriptor)
        }
    }
    
    public func countActive() async throws -> Int {
        let predicate = #Predicate<ClientEntity> { client in
            client.status.rawValue == "Active"
        }
        let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
        return try await MainActor.run {
            try modelContext.fetchCount(descriptor)
        }
    }
    
    public func fetch(byPayeeId payeeId: UUID) async throws -> [Client] {
        let predicate = #Predicate<ClientEntity> { client in
            client.payee?.id == payeeId
        }
        let descriptor = FetchDescriptor<ClientEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.fullName, order: .forward)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetch(byPlanManagerId planManagerId: UUID) async throws -> [Client] {
        let predicate = #Predicate<ClientEntity> { client in
            client.planManager?.id == planManagerId
        }
        let descriptor = FetchDescriptor<ClientEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.fullName, order: .forward)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    // MARK: - Private Helpers
    // Note: fetchEntity helper removed - all entity operations now happen directly within MainActor.run blocks
    // to avoid Sendable conformance issues with ClientEntity
}
