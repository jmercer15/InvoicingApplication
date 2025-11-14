import Foundation
import SwiftData
import Core

/// SwiftData implementation of PayeeRepository
public final class PayeeRepositorySwiftData: PayeeRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    public func fetchAll() async throws -> [Payee] {
        let descriptor = FetchDescriptor<PayeeEntity>(
            sortBy: [SortDescriptor(\.fullName, order: .forward)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Payee(from: $0) }
        }
    }
    
    public func fetch(by id: UUID) async throws -> Payee? {
        let predicate = #Predicate<PayeeEntity> { payee in
            payee.id == id
        }
        let descriptor = FetchDescriptor<PayeeEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return Payee(from: entity)
        }
    }
    
    public func create(_ payee: Payee) async throws -> Payee {
        return try await MainActor.run {
            // Check if entity already exists with this ID
            let predicate = #Predicate<PayeeEntity> { p in p.id == payee.id }
            let descriptor = FetchDescriptor<PayeeEntity>(predicate: predicate)
            if let existingEntity = try? modelContext.fetch(descriptor).first {
                // Entity already exists, update it instead
                existingEntity.update(from: payee)
                
                // Handle address update or clearing
                if let address = payee.address {
                    if let existingAddress = existingEntity.address {
                        existingAddress.update(from: address)
                    } else {
                        let addressEntity = AddressEntity()
                        addressEntity.update(from: address)
                        // Only insert address if not already tracked
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
                return Payee(from: existingEntity)
            }
            
            // Create new entity
            let entity = PayeeEntity(id: payee.id, fullName: payee.fullName)
            entity.update(from: payee)
            
            // Insert entity first before assigning relationships
            // This ensures entity is registered and prevents duplicate insertion
            if entity.modelContext == nil {
                modelContext.insert(entity)
            }
            
            // Handle address if provided
            if let address = payee.address {
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
            return Payee(from: entity)
        }
    }
    
    public func update(_ payee: Payee) async throws -> Payee {
        return try await MainActor.run {
            let predicate = #Predicate<PayeeEntity> { p in p.id == payee.id }
            let descriptor = FetchDescriptor<PayeeEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            entity.update(from: payee)
            
            // Handle address update or clearing
            if let address = payee.address {
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
            return Payee(from: entity)
        }
    }
    
    public func delete(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<PayeeEntity> { p in p.id == id }
            let descriptor = FetchDescriptor<PayeeEntity>(predicate: predicate)
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
    
    public func search(query: String) async throws -> [Payee] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        let predicate = #Predicate<PayeeEntity> { payee in
            payee.fullName.localizedStandardContains(trimmedQuery) ||
            payee.email?.localizedStandardContains(trimmedQuery) == true ||
            payee.phone?.localizedStandardContains(trimmedQuery) == true
        }
        let descriptor = FetchDescriptor<PayeeEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.fullName, order: .forward)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Payee(from: $0) }
        }
    }
    
    public func count() async throws -> Int {
        let descriptor = FetchDescriptor<PayeeEntity>()
        return try await MainActor.run {
            try modelContext.fetchCount(descriptor)
        }
    }
    
    // MARK: - Private Helpers
    // Note: fetchEntity helper removed - all entity operations now happen directly within MainActor.run blocks
    // to avoid Sendable conformance issues with PayeeEntity
}

