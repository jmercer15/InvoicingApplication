import Foundation
import SwiftData
import Core

/// SwiftData implementation of AddressRepository
public final class AddressRepositorySwiftData: AddressRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    private let mapper: AddressMapper
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.mapper = AddressMapper()
    }
    
    public func fetch(by id: UUID) async throws -> Address? {
        let predicate = #Predicate<AddressEntity> { address in
            address.id == id
        }
        let descriptor = FetchDescriptor<AddressEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return mapper.mapToDomain(entity)
        }
    }
    
    public func create(_ address: Address) async throws -> Address {
        return try await MainActor.run {
            var entity = AddressEntity()
            mapper.updateEntity(&entity, from: address)
            if entity.modelContext == nil {
                modelContext.insert(entity)
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
    
    public func update(_ address: Address) async throws -> Address {
        let predicate = #Predicate<AddressEntity> { addr in
            addr.id == address.id
        }
        let descriptor = FetchDescriptor<AddressEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            var mutableEntity = entity
            mapper.updateEntity(&mutableEntity, from: address)
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
        let predicate = #Predicate<AddressEntity> { address in
            address.id == id
        }
        let descriptor = FetchDescriptor<AddressEntity>(predicate: predicate)
        try await MainActor.run {
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
}
