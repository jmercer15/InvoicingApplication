import Foundation
import SwiftData
import Core

/// SwiftData implementation of PlanManagerRepository
public final class PlanManagerRepositorySwiftData: PlanManagerRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    
    private let mapper: PlanManagerMapper
    private let addressMapper: AddressMapper
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.mapper = PlanManagerMapper()
        self.addressMapper = AddressMapper()
    }
    
    public func fetchAll() async throws -> [PlanManager] {
        let descriptor = FetchDescriptor<PlanManagerEntity>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { mapper.mapToDomain($0) }
        }
    }
    
    public func fetch(by id: UUID) async throws -> PlanManager? {
        let predicate = #Predicate<PlanManagerEntity> { manager in
            manager.id == id
        }
        let descriptor = FetchDescriptor<PlanManagerEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return mapper.mapToDomain(entity)
        }
    }
    
    public func fetch(by abn: String) async throws -> PlanManager? {
        let predicate = #Predicate<PlanManagerEntity> { manager in
            manager.abn == abn
        }
        let descriptor = FetchDescriptor<PlanManagerEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return mapper.mapToDomain(entity)
        }
    }
    
    public func create(_ planManager: PlanManager) async throws -> PlanManager {
        return try await MainActor.run {
            // Check if entity already exists with this ID
            let idPredicate = #Predicate<PlanManagerEntity> { m in m.id == planManager.id }
            let idDescriptor = FetchDescriptor<PlanManagerEntity>(predicate: idPredicate)
            if let existingEntity = try? modelContext.fetch(idDescriptor).first {
                // Entity already exists, update it instead
                var mutableEntity = existingEntity
                mapper.updateEntity(&mutableEntity, from: planManager)
                
                // Handle address update or clearing
                if let address = planManager.address {
                    if var existingAddress = existingEntity.address {
                        addressMapper.updateEntity(&existingAddress, from: address)
                    } else {
                        var addressEntity = AddressEntity()
                        addressMapper.updateEntity(&addressEntity, from: address)
                        // Insert address before assigning to relationship
                        if addressEntity.modelContext == nil {
                            modelContext.insert(addressEntity)
                        }
                        existingEntity.address = addressEntity
                    }
                } else {
                    // Explicitly clear address relationship if not provided
                    existingEntity.address = nil
                }
                
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    throw RepositoryError.saveFailed
                }
                return mapper.mapToDomain(existingEntity)
            }
            
            // Check if entity with same ABN already exists (ABN is unique)
            let abnPredicate = #Predicate<PlanManagerEntity> { m in m.abn == planManager.abn }
            let abnDescriptor = FetchDescriptor<PlanManagerEntity>(predicate: abnPredicate)
            if var existingByABN = try? modelContext.fetch(abnDescriptor).first {
                // Update existing entity instead of creating duplicate
                mapper.updateEntity(&existingByABN, from: planManager)
                
                // Handle address update or clearing
                if let address = planManager.address {
                    if var existingAddress = existingByABN.address {
                        addressMapper.updateEntity(&existingAddress, from: address)
                    } else {
                        var addressEntity = AddressEntity()
                        addressMapper.updateEntity(&addressEntity, from: address)
                        // Insert address before assigning to relationship
                        if addressEntity.modelContext == nil {
                            modelContext.insert(addressEntity)
                        }
                        existingByABN.address = addressEntity
                    }
                } else {
                    // Explicitly clear address relationship if not provided
                    existingByABN.address = nil
                }
                
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    throw RepositoryError.saveFailed
                }
                return mapper.mapToDomain(existingByABN)
            }
            
            // Create new entity
            var entity = PlanManagerEntity(
                id: planManager.id,
                abn: planManager.abn
            )
            mapper.updateEntity(&entity, from: planManager)
            
            // Insert entity first before assigning relationships
            // This ensures entity is registered and prevents duplicate insertion
            if entity.modelContext == nil {
                modelContext.insert(entity)
            }
            
            // Handle address if provided
            if let address = planManager.address {
                var addressEntity = AddressEntity()
                addressMapper.updateEntity(&addressEntity, from: address)
                // Insert address before assigning to relationship
                if addressEntity.modelContext == nil {
                    modelContext.insert(addressEntity)
                }
                // Now assign relationship
                entity.address = addressEntity
            } else {
                entity.address = nil
            }
            
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            return mapper.mapToDomain(entity)
        }
    }
    
    public func update(_ planManager: PlanManager) async throws -> PlanManager {
        return try await MainActor.run {
            let predicate = #Predicate<PlanManagerEntity> { m in m.id == planManager.id }
            let descriptor = FetchDescriptor<PlanManagerEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            var mutableEntity = entity
            mapper.updateEntity(&mutableEntity, from: planManager)
            
            // Handle address update or clearing
            if let address = planManager.address {
                if var existingAddress = entity.address {
                    // Update existing address using domain model
                    addressMapper.updateEntity(&existingAddress, from: address)
                } else {
                    // Create new address
                    var addressEntity = AddressEntity()
                    addressMapper.updateEntity(&addressEntity, from: address)
                    // Insert address before assigning to relationship
                    if addressEntity.modelContext == nil {
                        modelContext.insert(addressEntity)
                    }
                    entity.address = addressEntity
                }
            } else {
                // Explicitly clear address relationship if not provided
                entity.address = nil
            }
            
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            return mapper.mapToDomain(entity)
        }
    }
    
    public func delete(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<PlanManagerEntity> { m in m.id == id }
            let descriptor = FetchDescriptor<PlanManagerEntity>(predicate: predicate)
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
    
    public func search(query: String) async throws -> [PlanManager] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        let predicate = #Predicate<PlanManagerEntity> { manager in
            (manager.name?.localizedStandardContains(trimmedQuery) ?? false) ||
            manager.abn.localizedStandardContains(trimmedQuery) ||
            manager.email?.localizedStandardContains(trimmedQuery) == true ||
            manager.phone?.localizedStandardContains(trimmedQuery) == true
        }
        let descriptor = FetchDescriptor<PlanManagerEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { mapper.mapToDomain($0) }
        }
    }
    
    public func count() async throws -> Int {
        let descriptor = FetchDescriptor<PlanManagerEntity>()
        return try await MainActor.run {
            try modelContext.fetchCount(descriptor)
        }
    }
    
    // MARK: - Private Helpers
    // Note: fetchEntity helpers removed
}

