import Foundation

/// Protocol for travel charge data operations
public protocol TravelChargeRepository: Sendable {
    /// Fetch all travel charges
    func fetchAll() async throws -> [TravelCharge]
    
    /// Fetch travel charges by session ID
    func fetchBySessionId(_ sessionId: UUID) async throws -> [TravelCharge]
    
    /// Fetch travel charges by client ID
    func fetchByClientId(_ clientId: UUID) async throws -> [TravelCharge]
    
    /// Fetch travel charges by status
    func fetchByStatus(_ status: TravelChargeStatus) async throws -> [TravelCharge]
    
    /// Fetch a single travel charge by ID
    func fetchById(_ id: UUID) async throws -> TravelCharge?
    
    /// Create a new travel charge
    func create(_ travelCharge: TravelCharge) async throws -> TravelCharge
    
    /// Update an existing travel charge
    func update(_ travelCharge: TravelCharge) async throws -> TravelCharge
    
    /// Delete a travel charge
    func delete(id: UUID) async throws
    
    /// Update travel charge status
    func updateStatus(id: UUID, status: TravelChargeStatus) async throws
    
    /// Search travel charges by query
    func search(query: String) async throws -> [TravelCharge]
    
    /// Fetch travel charges with pagination
    func fetch(limit: Int, offset: Int) async throws -> [TravelCharge]
    
    /// Count total travel charges
    func count() async throws -> Int
    
    /// Count travel charges by status
    func count(by status: TravelChargeStatus) async throws -> Int
    
    /// Fetch travel charges by date range
    func fetch(from startDate: Date, to endDate: Date) async throws -> [TravelCharge]
    
    /// Fetch travel charges requiring review
    func fetchRequiringReview() async throws -> [TravelCharge]
    
    /// Approve travel charge
    func approve(id: UUID) async throws -> TravelCharge
    
    /// Reject travel charge
    func reject(id: UUID, reason: String?) async throws -> TravelCharge
}

// MARK: - Type Alias for Naming Consistency

/// Type alias for consistent naming convention across repository protocols.
public typealias TravelChargeRepositoryProtocol = TravelChargeRepository
