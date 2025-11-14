import Foundation
import SwiftData
import Core

/// SwiftData implementation of NDISItemRepository
public final class NDISItemRepositorySwiftData: NDISItemRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    public func fetchAll() async throws -> [NDISItem] {
        let descriptor = FetchDescriptor<NDISItemEntity>(
            sortBy: [
                SortDescriptor(\.itemNumber, order: .forward),
                SortDescriptor(\.effectiveStartDate, order: .reverse)
            ]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { NDISItem(from: $0) }
    }
    
    public func fetchCurrent() async throws -> [NDISItem] {
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
        return entities.map { NDISItem(from: $0) }
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
            return filteredEntities.map { NDISItem(from: $0) }
        }
    }
    
    public func fetch(by id: UUID) async throws -> NDISItem? {
        let predicate = #Predicate<NDISItemEntity> { item in
            item.id == id
        }
        let descriptor = FetchDescriptor<NDISItemEntity>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return NDISItem(from: entity)
    }
    
    public func fetch(by itemNumber: String) async throws -> NDISItem? {
        let predicate = #Predicate<NDISItemEntity> { item in
            item.itemNumber == itemNumber
        }
        let descriptor = FetchDescriptor<NDISItemEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.effectiveStartDate, order: .reverse)]
        )
        // Get the most recent version if multiple exist
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return NDISItem(from: entity)
    }
    
    public func search(query: String) async throws -> [NDISItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
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
        return entities.map { NDISItem(from: $0) }
    }
    
    public func fetch(by category: String) async throws -> [NDISItem] {
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
        return entities.map { NDISItem(from: $0) }
    }
    
    public func count() async throws -> Int {
        let descriptor = FetchDescriptor<NDISItemEntity>()
        return try modelContext.fetchCount(descriptor)
    }
    
    public func countCurrent() async throws -> Int {
        let predicate = #Predicate<NDISItemEntity> { item in
            item.isCurrent == true
        }
        let descriptor = FetchDescriptor<NDISItemEntity>(predicate: predicate)
        return try modelContext.fetchCount(descriptor)
    }
}

