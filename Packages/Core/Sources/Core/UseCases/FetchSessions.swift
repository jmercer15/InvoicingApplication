import Foundation

/// Use case for fetching sessions
public struct FetchSessions: Sendable {
    private let repository: SessionsRepository
    
    public init(repository: SessionsRepository) {
        self.repository = repository
    }
    
    /// Fetch all sessions
    public func callAsFunction() async throws -> [Session] {
        try await repository.fetchAll()
    }
    
    /// Fetch sessions by date range
    public func callAsFunction(from startDate: Date, to endDate: Date) async throws -> [Session] {
        try await repository.fetch(from: startDate, to: endDate)
    }
    
    /// Fetch sessions by client ID
    public func callAsFunction(byClientId clientId: UUID) async throws -> [Session] {
        try await repository.fetch(byClientId: clientId)
    }
    
    /// Fetch sessions by status
    public func callAsFunction(byStatus status: String) async throws -> [Session] {
        try await repository.fetch(byStatus: status)
    }
    
    /// Fetch sessions by billing status
    public func callAsFunction(byBillingStatus billingStatus: BillingStatus) async throws -> [Session] {
        try await repository.fetch(byBillingStatus: billingStatus)
    }
    
    /// Fetch sessions by group ID
    public func callAsFunction(byGroupId groupId: UUID) async throws -> [Session] {
        try await repository.fetch(byGroupId: groupId)
    }
    
    /// Fetch a single session by ID
    public func callAsFunction(byId id: UUID) async throws -> Session? {
        try await repository.fetch(byId: id)
    }
    
    /// Search sessions by query
    public func callAsFunction(search query: String) async throws -> [Session] {
        try await repository.search(query: query)
    }
    
    /// Fetch sessions with pagination
    public func callAsFunction(limit: Int, offset: Int) async throws -> [Session] {
        try await repository.fetch(limit: limit, offset: offset)
    }
}
