import Foundation
import SwiftData
import Core

/// SwiftData implementation of TravelChargeReviewRepository
public final class TravelChargeReviewRepositorySwiftData: TravelChargeReviewRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    private let mapper: TravelChargeReviewMapper
    
    public init(modelContext: ModelContext, mapper: TravelChargeReviewMapper = TravelChargeReviewMapper()) {
        self.modelContext = modelContext
        self.mapper = mapper
    }
    
    public func fetchAll() async throws -> [Core.TravelChargeReviewItem] {
        let descriptor = FetchDescriptor<TravelChargeReviewItemEntity>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetchBySessionId(_ sessionId: UUID) async throws -> [Core.TravelChargeReviewItem] {
        let predicate = #Predicate<TravelChargeReviewItemEntity> { item in
            item.session?.id == sessionId
        }
        let descriptor = FetchDescriptor<TravelChargeReviewItemEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetchByStatus(_ status: String) async throws -> [Core.TravelChargeReviewItem] {
        let predicate = #Predicate<TravelChargeReviewItemEntity> { item in
            item.status == status
        }
        let descriptor = FetchDescriptor<TravelChargeReviewItemEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.mapper.mapToDomain($0) }
        }
    }
    
    public func fetchById(_ id: UUID) async throws -> Core.TravelChargeReviewItem? {
        let predicate = #Predicate<TravelChargeReviewItemEntity> { $0.id == id }
        let descriptor = FetchDescriptor<TravelChargeReviewItemEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil as Core.TravelChargeReviewItem? }
            return self.mapper.mapToDomain(entity)
        }
    }
    
    public func create(_ reviewItem: Core.TravelChargeReviewItem) async throws -> Core.TravelChargeReviewItem {
        return try await MainActor.run {
            var entity = TravelChargeReviewItemEntity(id: reviewItem.id)
            self.mapper.updateEntity(&entity, from: reviewItem)
            
            // Resolve session relationship
            if let sessionId = reviewItem.sessionId {
                let sessionPredicate = #Predicate<SessionEntity> { $0.id == sessionId }
                let sessionDescriptor = FetchDescriptor<SessionEntity>(predicate: sessionPredicate)
                if let session = try modelContext.fetch(sessionDescriptor).first {
                    entity.session = session
                }
            }
            
            if entity.modelContext == nil {
                modelContext.insert(entity)
            }
            try modelContext.save()
            return self.mapper.mapToDomain(entity)
        }
    }
    
    public func update(_ reviewItem: Core.TravelChargeReviewItem) async throws -> Core.TravelChargeReviewItem {
        return try await MainActor.run {
            let predicate = #Predicate<TravelChargeReviewItemEntity> { $0.id == reviewItem.id }
            let descriptor = FetchDescriptor<TravelChargeReviewItemEntity>(predicate: predicate)
            guard var entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            self.mapper.updateEntity(&entity, from: reviewItem)
            
            // Resolve session relationship if updated
            if let sessionId = reviewItem.sessionId {
                let sessionPredicate = #Predicate<SessionEntity> { $0.id == sessionId }
                let sessionDescriptor = FetchDescriptor<SessionEntity>(predicate: sessionPredicate)
                if let session = try modelContext.fetch(sessionDescriptor).first {
                    entity.session = session
                }
            }
            
            try modelContext.save()
            return self.mapper.mapToDomain(entity)
        }
    }
    
    public func delete(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<TravelChargeReviewItemEntity> { $0.id == id }
            let descriptor = FetchDescriptor<TravelChargeReviewItemEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            modelContext.delete(entity)
            try modelContext.save()
        }
    }
    
    public func resolve(id: UUID, status: String, notes: String?) async throws {
        try await MainActor.run {
            let predicate = #Predicate<TravelChargeReviewItemEntity> { $0.id == id }
            let descriptor = FetchDescriptor<TravelChargeReviewItemEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            entity.status = status
            entity.resolutionNotes = notes
            entity.timestamp = Date()
            try modelContext.save()
        }
    }
}
