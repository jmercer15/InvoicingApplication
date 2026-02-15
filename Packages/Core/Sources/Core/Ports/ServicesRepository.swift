import Foundation

/// Protocol for client service data operations
public protocol ClientServicesRepository: Sendable {
    /// Fetch all services assigned to a client
    func fetch(for clientId: UUID) async throws -> [ClientService]
    
    /// Fetch a single client service by ID
    func fetch(by id: UUID) async throws -> ClientService?

    /// Create a new client service assignment
    func create(_ clientService: ClientService) async throws -> ClientService

    /// Update an existing client service assignment
    func update(_ clientService: ClientService) async throws -> ClientService

    /// Delete a client service assignment
    func delete(id: UUID) async throws
}

// MARK: - Type Alias for Naming Consistency

/// Type alias for consistent naming convention across repository protocols.
public typealias ClientServicesRepositoryProtocol = ClientServicesRepository
