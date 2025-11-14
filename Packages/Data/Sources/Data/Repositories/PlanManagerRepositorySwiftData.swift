import Foundation
import SwiftData
import Core

/// SwiftData implementation of PlanManagerRepository
public final class PlanManagerRepositorySwiftData: PlanManagerRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    public func fetchAll() async throws -> [PlanManager] {
        let descriptor = FetchDescriptor<PlanManagerEntity>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { PlanManager(from: $0) }
        }
    }
    
    public func fetch(by id: UUID) async throws -> PlanManager? {
        let predicate = #Predicate<PlanManagerEntity> { manager in
            manager.id == id
        }
        let descriptor = FetchDescriptor<PlanManagerEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return PlanManager(from: entity)
        }
    }
    
    public func fetch(by abn: String) async throws -> PlanManager? {
        let predicate = #Predicate<PlanManagerEntity> { manager in
            manager.abn == abn
        }
        let descriptor = FetchDescriptor<PlanManagerEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return PlanManager(from: entity)
        }
    }
    
    public func create(_ planManager: PlanManager) async throws -> PlanManager {
        return try await MainActor.run {
            // Check if entity already exists with this ID
            let idPredicate = #Predicate<PlanManagerEntity> { m in m.id == planManager.id }
            let idDescriptor = FetchDescriptor<PlanManagerEntity>(predicate: idPredicate)
            if let existingEntity = try? modelContext.fetch(idDescriptor).first {
                // Entity already exists, update it instead
                existingEntity.update(from: planManager)
                
                // Handle address update or clearing
                if let address = planManager.address {
                    if let existingAddress = existingEntity.address {
                        existingAddress.update(from: address)
                    } else {
                        let addressEntity = AddressEntity()
                        addressEntity.update(from: address)
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
                return PlanManager(from: existingEntity)
            }
            
            // Check if entity with same ABN already exists (ABN is unique)
            let abnPredicate = #Predicate<PlanManagerEntity> { m in m.abn == planManager.abn }
            let abnDescriptor = FetchDescriptor<PlanManagerEntity>(predicate: abnPredicate)
            if let existingByABN = try? modelContext.fetch(abnDescriptor).first {
                // Update existing entity instead of creating duplicate
                existingByABN.update(from: planManager)
                
                // Handle address update or clearing
                if let address = planManager.address {
                    if let existingAddress = existingByABN.address {
                        existingAddress.update(from: address)
                    } else {
                        let addressEntity = AddressEntity()
                        addressEntity.update(from: address)
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
                return PlanManager(from: existingByABN)
            }
            
            // Create new entity
            let entity = PlanManagerEntity(id: planManager.id, abn: planManager.abn)
            entity.update(from: planManager)
            
            // Insert entity first before assigning relationships
            // This ensures entity is registered and prevents duplicate insertion
            if entity.modelContext == nil {
                modelContext.insert(entity)
            }
            
            // Handle address if provided
            if let address = planManager.address {
                let addressEntity = AddressEntity()
                addressEntity.update(from: address)
                // Insert address before assigning to relationship
                if addressEntity.modelContext == nil {
                    modelContext.insert(addressEntity)
                }
                // Now assign relationship (entity is already registered)
                entity.address = addressEntity
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
            return PlanManager(from: entity)
        }
    }
    
    public func update(_ planManager: PlanManager) async throws -> PlanManager {
        return try await MainActor.run {
            let predicate = #Predicate<PlanManagerEntity> { m in m.id == planManager.id }
            let descriptor = FetchDescriptor<PlanManagerEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            entity.update(from: planManager)
            
            // Handle address update or clearing
            if let address = planManager.address {
                if let existingAddress = entity.address {
                    // Update existing address using domain model
                    existingAddress.update(from: address)
                } else {
                    // Create new address
                    let addressEntity = AddressEntity()
                    addressEntity.update(from: address)
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
            return PlanManager(from: entity)
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
            return entities.map { PlanManager(from: $0) }
        }
    }
    
    public func count() async throws -> Int {
        let descriptor = FetchDescriptor<PlanManagerEntity>()
        return try await MainActor.run {
            try modelContext.fetchCount(descriptor)
        }
    }
    
    // MARK: - Private Helpers
    // Note: fetchEntity and fetchEntityByABN helpers removed - all entity operations now happen directly within MainActor.run blocks
    // to avoid Sendable conformance issues with PlanManagerEntity
}

