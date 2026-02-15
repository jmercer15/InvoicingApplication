import Foundation

/// Protocol for travel charge review item data operations
public protocol TravelChargeReviewRepository: Sendable {
    /// Fetch all review items
    func fetchAll() async throws -> [TravelChargeReviewItem]
    
    /// Fetch review items by session ID
    func fetchBySessionId(_ sessionId: UUID) async throws -> [TravelChargeReviewItem]
    
    /// Fetch review items by status
    func fetchByStatus(_ status: String) async throws -> [TravelChargeReviewItem]
    
    /// Fetch a single review item by ID
    func fetchById(_ id: UUID) async throws -> TravelChargeReviewItem?
    
    /// Create a new review item
    func create(_ reviewItem: TravelChargeReviewItem) async throws -> TravelChargeReviewItem
    
    /// Update an existing review item
    func update(_ reviewItem: TravelChargeReviewItem) async throws -> TravelChargeReviewItem
    
    /// Delete a review item
    func delete(id: UUID) async throws
    
    /// Resolve a review item
    func resolve(id: UUID, status: String, notes: String?) async throws
}

/// Type alias for naming consistency
public typealias TravelChargeReviewRepositoryProtocol = TravelChargeReviewRepository
