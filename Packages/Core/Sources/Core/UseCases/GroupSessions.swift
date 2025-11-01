import Foundation

/// Use case for grouping sessions
public struct GroupSessions: Sendable {
    private let repository: SessionsRepository
    
    public init(repository: SessionsRepository) {
        self.repository = repository
    }
    
    /// Group sessions together
    public func callAsFunction(_ sessionIds: [UUID]) async throws {
        guard !sessionIds.isEmpty else { return }
        
        let groupId = UUID()
        try await repository.groupSessions(sessionIds, groupId: groupId)
    }
    
    /// Group sessions with existing group
    public func callAsFunction(_ sessionIds: [UUID], with groupId: UUID) async throws {
        guard !sessionIds.isEmpty else { return }
        
        try await repository.groupSessions(sessionIds, groupId: groupId)
    }
    
    /// Ungroup sessions
    public func callAsFunction(ungroup sessionIds: [UUID]) async throws {
        guard !sessionIds.isEmpty else { return }
        
        try await repository.ungroupSessions(sessionIds)
    }
    
    /// Reorder sessions within a group
    public func callAsFunction(reorder sessionIds: [UUID], in groupId: UUID?) async throws {
        guard !sessionIds.isEmpty else { return }
        
        try await repository.reorderSessions(sessionIds, in: groupId)
    }
    
    /// Update grouped position for a session
    public func callAsFunction(updatePosition sessionId: UUID, to position: Int32) async throws {
        try await repository.updateGroupedPosition(id: sessionId, position: position)
    }
}
