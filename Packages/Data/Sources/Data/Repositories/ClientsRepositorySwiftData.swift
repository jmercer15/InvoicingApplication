import Foundation
import SwiftData
import Core

/// SwiftData implementation of ClientsRepository
public final class ClientsRepositorySwiftData: ClientsRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    public func fetchAll() async throws -> [Client] {
        let descriptor = FetchDescriptor<ClientEntity>(
            sortBy: [SortDescriptor(\.fullName, order: .forward)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Client(from: $0) }
    }
    
    public func fetchActive() async throws -> [Client] {
        let predicate = #Predicate<ClientEntity> { client in
            client.status.rawValue == "Active"
        }
        let descriptor = FetchDescriptor<ClientEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.fullName, order: .forward)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Client(from: $0) }
    }
    
    public func fetch(by id: UUID) async throws -> Client? {
        let predicate = #Predicate<ClientEntity> { client in
            client.id == id
        }
        let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return Client(from: entity)
    }
    
    public func fetch(by ndisNumber: String) async throws -> Client? {
        let predicate = #Predicate<ClientEntity> { client in
            client.ndisNumber == ndisNumber
        }
        let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return Client(from: entity)
    }
    
    public func create(_ client: Client) async throws -> Client {
        let entity = ClientEntity(
            id: client.id,
            ndisNumber: client.ndisNumber,
            fullName: client.fullName,
            status: ClientStatus(rawValue: client.status) ?? .active,
            // colorHex property removed - no longer supported
        )
        entity.update(from: client)
        modelContext.insert(entity)
        try modelContext.save()
        return Client(from: entity)
    }
    
    public func update(_ client: Client) async throws -> Client {
        guard let entity = try await fetchEntity(by: client.id) else {
            throw RepositoryError.entityNotFound
        }
        entity.update(from: client)
        try modelContext.save()
        return Client(from: entity)
    }
    
    public func delete(id: UUID) async throws {
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        modelContext.delete(entity)
        try modelContext.save()
    }
    
    public func archive(id: UUID) async throws {
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        entity.status = .archived
        try modelContext.save()
    }
    
    public func reactivate(id: UUID) async throws {
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        entity.status = .active
        try modelContext.save()
    }
    
    public func updateStatus(id: UUID, status: String) async throws {
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        entity.status = ClientStatus(rawValue: status) ?? .active
        try modelContext.save()
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
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Client(from: $0) }
    }
    
    public func fetch(limit: Int, offset: Int) async throws -> [Client] {
        var descriptor = FetchDescriptor<ClientEntity>(
            sortBy: [SortDescriptor(\.fullName, order: .forward)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Client(from: $0) }
    }
    
    public func count() async throws -> Int {
        let descriptor = FetchDescriptor<ClientEntity>()
        return try modelContext.fetchCount(descriptor)
    }
    
    public func countActive() async throws -> Int {
        let predicate = #Predicate<ClientEntity> { client in
            client.status.rawValue == "Active"
        }
        let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
        return try modelContext.fetchCount(descriptor)
    }
    
    // MARK: - Private Helpers
    
    private func fetchEntity(by id: UUID) async throws -> ClientEntity? {
        let predicate = #Predicate<ClientEntity> { client in
            client.id == id
        }
        let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
}
