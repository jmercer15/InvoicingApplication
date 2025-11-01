import Foundation

/// Protocol for session data operations
public protocol SessionsRepository: Sendable {
    /// Fetch all sessions
    func fetchAll() async throws -> [Session]
    
    /// Fetch sessions by date range
    func fetch(from startDate: Date, to endDate: Date) async throws -> [Session]
    
    /// Fetch sessions by client ID
    func fetch(byClientId clientId: UUID) async throws -> [Session]
    
    /// Fetch sessions by status
    func fetch(byStatus status: String) async throws -> [Session]
    
    /// Fetch sessions by billing status
    func fetch(byBillingStatus billingStatus: BillingStatus) async throws -> [Session]
    
    /// Fetch sessions by group ID
    func fetch(byGroupId groupId: UUID) async throws -> [Session]
    
    /// Fetch a single session by ID
    func fetch(byId id: UUID) async throws -> Session?
    
    /// Create a new session
    func create(_ session: Session) async throws -> Session
    
    /// Update an existing session
    func update(_ session: Session) async throws -> Session
    
    /// Delete a session
    func delete(id: UUID) async throws
    
    /// Update session status
    func updateStatus(id: UUID, status: String) async throws
    
    /// Update session billing status
    func updateBillingStatus(id: UUID, status: BillingStatus) async throws
    
    /// Group sessions together
    func groupSessions(_ sessionIds: [UUID], groupId: UUID) async throws
    
    /// Ungroup sessions
    func ungroupSessions(_ sessionIds: [UUID]) async throws
    
    /// Update grouped position for a session
    func updateGroupedPosition(id: UUID, position: Int32) async throws
    
    /// Reorder sessions within a group
    func reorderSessions(_ sessionIds: [UUID], in groupId: UUID?) async throws
    
    /// Search sessions by query
    func search(query: String) async throws -> [Session]
    
    /// Fetch sessions with pagination
    func fetch(limit: Int, offset: Int) async throws -> [Session]
    
    /// Count total sessions
    func count() async throws -> Int
    
    /// Count sessions by status
    func count(by status: String) async throws -> Int
}
