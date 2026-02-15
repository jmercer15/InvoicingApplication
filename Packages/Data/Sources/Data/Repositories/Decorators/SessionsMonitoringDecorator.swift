import Foundation
import Core
import os.log

/// A protocol-based decorator that wraps SessionsRepository to add performance monitoring.
/// Uses the decorator pattern to add logging/metrics without modifying the underlying implementation.
public final class SessionsMonitoringDecorator: SessionsRepository, @unchecked Sendable {
    private let wrapped: any SessionsRepository
    private let logger: Logger
    
    public init(wrapped: any SessionsRepository, subsystem: String = "InvoicingApplication") {
        self.wrapped = wrapped
        self.logger = Logger(subsystem: subsystem, category: "SessionsRepository.Performance")
    }
    
    // MARK: - Monitoring Helpers
    
    private func measure<T>(_ operation: String, _ block: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
            logger.info("[\(operation)] completed in \(duration, format: .fixed(precision: 2))ms")
        }
        return try await block()
    }
    
    // MARK: - SessionsRepository Protocol
    
    public func fetchAll() async throws -> [Session] {
        try await measure("fetchAll") {
            try await wrapped.fetchAll()
        }
    }
    
    public func fetch(from startDate: Date, to endDate: Date) async throws -> [Session] {
        try await measure("fetch(dateRange)") {
            try await wrapped.fetch(from: startDate, to: endDate)
        }
    }
    
    public func fetch(byClientId clientId: UUID) async throws -> [Session] {
        try await measure("fetch(byClientId)") {
            try await wrapped.fetch(byClientId: clientId)
        }
    }
    
    public func fetch(byStatus status: String) async throws -> [Session] {
        try await measure("fetch(byStatus)") {
            try await wrapped.fetch(byStatus: status)
        }
    }
    
    public func fetch(byBillingStatus billingStatus: BillingStatus) async throws -> [Session] {
        try await measure("fetch(byBillingStatus)") {
            try await wrapped.fetch(byBillingStatus: billingStatus)
        }
    }
    
    public func fetch(byGroupId groupId: UUID) async throws -> [Session] {
        try await measure("fetch(byGroupId)") {
            try await wrapped.fetch(byGroupId: groupId)
        }
    }
    
    public func fetch(byId id: UUID) async throws -> Session? {
        try await measure("fetch(byId)") {
            try await wrapped.fetch(byId: id)
        }
    }
    
    public func create(_ session: Session) async throws -> Session {
        try await measure("create") {
            try await wrapped.create(session)
        }
    }
    
    public func update(_ session: Session) async throws -> Session {
        try await measure("update") {
            try await wrapped.update(session)
        }
    }
    
    public func delete(id: UUID) async throws {
        try await measure("delete") {
            try await wrapped.delete(id: id)
        }
    }
    
    public func updateStatus(id: UUID, status: String) async throws {
        try await measure("updateStatus") {
            try await wrapped.updateStatus(id: id, status: status)
        }
    }
    
    public func updateBillingStatus(id: UUID, status: BillingStatus) async throws {
        try await measure("updateBillingStatus") {
            try await wrapped.updateBillingStatus(id: id, status: status)
        }
    }
    
    public func groupSessions(_ sessionIds: [UUID], groupId: UUID) async throws {
        try await measure("groupSessions") {
            try await wrapped.groupSessions(sessionIds, groupId: groupId)
        }
    }
    
    public func ungroupSessions(_ sessionIds: [UUID]) async throws {
        try await measure("ungroupSessions") {
            try await wrapped.ungroupSessions(sessionIds)
        }
    }
    
    public func updateGroupedPosition(id: UUID, position: Int32) async throws {
        try await measure("updateGroupedPosition") {
            try await wrapped.updateGroupedPosition(id: id, position: position)
        }
    }
    
    public func reorderSessions(_ sessionIds: [UUID], in groupId: UUID?) async throws {
        try await measure("reorderSessions") {
            try await wrapped.reorderSessions(sessionIds, in: groupId)
        }
    }
    
    public func search(query: String) async throws -> [Session] {
        try await measure("search") {
            try await wrapped.search(query: query)
        }
    }
    
    public func fetch(limit: Int, offset: Int) async throws -> [Session] {
        try await measure("fetch(paginated)") {
            try await wrapped.fetch(limit: limit, offset: offset)
        }
    }
    
    public func count() async throws -> Int {
        try await measure("count") {
            try await wrapped.count()
        }
    }
    
    public func count(by status: String) async throws -> Int {
        try await measure("count(byStatus)") {
            try await wrapped.count(by: status)
        }
    }
    
    public func fetch(byEventIdentifier eventIdentifier: String) async throws -> Session? {
        try await measure("fetch(byEventIdentifier)") {
            try await wrapped.fetch(byEventIdentifier: eventIdentifier)
        }
    }
    
    public func fetch(byDerivedFromEKEventID derivedId: String) async throws -> [Session] {
        try await measure("fetch(byDerivedFromEKEventID)") {
            try await wrapped.fetch(byDerivedFromEKEventID: derivedId)
        }
    }
}
