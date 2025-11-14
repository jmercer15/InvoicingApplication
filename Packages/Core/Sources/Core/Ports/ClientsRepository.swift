import Foundation

/// Protocol for client data operations
public protocol ClientsRepository: Sendable {
    /// Fetch all clients
    func fetchAll() async throws -> [Client]
    
    /// Fetch active clients only
    func fetchActive() async throws -> [Client]
    
    /// Fetch a single client by ID
    func fetch(by id: UUID) async throws -> Client?
    
    /// Fetch client by NDIS number
    func fetch(by ndisNumber: String) async throws -> Client?
    
    /// Create a new client
    func create(_ client: Client) async throws -> Client
    
    /// Update an existing client
    func update(_ client: Client) async throws -> Client
    
    /// Delete a client
    func delete(id: UUID) async throws
    
    /// Archive a client
    func archive(id: UUID) async throws
    
    /// Reactivate a client
    func reactivate(id: UUID) async throws
    
    /// Update client status
    func updateStatus(id: UUID, status: String) async throws
    
    /// Search clients by query
    func search(query: String) async throws -> [Client]
    
    /// Fetch clients with pagination
    func fetch(limit: Int, offset: Int) async throws -> [Client]
    
    /// Count total clients
    func count() async throws -> Int
    
    /// Count active clients
    func countActive() async throws -> Int
    
    /// Fetch clients by payee ID
    func fetch(byPayeeId payeeId: UUID) async throws -> [Client]
    
    /// Fetch clients by plan manager ID
    func fetch(byPlanManagerId planManagerId: UUID) async throws -> [Client]
}
