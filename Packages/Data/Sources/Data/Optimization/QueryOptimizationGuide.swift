import Foundation
import SwiftData
import Core

/// Query optimization guide and utilities for SwiftData repositories
/// 
/// This file provides guidelines and utilities for optimizing database queries
/// to improve performance and reduce memory usage.
public struct QueryOptimizationGuide {
    
    // MARK: - Indexing Guidelines
    
    /// Properties that should be indexed for optimal query performance
    public struct IndexedProperties {
        
        // ClientEntity indexes
        public static let clientEntityIndexes = [
            "id",           // Primary key - always indexed
            "ndisNumber",   // Unique constraint - always indexed
            "status",       // Frequently filtered
            "fullName",     // Frequently sorted
            "email"         // Frequently searched
        ]
        
        // InvoiceEntity indexes
        public static let invoiceEntityIndexes = [
            "id",           // Primary key - always indexed
            "invoiceNumber", // Unique constraint - always indexed
            "status",       // Frequently filtered
            "issueDate",    // Frequently sorted
            "clientId",     // Foreign key - frequently joined
            "dueDate"       // Frequently filtered for overdue invoices
        ]
        
        // SessionEntity indexes
        public static let sessionEntityIndexes = [
            "id",           // Primary key - always indexed
            "startTime",    // Frequently sorted and filtered
            "endTime",      // Frequently filtered
            "clientId",     // Foreign key - frequently joined
            "status",       // Frequently filtered
            "isTravel"      // Frequently filtered
        ]
        
        // TravelChargeEntity indexes
        public static let travelChargeEntityIndexes = [
            "id",           // Primary key - always indexed
            "linkedSessionId", // Foreign key - frequently joined
            "clientId",     // Foreign key - frequently joined
            "status"        // Frequently filtered
        ]
        
        // ClientServiceEntity indexes
        public static let clientServiceEntityIndexes = [
            "id",             // Primary key - always indexed
            "serviceName",    // Frequently searched
            "ndisCode",       // Frequently searched
            "clientServiceID",// Legacy identifier
            "clientId",       // Foreign key
            "ndisItemId",     // Foreign key
            "status",         // Frequently filtered
            "isActive",       // Frequently filtered
            "rate",           // Occasionally sorted
            "unit"            // Occasionally filtered
        ]
    }
    
    // MARK: - Query Optimization Patterns
    
    /// Optimized fetch descriptor for common query patterns
    public struct OptimizedDescriptors {
        
        /// Create an optimized descriptor for fetching entities by ID
        /// - Parameter id: The entity ID
        /// - Returns: Optimized fetch descriptor
        public static func byId<T: PersistentModel>(_ id: UUID, for type: T.Type) -> FetchDescriptor<T> {
            // Note: This is a simplified version - SwiftData doesn't support direct UUID comparison with persistentModelID
            // This would need to be implemented differently in a real scenario
            return FetchDescriptor<T>()
        }
        
        /// Create an optimized descriptor for paginated results
        /// - Parameters:
        ///   - offset: Number of items to skip
        ///   - limit: Maximum number of items to return
        ///   - sortBy: Sort descriptors
        /// - Returns: Optimized fetch descriptor with pagination
        public static func paginated<T: PersistentModel>(
            offset: Int = 0,
            limit: Int = 50,
            sortBy: [SortDescriptor<T>] = []
        ) -> FetchDescriptor<T> {
            var descriptor = FetchDescriptor<T>(sortBy: sortBy)
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = limit
            return descriptor
        }
        
        /// Create an optimized descriptor for date range queries
        /// - Parameters:
        ///   - startDate: Start of date range
        ///   - endDate: End of date range
        ///   - dateProperty: KeyPath to the date property
        ///   - sortBy: Sort descriptors
        /// - Returns: Optimized fetch descriptor for date range
        public static func dateRange<T: PersistentModel>(
            from startDate: Date,
            to endDate: Date,
            dateProperty: KeyPath<T, Date?>,
            sortBy: [SortDescriptor<T>] = []
        ) -> FetchDescriptor<T> {
            // Note: SwiftData predicates don't support keyPath subscript operations
            // This would need to be implemented with specific entity types
            return FetchDescriptor<T>(sortBy: sortBy)
        }
        
        /// Create an optimized descriptor for filtering by date range (non-optional Date)
        /// - Parameters:
        ///   - startDate: Start date for filtering
        ///   - endDate: End date for filtering
        ///   - dateProperty: KeyPath to the date property
        ///   - sortBy: Sort descriptors
        /// - Returns: Optimized fetch descriptor for date range filtering
        public static func dateRange<T: PersistentModel>(
            from startDate: Date,
            to endDate: Date,
            dateProperty: KeyPath<T, Date>,
            sortBy: [SortDescriptor<T>] = []
        ) -> FetchDescriptor<T> {
            // Note: SwiftData predicates don't support keyPath subscript operations
            // This would need to be implemented with specific entity types
            return FetchDescriptor<T>(sortBy: sortBy)
        }
        
        /// Create an optimized descriptor for status filtering (supports both String and enum types)
        /// - Parameters:
        ///   - status: Status value to filter by (String or enum)
        ///   - statusProperty: KeyPath to the status property
        ///   - sortBy: Sort descriptors
        /// - Returns: Optimized fetch descriptor for status filtering
        public static func byStatus<T: PersistentModel, S>(
            _ status: S,
            statusProperty: KeyPath<T, S>,
            sortBy: [SortDescriptor<T>] = []
        ) -> FetchDescriptor<T> {
            // Note: SwiftData predicates don't support keyPath subscript operations
            // This would need to be implemented with specific entity types
            return FetchDescriptor<T>(sortBy: sortBy)
        }
        
        /// Create an optimized descriptor for filtering by optional status (supports both String and enum types)
        /// - Parameters:
        ///   - status: Status value to filter by (String or enum)
        ///   - statusProperty: KeyPath to the optional status property
        ///   - sortBy: Sort descriptors
        /// - Returns: Optimized fetch descriptor for status filtering
        public static func byStatus<T: PersistentModel, S>(
            _ status: S,
            statusProperty: KeyPath<T, S?>,
            sortBy: [SortDescriptor<T>] = []
        ) -> FetchDescriptor<T> {
            // Note: SwiftData predicates don't support keyPath subscript operations
            // This would need to be implemented with specific entity types
            return FetchDescriptor<T>(sortBy: sortBy)
        }
        
    }
    
    // MARK: - Performance Monitoring
    
    /// Query performance metrics
    public struct QueryMetrics {
        public let queryName: String
        public let executionTime: TimeInterval
        public let resultCount: Int
        public let memoryUsage: Int
        
        public init(queryName: String, executionTime: TimeInterval, resultCount: Int, memoryUsage: Int) {
            self.queryName = queryName
            self.executionTime = executionTime
            self.resultCount = resultCount
            self.memoryUsage = memoryUsage
        }
    }
    
    /// Monitor query performance
    /// - Parameters:
    ///   - queryName: Name of the query for logging
    ///   - operation: The query operation to monitor
    /// - Returns: Query metrics
    public static func monitorQuery<T>(
        _ queryName: String,
        operation: () throws -> T
    ) rethrows -> (result: T, metrics: QueryMetrics) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getMemoryUsage()
        
        let result = try operation()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = getMemoryUsage()
        
        let metrics = QueryMetrics(
            queryName: queryName,
            executionTime: endTime - startTime,
            resultCount: (result as? [Any])?.count ?? 1,
            memoryUsage: endMemory - startMemory
        )
        
        // Log performance metrics
        print("Query '\(queryName)' executed in \(String(format: "%.3f", metrics.executionTime))s, returned \(metrics.resultCount) results, used \(metrics.memoryUsage) bytes")
        
        return (result: result, metrics: metrics)
    }
    
    // MARK: - Caching Utilities
    
    /// Simple in-memory cache for query results
    public class QueryCache {
        private var cache: [String: (data: Any, timestamp: Date)] = [:]
        private let maxAge: TimeInterval
        private let maxSize: Int
        
        public init(maxAge: TimeInterval = 300, maxSize: Int = 100) { // 5 minutes, 100 items
            self.maxAge = maxAge
            self.maxSize = maxSize
        }
        
        /// Get cached result if available and not expired
        public func get<T>(_ key: String) -> T? {
            guard let cached = cache[key] else { return nil }
            
            // Check if expired
            if Date().timeIntervalSince(cached.timestamp) > maxAge {
                cache.removeValue(forKey: key)
                return nil
            }
            
            return cached.data as? T
        }
        
        /// Set cached result
        public func set<T>(_ key: String, value: T) {
            // Remove oldest entries if cache is full
            if cache.count >= maxSize {
                let oldestKey = cache.min { $0.value.timestamp < $1.value.timestamp }?.key
                if let oldestKey = oldestKey {
                    cache.removeValue(forKey: oldestKey)
                }
            }
            
            cache[key] = (data: value, timestamp: Date())
        }
        
        /// Clear all cached results
        public func clear() {
            cache.removeAll()
        }
        
        /// Remove expired entries
        public func cleanup() {
            let now = Date()
            cache = cache.filter { now.timeIntervalSince($0.value.timestamp) <= maxAge }
        }
    }
    
    // MARK: - Query Optimization Tips
    
    /// Common query optimization tips
    public static let optimizationTips = [
        "Use specific predicates instead of fetching all and filtering in memory",
        "Limit result sets using fetchLimit for large datasets",
        "Use pagination for large result sets",
        "Index frequently queried properties",
        "Avoid N+1 queries by using relationships efficiently",
        "Use batch operations for bulk updates",
        "Consider caching frequently accessed data",
        "Profile queries to identify performance bottlenecks",
        "Use appropriate sort descriptors for indexed properties",
        "Avoid complex predicates that can't use indexes"
    ]
    
    // MARK: - Private Helpers
    
    private static func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
}

// MARK: - Query Optimization Extensions

extension FetchDescriptor {
    
    /// Add pagination to an existing fetch descriptor
    /// - Parameters:
    ///   - offset: Number of items to skip
    ///   - limit: Maximum number of items to return
    /// - Returns: Modified fetch descriptor with pagination
    public func withPagination(offset: Int = 0, limit: Int = 50) -> FetchDescriptor<T> {
        var descriptor = self
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return descriptor
    }
    
    /// Add result limiting to an existing fetch descriptor
    /// - Parameter limit: Maximum number of items to return
    /// - Returns: Modified fetch descriptor with limit
    public func withLimit(_ limit: Int) -> FetchDescriptor<T> {
        var descriptor = self
        descriptor.fetchLimit = limit
        return descriptor
    }
}

// MARK: - Repository Optimization Protocol

/// Protocol for repositories that support query optimization
public protocol OptimizedRepository {
    /// Get query performance metrics
    func getQueryMetrics() -> [QueryOptimizationGuide.QueryMetrics]
    
    /// Clear query cache
    func clearCache()
    
    /// Get cache statistics
    func getCacheStats() -> (hitRate: Double, size: Int, maxSize: Int)
}
