import Foundation
import SwiftData
import Core

/// SwiftData implementation of NDISItemRepository
public final class NDISItemRepositorySwiftData: NDISItemRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    private let mapper: NDISItemMapper
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.mapper = NDISItemMapper()
    }
    
    public func fetchAll() async throws -> [NDISItem] {
        try await MainActor.run {
            let descriptor = FetchDescriptor<NDISItemEntity>(
                sortBy: [
                    SortDescriptor(\.itemNumber, order: .forward),
                    SortDescriptor(\.effectiveStartDate, order: .reverse)
                ]
            )
            let entities = try modelContext.fetch(descriptor)
            return entities.map { mapper.mapToDomain($0) }
        }
    }
    
    public func fetchCurrent() async throws -> [NDISItem] {
        try await MainActor.run {
            let predicate = #Predicate<NDISItemEntity> { item in
                item.isCurrent == true
            }
            let descriptor = FetchDescriptor<NDISItemEntity>(
                predicate: predicate,
                sortBy: [
                    SortDescriptor(\.itemNumber, order: .forward),
                    SortDescriptor(\.effectiveStartDate, order: .reverse)
                ]
            )
            let entities = try modelContext.fetch(descriptor)
            return entities.map { mapper.mapToDomain($0) }
        }
    }
    
    public func fetchEffective() async throws -> [NDISItem] {
        // Note: SwiftData predicates don't support forced unwrapping (!)
        // We fetch with a simpler predicate and filter in memory
        let predicate = #Predicate<NDISItemEntity> { item in
            item.isCurrent == true || item.effectiveStartDate != nil || item.effectiveEndDate != nil
        }
        let descriptor = FetchDescriptor<NDISItemEntity>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.itemNumber, order: .forward),
                SortDescriptor(\.effectiveStartDate, order: .reverse)
            ]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            let now = Date()
            // Filter in memory to avoid forced unwrap in predicate
            let filteredEntities = entities.filter { entity in
                if entity.isCurrent { return true }
                let startDate = entity.effectiveStartDate ?? Date.distantPast
                let endDate = entity.effectiveEndDate ?? Date.distantFuture
                return startDate <= now && endDate >= now
            }
            return filteredEntities.map { mapper.mapToDomain($0) }
        }
    }
    
    public func fetch(by id: UUID) async throws -> NDISItem? {
        try await MainActor.run {
            let predicate = #Predicate<NDISItemEntity> { item in
                item.id == id
            }
            let descriptor = FetchDescriptor<NDISItemEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return mapper.mapToDomain(entity)
        }
    }
    
    public func fetch(by itemNumber: String) async throws -> NDISItem? {
        try await MainActor.run {
            let predicate = #Predicate<NDISItemEntity> { item in
                item.itemNumber == itemNumber
            }
            let descriptor = FetchDescriptor<NDISItemEntity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.effectiveStartDate, order: .reverse)]
            )
            // Get the most recent version if multiple exist
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return mapper.mapToDomain(entity)
        }
    }
    
    public func search(query: String) async throws -> [NDISItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        return try await MainActor.run {
            let predicate = #Predicate<NDISItemEntity> { item in
                item.itemNumber.localizedStandardContains(trimmedQuery) ||
                item.name.localizedStandardContains(trimmedQuery) ||
                item.itemDescription?.localizedStandardContains(trimmedQuery) == true
            }
            let descriptor = FetchDescriptor<NDISItemEntity>(
                predicate: predicate,
                sortBy: [
                    SortDescriptor(\.itemNumber, order: .forward),
                    SortDescriptor(\.effectiveStartDate, order: .reverse)
                ]
            )
            let entities = try modelContext.fetch(descriptor)
            return entities.map { mapper.mapToDomain($0) }
        }
    }
    
    public func fetch(by category: String) async throws -> [NDISItem] {
        try await MainActor.run {
            let predicate = #Predicate<NDISItemEntity> { item in
                item.category == category
            }
            let descriptor = FetchDescriptor<NDISItemEntity>(
                predicate: predicate,
                sortBy: [
                    SortDescriptor(\.itemNumber, order: .forward),
                    SortDescriptor(\.effectiveStartDate, order: .reverse)
                ]
            )
            let entities = try modelContext.fetch(descriptor)
            return entities.map { mapper.mapToDomain($0) }
        }
    }
    
    public func count() async throws -> Int {
        try await MainActor.run {
            let descriptor = FetchDescriptor<NDISItemEntity>()
            return try modelContext.fetchCount(descriptor)
        }
    }
    
    public func countCurrent() async throws -> Int {
        try await MainActor.run {
            let predicate = #Predicate<NDISItemEntity> { item in
                item.isCurrent == true
            }
            let descriptor = FetchDescriptor<NDISItemEntity>(predicate: predicate)
            return try modelContext.fetchCount(descriptor)
        }
    }
    
    // MARK: - Maintenance Operations
    
    public func recalculateAllCurrentFlags() async throws -> Int {
        try await MainActor.run {
            // Re-use logic from NDISVersioningService for consistency
            // but keep it encapsulated within the Data layer
            try NDISVersioningService.updateCurrentStatusForAllItems(in: modelContext)
            try modelContext.save()
            
            // Return count of current items for feedback
            let predicate = #Predicate<NDISItemEntity> { item in
                item.isCurrent == true
            }
            let descriptor = FetchDescriptor<NDISItemEntity>(predicate: predicate)
            return try modelContext.fetchCount(descriptor)
        }
    }
    
    public func removeAll() async throws -> (deletedItems: Int, deletedPrices: Int) {
        try await MainActor.run {
            // Count before deletion for reporting
            let itemDescriptor = FetchDescriptor<NDISItemEntity>()
            let priceDescriptor = FetchDescriptor<RegionalPriceEntity>()
            
            let itemCount = try modelContext.fetchCount(itemDescriptor)
            let priceCount = try modelContext.fetchCount(priceDescriptor)
            
            // Perform batch delete
            try modelContext.delete(model: RegionalPriceEntity.self)
            try modelContext.delete(model: NDISItemEntity.self)
            
            try modelContext.save()
            
            return (deletedItems: itemCount, deletedPrices: priceCount)
        }
    }
}

