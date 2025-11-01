import Foundation
import SwiftData
import Core

/// SwiftData implementation of SessionsRepository
public final class SessionsRepositorySwiftData: SessionsRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    public func fetchAll() async throws -> [Session] {
        let descriptor = FetchDescriptor<SessionEntity>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Session(from: $0) }
    }
    
    public func fetch(from startDate: Date, to endDate: Date) async throws -> [Session] {
        let predicate = #Predicate<SessionEntity> { session in
            session.startTime != nil && session.startTime! >= startDate && session.startTime! <= endDate
        }
        let descriptor = FetchDescriptor<SessionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .forward)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Session(from: $0) }
    }
    
    public func fetch(byClientId clientId: UUID) async throws -> [Session] {
        let predicate = #Predicate<SessionEntity> { session in
            session.client?.id == clientId
        }
        let descriptor = FetchDescriptor<SessionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Session(from: $0) }
    }
    
    public func fetch(byStatus status: String) async throws -> [Session] {
        let predicate = #Predicate<SessionEntity> { session in
            session.status?.rawValue == status
        }
        let descriptor = FetchDescriptor<SessionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Session(from: $0) }
    }
    
    public func fetch(byBillingStatus billingStatus: BillingStatus) async throws -> [Session] {
        let statusString = billingStatus.rawValue
        return try await fetch(byStatus: statusString)
    }
    
    public func fetch(byGroupId groupId: UUID) async throws -> [Session] {
        let predicate = #Predicate<SessionEntity> { session in
            session.groupID == groupId
        }
        let descriptor = FetchDescriptor<SessionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.groupedPosition, order: .forward)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Session(from: $0) }
    }
    
    public func fetch(byId id: UUID) async throws -> Session? {
        let predicate = #Predicate<SessionEntity> { session in
            session.id == id
        }
        let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return Session(from: entity)
    }
    
    public func create(_ session: Session) async throws -> Session {
        let entity = SessionEntity(id: session.id)
        entity.update(from: session)
        modelContext.insert(entity)
        try modelContext.save()
        return Session(from: entity)
    }
    
    public func update(_ session: Session) async throws -> Session {
        guard let entity = try await fetchEntity(by: session.id) else {
            throw RepositoryError.entityNotFound
        }
        entity.update(from: session)
        try modelContext.save()
        return Session(from: entity)
    }
    
    public func delete(id: UUID) async throws {
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        modelContext.delete(entity)
        try modelContext.save()
    }
    
    public func updateStatus(id: UUID, status: String) async throws {
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        entity.status = SessionStatus(rawValue: status) ?? .scheduled
        try modelContext.save()
    }
    
    public func updateBillingStatus(id: UUID, status: BillingStatus) async throws {
        try await updateStatus(id: id, status: status.rawValue)
    }
    
    public func groupSessions(_ sessionIds: [UUID], groupId: UUID) async throws {
        for (index, sessionId) in sessionIds.enumerated() {
            guard let entity = try await fetchEntity(by: sessionId) else { continue }
            entity.groupID = groupId
            entity.groupedPosition = Int32(index)
        }
        try modelContext.save()
    }
    
    public func ungroupSessions(_ sessionIds: [UUID]) async throws {
        for sessionId in sessionIds {
            guard let entity = try await fetchEntity(by: sessionId) else { continue }
            entity.groupID = nil
            entity.groupedPosition = 0
        }
        try modelContext.save()
    }
    
    public func updateGroupedPosition(id: UUID, position: Int32) async throws {
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        entity.groupedPosition = position
        try modelContext.save()
    }
    
    public func reorderSessions(_ sessionIds: [UUID], in groupId: UUID?) async throws {
        for (index, sessionId) in sessionIds.enumerated() {
            guard let entity = try await fetchEntity(by: sessionId) else { continue }
            entity.groupID = groupId
            entity.groupedPosition = Int32(index)
        }
        try modelContext.save()
    }
    
    public func search(query: String) async throws -> [Session] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        let predicate = #Predicate<SessionEntity> { session in
            session.title.localizedStandardContains(trimmedQuery) ||
            session.client?.fullName.localizedStandardContains(trimmedQuery) == true ||
            session.clientService?.serviceName.localizedStandardContains(trimmedQuery) == true
        }
        let descriptor = FetchDescriptor<SessionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Session(from: $0) }
    }
    
    public func fetch(limit: Int, offset: Int) async throws -> [Session] {
        var descriptor = FetchDescriptor<SessionEntity>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Session(from: $0) }
    }
    
    public func count() async throws -> Int {
        let descriptor = FetchDescriptor<SessionEntity>()
        return try modelContext.fetchCount(descriptor)
    }
    
    public func count(by status: String) async throws -> Int {
        let predicate = #Predicate<SessionEntity> { session in
            session.status?.rawValue == status
        }
        let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
        return try modelContext.fetchCount(descriptor)
    }
    
    // MARK: - Private Helpers
    
    private func fetchEntity(by id: UUID) async throws -> SessionEntity? {
        let predicate = #Predicate<SessionEntity> { session in
            session.id == id
        }
        let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
}

/// Repository errors
public enum RepositoryError: Error, LocalizedError {
    case entityNotFound
    case invalidData
    case saveFailed
    
    public var errorDescription: String? {
        switch self {
        case .entityNotFound:
            return "Entity not found"
        case .invalidData:
            return "Invalid data provided"
        case .saveFailed:
            return "Failed to save data"
        }
    }
}
