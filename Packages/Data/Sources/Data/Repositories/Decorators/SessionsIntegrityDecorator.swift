import Foundation
import Core
import os.log

/// A decorator that enforces data integrity rules for SessionsRepository operations.
public final class SessionsIntegrityDecorator: SessionsRepository, @unchecked Sendable {
    private let wrapped: any SessionsRepository
    private let logger: Logger
    
    public init(wrapped: any SessionsRepository, subsystem: String = "InvoicingApplication") {
        self.wrapped = wrapped
        self.logger = Logger(subsystem: subsystem, category: "SessionsRepository.Integrity")
    }
    
    // MARK: - Validation Helpers
    
    private func validateSession(_ session: Session) throws {
        // Validates that start time is before end time
        if let start = session.startTime, let end = session.endTime {
            guard start <= end else {
                logger.error("Integrity Check Failed: Session \(session.id) has start time after end time")
                throw RepositoryError.validationFailed(message: "Start time must be before end time")
            }
        }
        
        // Ensure client ID is present (implicit in UUID but good to check if optional in future)
        // Additional checks can be added here
    }
    
    // MARK: - SessionsRepository Protocol
    
    public func fetchAll() async throws -> [Session] {
        try await wrapped.fetchAll()
    }
    
    public func fetch(from startDate: Date, to endDate: Date) async throws -> [Session] {
        try await wrapped.fetch(from: startDate, to: endDate)
    }
    
    public func fetch(byClientId clientId: UUID) async throws -> [Session] {
        try await wrapped.fetch(byClientId: clientId)
    }
    
    public func fetch(byStatus status: String) async throws -> [Session] {
        try await wrapped.fetch(byStatus: status)
    }
    
    public func fetch(byBillingStatus billingStatus: BillingStatus) async throws -> [Session] {
        try await wrapped.fetch(byBillingStatus: billingStatus)
    }
    
    public func fetch(byGroupId groupId: UUID) async throws -> [Session] {
        try await wrapped.fetch(byGroupId: groupId)
    }
    
    public func fetch(byId id: UUID) async throws -> Session? {
        try await wrapped.fetch(byId: id)
    }
    
    public func create(_ session: Session) async throws -> Session {
        try validateSession(session)
        return try await wrapped.create(session)
    }
    
    public func update(_ session: Session) async throws -> Session {
        try validateSession(session)
        return try await wrapped.update(session)
    }
    
    public func delete(id: UUID) async throws {
        try await wrapped.delete(id: id)
    }
    
    public func updateStatus(id: UUID, status: String) async throws {
        try await wrapped.updateStatus(id: id, status: status)
    }
    
    public func updateBillingStatus(id: UUID, status: BillingStatus) async throws {
        try await wrapped.updateBillingStatus(id: id, status: status)
    }
    
    public func groupSessions(_ sessionIds: [UUID], groupId: UUID) async throws {
        try await wrapped.groupSessions(sessionIds, groupId: groupId)
    }
    
    public func ungroupSessions(_ sessionIds: [UUID]) async throws {
        try await wrapped.ungroupSessions(sessionIds)
    }
    
    public func updateGroupedPosition(id: UUID, position: Int32) async throws {
        try await wrapped.updateGroupedPosition(id: id, position: position)
    }
    
    public func reorderSessions(_ sessionIds: [UUID], in groupId: UUID?) async throws {
        try await wrapped.reorderSessions(sessionIds, in: groupId)
    }
    
    public func search(query: String) async throws -> [Session] {
        try await wrapped.search(query: query)
    }
    
    public func fetch(limit: Int, offset: Int) async throws -> [Session] {
        try await wrapped.fetch(limit: limit, offset: offset)
    }
    
    public func count() async throws -> Int {
        try await wrapped.count()
    }
    
    public func count(by status: String) async throws -> Int {
        try await wrapped.count(by: status)
    }
    
    public func fetch(byEventIdentifier eventIdentifier: String) async throws -> Session? {
        try await wrapped.fetch(byEventIdentifier: eventIdentifier)
    }
    
    public func fetch(byDerivedFromEKEventID derivedId: String) async throws -> [Session] {
        try await wrapped.fetch(byDerivedFromEKEventID: derivedId)
    }
}
