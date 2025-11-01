import Foundation

/// Use case for creating or updating sessions
public struct CreateOrUpdateSession: Sendable {
    private let repository: SessionsRepository
    private let syncService: SyncService
    
    public init(repository: SessionsRepository, syncService: SyncService) {
        self.repository = repository
        self.syncService = syncService
    }
    
    /// Create a new session
    public func create(_ session: Session) async throws -> Session {
        let createdSession = try await repository.create(session)
        
        // Sync to calendar if enabled
        if syncService.syncEnabled && syncService.accessGranted {
            try await syncService.sync(session: createdSession)
        }
        
        return createdSession
    }
    
    /// Update an existing session
    public func update(_ session: Session) async throws -> Session {
        let updatedSession = try await repository.update(session)
        
        // Sync to calendar if enabled
        if syncService.syncEnabled && syncService.accessGranted {
            try await syncService.update(session: updatedSession)
        }
        
        return updatedSession
    }
    
    /// Delete a session
    public func callAsFunction(id: UUID) async throws {
        // Get session first to check if it has calendar sync
        if let session = try await repository.fetch(byId: id) {
            // Remove from calendar if it was synced
            if !session.eventIdentifier.isEmpty && syncService.syncEnabled && syncService.accessGranted {
                try await syncService.delete(syncIdentifier: session.eventIdentifier)
            }
        }
        
        try await repository.delete(id: id)
    }
}
