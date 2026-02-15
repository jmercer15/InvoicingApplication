import Foundation
import SwiftData
import Core

/// SwiftData implementation of PayeeRepository
public final class PayeeRepositorySwiftData: PayeeRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    
    private let mapper: PayeeMapper
    private let addressMapper: AddressMapper
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.mapper = PayeeMapper()
        self.addressMapper = AddressMapper()
    }
    
    public func fetchAll() async throws -> [Payee] {
        let descriptor = FetchDescriptor<PayeeEntity>(
            sortBy: [SortDescriptor(\.fullName, order: .forward)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { mapper.mapToDomain($0) }
        }
    }
    
    public func fetch(by id: UUID) async throws -> Payee? {
        let predicate = #Predicate<PayeeEntity> { payee in
            payee.id == id
        }
        let descriptor = FetchDescriptor<PayeeEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return mapper.mapToDomain(entity)
        }
    }
    
    public func create(_ payee: Payee) async throws -> Payee {
        return try await MainActor.run {
            // Check if entity already exists with this ID
            let predicate = #Predicate<PayeeEntity> { p in p.id == payee.id }
            let descriptor = FetchDescriptor<PayeeEntity>(predicate: predicate)
            if let existingEntity = try? modelContext.fetch(descriptor).first {
                // Entity already exists, update it instead
                var mutableEntity = existingEntity
                mapper.updateEntity(&mutableEntity, from: payee)
                
                // Handle address update or clearing
                if let address = payee.address {
                    if var existingAddress = existingEntity.address {
                        addressMapper.updateEntity(&existingAddress, from: address)
                    } else {
                        var addressEntity = AddressEntity()
                        addressMapper.updateEntity(&addressEntity, from: address)
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
                return mapper.mapToDomain(existingEntity)
            }
            
            // Create new entity
            var entity = PayeeEntity(id: payee.id, fullName: payee.fullName)
            mapper.updateEntity(&entity, from: payee)
            
            // Insert entity first before assigning relationships
            if entity.modelContext == nil {
                modelContext.insert(entity)
            }
            
            // Handle address if provided
            if let address = payee.address {
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
    
    public func update(_ payee: Payee) async throws -> Payee {
        return try await MainActor.run {
            let predicate = #Predicate<PayeeEntity> { p in p.id == payee.id }
            let descriptor = FetchDescriptor<PayeeEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            var mutableEntity = entity
            mapper.updateEntity(&mutableEntity, from: payee)
            
            // Handle address update or clearing
            if let address = payee.address {
                if var existingAddress = entity.address {
                    addressMapper.updateEntity(&existingAddress, from: address)
                } else {
                    var addressEntity = AddressEntity()
                    addressMapper.updateEntity(&addressEntity, from: address)
                    if addressEntity.modelContext == nil {
                        modelContext.insert(addressEntity)
                    }
                    entity.address = addressEntity
                }
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
            return entities.map { mapper.mapToDomain($0) }
        }
    }
    
    public func count() async throws -> Int {
        let descriptor = FetchDescriptor<PayeeEntity>()
        return try await MainActor.run {
            try modelContext.fetchCount(descriptor)
        }
    }
    
    // MARK: - Private Helpers
}

