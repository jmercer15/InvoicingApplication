import Foundation
import SwiftData
import Core

/// SwiftData implementation of TravelChargeRepository
public final class TravelChargeRepositorySwiftData: TravelChargeRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    private let mapper: TravelChargeMapper
    
    public init(modelContext: ModelContext, mapper: TravelChargeMapper = TravelChargeMapper()) {
        self.modelContext = modelContext
        self.mapper = mapper
    }
    
    public func fetchAll() async throws -> [TravelCharge] {
        let descriptor = FetchDescriptor<TravelChargeEntity>(
            sortBy: [SortDescriptor(\.ekCreationDate, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetchBySessionId(_ sessionId: UUID) async throws -> [TravelCharge] {
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.linkedSession?.id == sessionId
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.ekCreationDate, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetchByClientId(_ clientId: UUID) async throws -> [TravelCharge] {
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.client?.id == clientId
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.ekCreationDate, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetchByStatus(_ status: TravelChargeStatus) async throws -> [TravelCharge] {
        let statusString = status.rawValue
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.notes?.contains("Status: \(statusString)") == true
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.ekCreationDate, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetchById(_ id: UUID) async throws -> TravelCharge? {
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.id == id
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return self.mapper.mapToDomain(entity)
        }
    }
    
    public func create(_ travelCharge: TravelCharge) async throws -> TravelCharge {
        return try await MainActor.run {
            var entity = TravelChargeEntity(id: travelCharge.id)
            self.mapper.updateEntity(&entity, from: travelCharge)
            
            // Resolve relationships using IDs from domain model
            let clientPredicate = #Predicate<ClientEntity> { $0.id == travelCharge.clientId }
            let clientDescriptor = FetchDescriptor<ClientEntity>(predicate: clientPredicate)
            if let client = try modelContext.fetch(clientDescriptor).first {
                entity.client = client
            } else {
                print("TravelChargeRepository: Client not found for ID \(travelCharge.clientId)")
            }
            
            let sessionPredicate = #Predicate<SessionEntity> { $0.id == travelCharge.sessionId }
            let sessionDescriptor = FetchDescriptor<SessionEntity>(predicate: sessionPredicate)
            if let session = try modelContext.fetch(sessionDescriptor).first {
                entity.linkedSession = session
            } else {
                print("TravelChargeRepository: Session not found for ID \(travelCharge.sessionId)")
            }
            
            if let serviceId = travelCharge.serviceId {
                let servicePredicate = #Predicate<ClientServiceEntity> { $0.id == serviceId }
                let serviceDescriptor = FetchDescriptor<ClientServiceEntity>(predicate: servicePredicate)
                if let service = try modelContext.fetch(serviceDescriptor).first {
                    entity.service = service
                }
            }
            
            if entity.modelContext == nil {
                modelContext.insert(entity)
            }
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            return self.mapper.mapToDomain(entity)
        }
    }
    
    public func update(_ travelCharge: TravelCharge) async throws -> TravelCharge {
        return try await MainActor.run {
            let predicate = #Predicate<TravelChargeEntity> { $0.id == travelCharge.id }
            let descriptor = FetchDescriptor<TravelChargeEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            var mutableEntity = entity
            self.mapper.updateEntity(&mutableEntity, from: travelCharge)
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            return self.mapper.mapToDomain(entity)
        }
    }
    
    public func delete(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<TravelChargeEntity> { $0.id == id }
            let descriptor = FetchDescriptor<TravelChargeEntity>(predicate: predicate)
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
    
    public func updateStatus(id: UUID, status: TravelChargeStatus) async throws {
        try await MainActor.run {
            let predicate = #Predicate<TravelChargeEntity> { $0.id == id }
            let descriptor = FetchDescriptor<TravelChargeEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            
            // Update status in notes field (temporary until entity is updated with proper status field)
            let statusNote = "Status: \(status.rawValue)"
            if let existingNotes = entity.notes, !existingNotes.contains("Status:") {
                entity.notes = "\(existingNotes)\n\(statusNote)"
            } else if entity.notes == nil {
                entity.notes = statusNote
            }
            
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
        }
    }
    
    public func search(query: String) async throws -> [TravelCharge] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.notes?.localizedStandardContains(trimmedQuery) == true ||
            travelCharge.location?.localizedStandardContains(trimmedQuery) == true ||
            travelCharge.title.localizedStandardContains(trimmedQuery) == true
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.ekCreationDate, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetch(limit: Int, offset: Int) async throws -> [TravelCharge] {
        var descriptor = FetchDescriptor<TravelChargeEntity>(
            sortBy: [SortDescriptor(\.ekCreationDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func count() async throws -> Int {
        let descriptor = FetchDescriptor<TravelChargeEntity>()
        return try await MainActor.run {
            try modelContext.fetchCount(descriptor)
        }
    }
    
    public func count(by status: TravelChargeStatus) async throws -> Int {
        let statusString = status.rawValue
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.notes?.contains("Status: \(statusString)") == true
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(predicate: predicate)
        return try await MainActor.run {
            try modelContext.fetchCount(descriptor)
        }
    }
    
    public func fetch(from startDate: Date, to endDate: Date) async throws -> [TravelCharge] {
        // Note: SwiftData predicates don't support forced unwrapping (!)
        // We fetch with a simpler predicate and filter in memory
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.ekCreationDate != nil
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.ekCreationDate, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            // Filter in memory to avoid forced unwrap in predicate
            let filteredEntities = entities.filter { entity in
                guard let creationDate = entity.ekCreationDate else { return false }
                return creationDate >= startDate && creationDate <= endDate
            }
            return filteredEntities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetchRequiringReview() async throws -> [TravelCharge] {
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.notes?.contains("Status: pending") == true
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.ekCreationDate, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func approve(id: UUID) async throws -> TravelCharge {
        try await updateStatus(id: id, status: .approved)
        guard let travelCharge = try await fetchById(id) else {
            throw RepositoryError.entityNotFound
        }
        return travelCharge
    }
    
    public func reject(id: UUID, reason: String?) async throws -> TravelCharge {
        try await updateStatus(id: id, status: .rejected)
        
        // Add rejection reason to notes if provided
        if let reason = reason {
            try await MainActor.run {
                let predicate = #Predicate<TravelChargeEntity> { $0.id == id }
                let descriptor = FetchDescriptor<TravelChargeEntity>(predicate: predicate)
                guard let entity = try modelContext.fetch(descriptor).first else {
                    throw RepositoryError.entityNotFound
                }
                let rejectionNote = "Rejection Reason: \(reason)"
                if let existingNotes = entity.notes {
                    entity.notes = "\(existingNotes)\n\(rejectionNote)"
                } else {
                    entity.notes = rejectionNote
                }
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    throw RepositoryError.saveFailed
                }
            }
        }
        
        guard let travelCharge = try await fetchById(id) else {
            throw RepositoryError.entityNotFound
        }
        return travelCharge
    }
    
    // MARK: - Private Helpers
}
