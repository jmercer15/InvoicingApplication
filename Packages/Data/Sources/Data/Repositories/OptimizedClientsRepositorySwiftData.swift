import Foundation
import SwiftData
import Core

/// Optimized SwiftData implementation of ClientsRepository with caching and performance monitoring
public final class OptimizedClientsRepositorySwiftData: ClientsRepository, OptimizedRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    private let cache: QueryOptimizationGuide.QueryCache
    private var queryMetrics: [QueryOptimizationGuide.QueryMetrics] = []
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.cache = QueryOptimizationGuide.QueryCache(maxAge: 300, maxSize: 100) // 5 minutes, 100 items
    }
    
    // MARK: - Optimized Query Methods
    
    public func fetchAll() async throws -> [Client] {
        let cacheKey = "fetchAll_clients"
        
        // Check cache first
        if let cached: [Client] = cache.get(cacheKey) {
            return cached
        }
        
        // Execute query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("fetchAll_clients") {
            let descriptor = FetchDescriptor<ClientEntity>(
                sortBy: [SortDescriptor(\ClientEntity.fullName, order: .forward)]
            )
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Client(from: $0) }
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    public func fetchActive() async throws -> [Client] {
        let cacheKey = "fetchActive_clients"
        
        // Check cache first
        if let cached: [Client] = cache.get(cacheKey) {
            return cached
        }
        
        // Execute optimized query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("fetchActive_clients") {
            let descriptor = QueryOptimizationGuide.OptimizedDescriptors.byStatus(
                ClientStatus.active,
                statusProperty: \ClientEntity.status,
                sortBy: [SortDescriptor(\ClientEntity.fullName, order: .forward)]
            )
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Client(from: $0) }
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    public func fetch(by id: UUID) async throws -> Client? {
        let cacheKey = "fetchById_\(id.uuidString)"
        
        // Check cache first
        if let cached: Client? = cache.get(cacheKey) {
            return cached
        }
        
        // Execute optimized query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("fetchById_\(id.uuidString)") {
            let descriptor = QueryOptimizationGuide.OptimizedDescriptors.byId(id, for: ClientEntity.self)
            guard let entity = try modelContext.fetch(descriptor).first else { return nil as Client? }
            return Client(from: entity)
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    public func fetch(by ndisNumber: String) async throws -> Client? {
        let cacheKey = "fetchByNdisNumber_\(ndisNumber)"
        
        // Check cache first
        if let cached: Client? = cache.get(cacheKey) {
            return cached
        }
        
        // Execute optimized query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("fetchByNdisNumber_\(ndisNumber)") {
            let predicate = #Predicate<ClientEntity> { client in
                client.ndisNumber == ndisNumber
            }
            let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else { return nil as Client? }
            return Client(from: entity)
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    public func fetchByStatus(_ status: String) async throws -> [Client] {
        let cacheKey = "fetchByStatus_\(status)"
        
        // Check cache first
        if let cached: [Client] = cache.get(cacheKey) {
            return cached
        }
        
        // Execute optimized query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("fetchByStatus_\(status)") {
            let descriptor = QueryOptimizationGuide.OptimizedDescriptors.byStatus(
                ClientStatus(rawValue: status) ?? .active,
                statusProperty: \ClientEntity.status,
                sortBy: [SortDescriptor(\ClientEntity.fullName, order: .forward)]
            )
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Client(from: $0) }
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    public func fetchByEmail(_ email: String) async throws -> [Client] {
        let cacheKey = "fetchByEmail_\(email)"
        
        // Check cache first
        if let cached: [Client] = cache.get(cacheKey) {
            return cached
        }
        
        // Execute optimized query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("fetchByEmail_\(email)") {
            let predicate = #Predicate<ClientEntity> { client in
                client.email == email
            }
            let descriptor = FetchDescriptor<ClientEntity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\ClientEntity.fullName, order: .forward)]
            )
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Client(from: $0) }
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    public func search(query: String) async throws -> [Client] {
        let cacheKey = "search_\(query)"
        
        // Check cache first
        if let cached: [Client] = cache.get(cacheKey) {
            return cached
        }
        
        // Execute optimized search query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("search_\(query)") {
            let predicate = #Predicate<ClientEntity> { client in
                client.fullName.localizedStandardContains(query) ||
                client.ndisNumber.localizedStandardContains(query) ||
                (client.email?.localizedStandardContains(query) ?? false)
            }
            let descriptor = FetchDescriptor<ClientEntity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\ClientEntity.fullName, order: .forward)]
            ).withLimit(50) // Limit search results for performance
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Client(from: $0) }
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    // MARK: - Paginated Queries
    
    /// Fetch clients with pagination
    /// - Parameters:
    ///   - offset: Number of clients to skip
    ///   - limit: Maximum number of clients to return
    /// - Returns: Paginated list of clients
    public func fetchPaginated(offset: Int = 0, limit: Int = 50) async throws -> [Client] {
        let cacheKey = "fetchPaginated_\(offset)_\(limit)"
        
        // Check cache first
        if let cached: [Client] = cache.get(cacheKey) {
            return cached
        }
        
        // Execute paginated query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("fetchPaginated_\(offset)_\(limit)") {
            let descriptor = QueryOptimizationGuide.OptimizedDescriptors.paginated(
                offset: offset,
                limit: limit,
                sortBy: [SortDescriptor(\ClientEntity.fullName, order: .forward)]
            )
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Client(from: $0) }
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    // MARK: - CRUD Operations
    
    public func create(_ client: Client) async throws -> Client {
        // Clear relevant cache entries
        cache.clear()
        
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("create_client") {
            let entity = ClientEntity(
                id: client.id,
                ndisNumber: client.ndisNumber,
                fullName: client.fullName,
                status: ClientStatus(rawValue: client.status) ?? .active
            )
            entity.update(from: client)
            modelContext.insert(entity)
            try modelContext.save()
            return Client(from: entity)
        }
        
        queryMetrics.append(metrics)
        return result
    }
    
    public func update(_ client: Client) async throws -> Client {
        // Clear relevant cache entries
        cache.clear()
        
        guard let entity = try await fetchEntity(by: client.id) else {
            throw RepositoryError.entityNotFound
        }
        
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("update_client") {
            entity.update(from: client)
            try modelContext.save()
            return Client(from: entity)
        }
        
        queryMetrics.append(metrics)
        return result
    }
    
    public func delete(id: UUID) async throws {
        // Clear relevant cache entries
        cache.clear()
        
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        
        let (_, metrics) = try QueryOptimizationGuide.monitorQuery("delete_client") {
            modelContext.delete(entity)
            try modelContext.save()
        }
        
        queryMetrics.append(metrics)
    }
    
    // MARK: - Missing Protocol Methods
    
    public func archive(id: UUID) async throws {
        // Implementation for archiving client
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        entity.status = .archived
        try modelContext.save()
    }
    
    public func reactivate(id: UUID) async throws {
        // Implementation for reactivating client
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        entity.status = .active
        try modelContext.save()
    }
    
    public func updateStatus(id: UUID, status: String) async throws {
        // Implementation for updating client status
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        entity.status = ClientStatus(rawValue: status) ?? .active
        try modelContext.save()
    }
    
    public func count() async throws -> Int {
        let descriptor = FetchDescriptor<ClientEntity>()
        return try modelContext.fetchCount(descriptor)
    }
    
    public func countActive() async throws -> Int {
        let predicate = #Predicate<ClientEntity> { client in
            client.status.rawValue == "Active"
        }
        let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
        return try modelContext.fetchCount(descriptor)
    }
    
    // MARK: - OptimizedRepository Protocol
    
    public func getQueryMetrics() -> [QueryOptimizationGuide.QueryMetrics] {
        return queryMetrics
    }
    
    public func clearCache() {
        cache.clear()
    }
    
    public func getCacheStats() -> (hitRate: Double, size: Int, maxSize: Int) {
        // This would need to be implemented with actual cache hit/miss tracking
        return (hitRate: 0.0, size: 0, maxSize: 100)
    }
    
    // MARK: - Private Helpers
    
    private func fetchEntity(by id: UUID) async throws -> ClientEntity? {
        let predicate = #Predicate<ClientEntity> { client in
            client.id == id
        }
        let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
}

// MARK: - Performance Monitoring Extensions

extension OptimizedClientsRepositorySwiftData {
    
    /// Get performance summary
    public func getPerformanceSummary() -> String {
        let totalQueries = queryMetrics.count
        let totalTime = queryMetrics.reduce(0) { $0 + $1.executionTime }
        let avgTime = totalQueries > 0 ? totalTime / Double(totalQueries) : 0
        let slowestQuery = queryMetrics.max { $0.executionTime < $1.executionTime }
        
        var summary = "Performance Summary:\n"
        summary += "Total Queries: \(totalQueries)\n"
        summary += "Total Time: \(String(format: "%.3f", totalTime))s\n"
        summary += "Average Time: \(String(format: "%.3f", avgTime))s\n"
        
        if let slowest = slowestQuery {
            summary += "Slowest Query: \(slowest.queryName) (\(String(format: "%.3f", slowest.executionTime))s)\n"
        }
        
        return summary
    }
    
    /// Clear performance metrics
    public func clearMetrics() {
        queryMetrics.removeAll()
    }
    
    // MARK: - Missing Protocol Methods
    
    public func fetch(limit: Int, offset: Int) async throws -> [Client] {
        var descriptor = FetchDescriptor<ClientEntity>(
            sortBy: [SortDescriptor(\ClientEntity.fullName, order: .forward)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Client(from: $0) }
    }
}
