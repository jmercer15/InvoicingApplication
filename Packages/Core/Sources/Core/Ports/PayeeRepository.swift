import Foundation

/// Protocol for payee data operations
public protocol PayeeRepository: Sendable {
    /// Fetch all payees
    func fetchAll() async throws -> [Payee]
    
    /// Fetch a single payee by ID
    func fetch(by id: UUID) async throws -> Payee?
    
    /// Create a new payee
    func create(_ payee: Payee) async throws -> Payee
    
    /// Update an existing payee
    func update(_ payee: Payee) async throws -> Payee
    
    /// Delete a payee
    func delete(id: UUID) async throws
    
    /// Search payees by query
    func search(query: String) async throws -> [Payee]
    
    /// Count total payees
    func count() async throws -> Int
}

// MARK: - Type Alias for Naming Consistency

/// Type alias for consistent naming convention across repository protocols.
public typealias PayeeRepositoryProtocol = PayeeRepository
