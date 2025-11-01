import Foundation
import SwiftData
import Core

/// SwiftData implementation of TravelChargeRepository
public final class TravelChargeRepositorySwiftData: TravelChargeRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    public func fetchAll() async throws -> [TravelCharge] {
        let descriptor = FetchDescriptor<TravelChargeEntity>(
            sortBy: [SortDescriptor(\.ekCreationDate, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { TravelCharge(from: $0) }
    }
    
    public func fetchBySessionId(_ sessionId: UUID) async throws -> [TravelCharge] {
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.linkedSession?.id == sessionId
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.ekCreationDate, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { TravelCharge(from: $0) }
    }
    
    public func fetchByClientId(_ clientId: UUID) async throws -> [TravelCharge] {
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.client?.id == clientId
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.ekCreationDate, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { TravelCharge(from: $0) }
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
        let entities = try modelContext.fetch(descriptor)
        return entities.map { TravelCharge(from: $0) }
    }
    
    public func fetchById(_ id: UUID) async throws -> TravelCharge? {
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.id == id
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return TravelCharge(from: entity)
    }
    
    public func create(_ travelCharge: TravelCharge) async throws -> TravelCharge {
        let entity = TravelChargeEntity(id: travelCharge.id)
        entity.update(from: travelCharge)
        modelContext.insert(entity)
        try modelContext.save()
        return TravelCharge(from: entity)
    }
    
    public func update(_ travelCharge: TravelCharge) async throws -> TravelCharge {
        guard let entity = try await fetchEntity(by: travelCharge.id) else {
            throw RepositoryError.entityNotFound
        }
        entity.update(from: travelCharge)
        try modelContext.save()
        return TravelCharge(from: entity)
    }
    
    public func delete(id: UUID) async throws {
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        modelContext.delete(entity)
        try modelContext.save()
    }
    
    public func updateStatus(id: UUID, status: TravelChargeStatus) async throws {
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        
        // Update status in notes field (temporary until entity is updated with proper status field)
        let statusNote = "Status: \(status.rawValue)"
        if let existingNotes = entity.notes, !existingNotes.contains("Status:") {
            entity.notes = "\(existingNotes)\n\(statusNote)"
        } else if entity.notes == nil {
            entity.notes = statusNote
        }
        
        try modelContext.save()
    }
    
    public func search(query: String) async throws -> [TravelCharge] {
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.notes?.localizedStandardContains(query) == true ||
            travelCharge.location?.localizedStandardContains(query) == true ||
            travelCharge.title.localizedStandardContains(query) == true
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.ekCreationDate, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { TravelCharge(from: $0) }
    }
    
    public func fetch(limit: Int, offset: Int) async throws -> [TravelCharge] {
        var descriptor = FetchDescriptor<TravelChargeEntity>(
            sortBy: [SortDescriptor(\.ekCreationDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        
        let entities = try modelContext.fetch(descriptor)
        return entities.map { TravelCharge(from: $0) }
    }
    
    public func count() async throws -> Int {
        let descriptor = FetchDescriptor<TravelChargeEntity>()
        return try modelContext.fetchCount(descriptor)
    }
    
    public func count(by status: TravelChargeStatus) async throws -> Int {
        let statusString = status.rawValue
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.notes?.contains("Status: \(statusString)") == true
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(predicate: predicate)
        return try modelContext.fetchCount(descriptor)
    }
    
    public func fetch(from startDate: Date, to endDate: Date) async throws -> [TravelCharge] {
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.ekCreationDate != nil && 
            travelCharge.ekCreationDate! >= startDate && 
            travelCharge.ekCreationDate! <= endDate
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.ekCreationDate, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { TravelCharge(from: $0) }
    }
    
    public func fetchRequiringReview() async throws -> [TravelCharge] {
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.notes?.contains("Status: pending") == true
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.ekCreationDate, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { TravelCharge(from: $0) }
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
            guard let entity = try await fetchEntity(by: id) else {
                throw RepositoryError.entityNotFound
            }
            let rejectionNote = "Rejection Reason: \(reason)"
            if let existingNotes = entity.notes {
                entity.notes = "\(existingNotes)\n\(rejectionNote)"
            } else {
                entity.notes = rejectionNote
            }
            try modelContext.save()
        }
        
        guard let travelCharge = try await fetchById(id) else {
            throw RepositoryError.entityNotFound
        }
        return travelCharge
    }
    
    // MARK: - Private Helpers
    
    private func fetchEntity(by id: UUID) async throws -> TravelChargeEntity? {
        let predicate = #Predicate<TravelChargeEntity> { travelCharge in
            travelCharge.id == id
        }
        let descriptor = FetchDescriptor<TravelChargeEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
}
