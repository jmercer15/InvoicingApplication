import Foundation
import SwiftData
import Core

/// SwiftData implementation of SessionsRepository
public final class SessionsRepositorySwiftData: SessionsRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    private let mapper: SessionMapper
    
    public init(modelContext: ModelContext, mapper: SessionMapper = SessionMapper()) {
        self.modelContext = modelContext
        self.mapper = mapper
    }
    
    public func fetchAll() async throws -> [Session] {
        let descriptor = FetchDescriptor<SessionEntity>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetch(from startDate: Date, to endDate: Date) async throws -> [Session] {
        // Note: SwiftData predicates don't support forced unwrapping (!)
        // We need to fetch with a simpler predicate and filter in memory
        // Fetch sessions where startTime is not nil and could be in range
        // We use a wider range to catch sessions that might have instances in the desired range
        let extendedStartDate = startDate.addingTimeInterval(-86400 * 365) // One year before
        let extendedEndDate = endDate.addingTimeInterval(86400 * 365) // One year after
        
        let predicate = #Predicate<SessionEntity> { session in
            // Only check that startTime exists - actual date filtering happens in memory
            session.startTime != nil
        }
        let descriptor = FetchDescriptor<SessionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .forward)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            // Filter in memory to avoid forced unwrap in predicate
            let filteredEntities = entities.filter { entity in
                guard let startTime = entity.startTime else { return false }
                return startTime >= startDate && startTime <= endDate
            }
            return filteredEntities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetch(byClientId clientId: UUID) async throws -> [Session] {
        let predicate = #Predicate<SessionEntity> { session in
            session.client?.id == clientId
        }
        let descriptor = FetchDescriptor<SessionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetch(byStatus status: String) async throws -> [Session] {
        guard let normalizedStatus = SessionStatus(normalized: status) else { return [] }
        let predicate = #Predicate<SessionEntity> { session in
            session.status == normalizedStatus
        }
        let descriptor = FetchDescriptor<SessionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
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
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetch(byId id: UUID) async throws -> Session? {
        let predicate = #Predicate<SessionEntity> { session in
            session.id == id
        }
        let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return self.mapper.mapToDomain(entity)
        }
    }
    
    public func create(_ session: Session) async throws -> Session {
        return try await MainActor.run {
            var entity = SessionEntity(id: session.id)
            self.mapper.updateEntity(&entity, from: session)
            try self.applyRelationships(from: session, to: entity)
            if entity.modelContext == nil {
                modelContext.insert(entity)
            }
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            self.notifySessionChanged(session.id)
            return self.mapper.mapToDomain(entity)
        }
    }
    
    public func update(_ session: Session) async throws -> Session {
        return try await MainActor.run {
            let predicate = #Predicate<SessionEntity> { s in s.id == session.id }
            let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
            guard var entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            self.mapper.updateEntity(&entity, from: session)
            try self.applyRelationships(from: session, to: entity)
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            self.notifySessionChanged(session.id)
            return self.mapper.mapToDomain(entity)
        }
    }
    
    public func delete(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<SessionEntity> { s in s.id == id }
            let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            modelContext.delete(entity)
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
        }
    }
    
    public func updateStatus(id: UUID, status: String) async throws {
        guard let normalizedStatus = SessionStatus(normalized: status) else {
            throw RepositoryError.validationFailed(message: "Unsupported session status: \(status)")
        }

        try await MainActor.run {
            let predicate = #Predicate<SessionEntity> { s in s.id == id }
            let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            entity.status = normalizedStatus
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            self.notifySessionChanged(id)
        }
    }
    
    public func updateBillingStatus(id: UUID, status: BillingStatus) async throws {
        try await updateStatus(id: id, status: status.rawValue)
    }
    
    public func groupSessions(_ sessionIds: [UUID], groupId: UUID) async throws {
        try await MainActor.run {
            for (index, sessionId) in sessionIds.enumerated() {
                let predicate = #Predicate<SessionEntity> { s in s.id == sessionId }
                let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
                guard let entity = try modelContext.fetch(descriptor).first else { continue }
                entity.groupID = groupId
                entity.groupedPosition = Int32(index)
            }
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
        }
    }
    
    public func ungroupSessions(_ sessionIds: [UUID]) async throws {
        try await MainActor.run {
            for sessionId in sessionIds {
                let predicate = #Predicate<SessionEntity> { s in s.id == sessionId }
                let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
                guard let entity = try modelContext.fetch(descriptor).first else { continue }
                entity.groupID = nil
                entity.groupedPosition = 0
            }
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            self.notifySessionsRefreshNeeded()
        }
    }
    
    public func updateGroupedPosition(id: UUID, position: Int32) async throws {
        try await MainActor.run {
            let predicate = #Predicate<SessionEntity> { s in s.id == id }
            let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            entity.groupedPosition = position
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
        }
    }
    
    public func reorderSessions(_ sessionIds: [UUID], in groupId: UUID?) async throws {
        try await MainActor.run {
            for (index, sessionId) in sessionIds.enumerated() {
                let predicate = #Predicate<SessionEntity> { s in s.id == sessionId }
                let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
                guard let entity = try modelContext.fetch(descriptor).first else { continue }
                entity.groupID = groupId
                entity.groupedPosition = Int32(index)
            }
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
        }
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
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetch(limit: Int, offset: Int) async throws -> [Session] {
        var descriptor = FetchDescriptor<SessionEntity>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func count() async throws -> Int {
        let descriptor = FetchDescriptor<SessionEntity>()
        return try await MainActor.run {
            try modelContext.fetchCount(descriptor)
        }
    }
    
    public func count(by status: String) async throws -> Int {
        guard let normalizedStatus = SessionStatus(normalized: status) else { return 0 }
        let predicate = #Predicate<SessionEntity> { session in
            session.status == normalizedStatus
        }
        let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
        return try await MainActor.run {
            try modelContext.fetchCount(descriptor)
        }
    }
    
    public func fetch(byEventIdentifier eventIdentifier: String) async throws -> Session? {
        let predicate = #Predicate<SessionEntity> { session in
            session.eventIdentifier == eventIdentifier
        }
        let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return self.mapper.mapToDomain(entity)
        }
    }
    
    public func fetch(byDerivedFromEKEventID derivedId: String) async throws -> [Session] {
        let predicate = #Predicate<SessionEntity> { session in
            session.derivedFromEKEventID == derivedId
        }
        let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    // MARK: - Private Helpers

    private func applyRelationships(from session: Session, to entity: SessionEntity) throws {
        entity.client = try resolveClientEntity(by: session.clientId)
        entity.clientService = try resolveClientServiceEntity(by: session.clientServiceId)
        entity.address = try resolveAddressEntity(by: session.addressId)

        if let clientId = session.clientId,
           let serviceClientId = entity.clientService?.client?.id,
           serviceClientId != clientId {
            throw RepositoryError.validationFailed(
                message: "Selected service does not belong to the selected client."
            )
        }
    }

    private func resolveClientEntity(by id: UUID?) throws -> ClientEntity? {
        guard let id else { return nil }
        let predicate = #Predicate<ClientEntity> { client in
            client.id == id
        }
        let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.validationFailed(message: "Selected client could not be found.")
        }
        return entity
    }

    private func resolveClientServiceEntity(by id: UUID?) throws -> ClientServiceEntity? {
        guard let id else { return nil }
        let predicate = #Predicate<ClientServiceEntity> { service in
            service.id == id
        }
        let descriptor = FetchDescriptor<ClientServiceEntity>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.validationFailed(message: "Selected client service could not be found.")
        }
        return entity
    }

    private func resolveAddressEntity(by id: UUID?) throws -> AddressEntity? {
        guard let id else { return nil }
        let predicate = #Predicate<AddressEntity> { address in
            address.id == id
        }
        let descriptor = FetchDescriptor<AddressEntity>(predicate: predicate)
        // Addresses are optional for sessions; tolerate stale/missing references by clearing the relation.
        return try modelContext.fetch(descriptor).first
    }

    // Note: fetchEntity helper removed - all entity operations now happen directly within MainActor.run blocks
    // to avoid Sendable conformance issues with SessionEntity

    @MainActor
    private func notifySessionChanged(_ id: UUID) {
        SessionChangePublisher.shared.notifyChange(sessionId: id)
    }

    @MainActor
    private func notifySessionsRefreshNeeded() {
        SessionChangePublisher.shared.notifyRefreshNeeded()
    }
}
