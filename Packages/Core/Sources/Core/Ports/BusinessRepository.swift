import Foundation

/// Protocol for business data operations
public protocol BusinessRepository: Sendable {
    /// Fetch business by ID
    func fetch(by id: UUID) async throws -> Business?
    
    /// Fetch the primary business profile (usually the first one found)
    func fetchFirst() async throws -> Business?
    
    /// Update business profile
    @discardableResult
    func update(_ business: Business) async throws -> Business
}

// MARK: - Type Alias for Naming Consistency

/// Type alias for consistent naming convention across repository protocols.
public typealias BusinessRepositoryProtocol = BusinessRepository
