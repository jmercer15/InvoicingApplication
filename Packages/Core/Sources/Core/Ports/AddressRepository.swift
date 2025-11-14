import Foundation

/// Protocol for address data operations
public protocol AddressRepository: Sendable {
    /// Fetch address by ID
    func fetch(by id: UUID) async throws -> Address?
    
    /// Create a new address
    func create(_ address: Address) async throws -> Address
    
    /// Update an existing address
    func update(_ address: Address) async throws -> Address
    
    /// Delete an address
    func delete(id: UUID) async throws
}
