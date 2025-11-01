import Foundation
import SwiftData
import Core

/// Database index configuration for optimal query performance
/// 
/// This file defines the recommended database indexes for all entities
/// to ensure optimal query performance across the application.
public struct DatabaseIndexConfiguration {
    
    // MARK: - Index Configuration
    
    /// Recommended indexes for ClientEntity
    public static let clientEntityIndexes: [String] = [
        "id",           // Primary key - always indexed
        "ndisNumber",   // Unique constraint - always indexed
        "status",       // Frequently filtered (active/inactive)
        "fullName",     // Frequently sorted and searched
        "email",        // Frequently searched
        "phone",        // Occasionally searched
        "hasNdisPlan",  // Frequently filtered
        "isMinor"       // Occasionally filtered
    ]
    
    /// Recommended indexes for InvoiceEntity
    public static let invoiceEntityIndexes: [String] = [
        "id",           // Primary key - always indexed
        "invoiceNumber", // Unique constraint - always indexed
        "status",       // Frequently filtered (draft/sent/paid)
        "issueDate",    // Frequently sorted and filtered
        "dueDate",      // Frequently filtered for overdue invoices
        "clientId",     // Foreign key - frequently joined
        "totalAmount",  // Occasionally sorted
        "paidDate",     // Occasionally filtered
        "sentDate"      // Occasionally filtered
    ]
    
    /// Recommended indexes for SessionEntity
    public static let sessionEntityIndexes: [String] = [
        "id",           // Primary key - always indexed
        "startTime",    // Frequently sorted and filtered
        "endTime",      // Frequently filtered
        "clientId",     // Foreign key - frequently joined
        "status",       // Frequently filtered
        "isTravel",     // Frequently filtered
        "title",        // Occasionally searched
        "location"      // Occasionally searched
    ]
    
    /// Recommended indexes for TravelChargeEntity
    public static let travelChargeEntityIndexes: [String] = [
        "id",           // Primary key - always indexed
        "linkedSessionId", // Foreign key - frequently joined
        "clientId",     // Foreign key - frequently joined
        "status",       // Frequently filtered
        "amount",       // Occasionally sorted
        "date"          // Frequently sorted and filtered
    ]
    
    /// Recommended indexes for ClientServiceEntity
    public static let clientServiceEntityIndexes: [String] = [
        "id",             // Primary key - always indexed
        "serviceName",    // Frequently searched and sorted
        "ndisCode",       // Frequently searched
        "clientServiceID",// Legacy import identifier
        "clientId",       // Foreign key - frequently joined
        "ndisItemId",     // Foreign key - frequently joined
        "status",         // Frequently filtered
        "isActive",       // Frequently filtered
        "rate",           // Occasionally sorted
        "unit",           // Occasionally filtered
        "startDate",      // Occasionally filtered
        "endDate"         // Occasionally filtered
    ]
    
    /// Recommended indexes for NDISItemEntity
    public static let ndisItemEntityIndexes: [String] = [
        "id",           // Primary key - always indexed
        "itemNumber",   // Frequently searched
        "name",         // Frequently searched
        "category",     // Frequently filtered
        "status",       // Frequently filtered
        "isCurrent"     // Frequently filtered
    ]
    
    /// Recommended indexes for PayeeEntity
    public static let payeeEntityIndexes: [String] = [
        "id",           // Primary key - always indexed
        "fullName",     // Frequently searched
        "email",        // Occasionally searched
        "status",       // Frequently filtered
        "payeeID"       // Occasionally searched
    ]
    
    /// Recommended indexes for PlanManagerEntity
    public static let planManagerEntityIndexes: [String] = [
        "id",           // Primary key - always indexed
        "abn",          // Unique constraint - always indexed
        "name",         // Frequently searched
        "email",        // Occasionally searched
        "phone"         // Occasionally searched
    ]
    
    /// Recommended indexes for AddressEntity
    public static let addressEntityIndexes: [String] = [
        "id",           // Primary key - always indexed
        "postcode",     // Frequently filtered
        "state",        // Frequently filtered
        "city",         // Frequently filtered
        "streetName"    // Occasionally searched
    ]
    
    // MARK: - Composite Indexes
    
    /// Recommended composite indexes for complex queries
    public static let compositeIndexes: [String: [String]] = [
        "InvoiceEntity": [
            "status,issueDate",      // For status filtering with date sorting
            "clientId,status",       // For client invoices by status
            "dueDate,status",        // For overdue invoice queries
            "issueDate,status"       // For date range with status filtering
        ],
        "SessionEntity": [
            "clientId,startTime",    // For client sessions by date
            "startTime,endTime",     // For time range queries
            "status,startTime",      // For status filtering with date sorting
            "isTravel,startTime"     // For travel sessions by date
        ],
        "TravelChargeEntity": [
            "clientId,status",       // For client travel charges by status
            "linkedSessionId,status", // For session travel charges by status
            "date,status"            // For date range with status filtering
        ],
        "ClientServiceEntity": [
            "clientId,isActive",     // Active services per client
            "clientId,serviceName",  // Sorting client services alphabetically
            "ndisCode,serviceName"    // Resolving duplicates by code and name
        ],
        "ClientEntity": [
            "status,fullName",       // For active clients sorted by name
            "hasNdisPlan,status",    // For NDIS clients by status
            "isMinor,status"         // For minor clients by status
        ]
    ]
    
    // MARK: - Index Usage Guidelines
    
    /// Guidelines for effective index usage
    public static let indexUsageGuidelines = [
        "Index frequently queried columns",
        "Index columns used in WHERE clauses",
        "Index columns used in ORDER BY clauses",
        "Index foreign key columns for joins",
        "Use composite indexes for multi-column queries",
        "Avoid over-indexing as it slows down writes",
        "Monitor index usage and remove unused indexes",
        "Consider partial indexes for filtered queries",
        "Use covering indexes to avoid table lookups",
        "Regularly analyze query performance and adjust indexes"
    ]
    
    // MARK: - Query Performance Tips
    
    /// Tips for writing performant queries
    public static let queryPerformanceTips = [
        "Use specific predicates instead of fetching all and filtering",
        "Limit result sets using fetchLimit for large datasets",
        "Use pagination for large result sets",
        "Avoid SELECT * - only fetch needed columns",
        "Use appropriate data types to minimize storage",
        "Avoid complex expressions in WHERE clauses",
        "Use EXISTS instead of IN for subqueries when possible",
        "Consider denormalization for frequently joined data",
        "Use batch operations for bulk updates",
        "Profile queries to identify bottlenecks"
    ]
    
    // MARK: - Index Monitoring
    
    /// Monitor index usage and performance
    public struct IndexMonitoring {
        
        /// Track index usage statistics
        public struct IndexStats {
            public let indexName: String
            public let usageCount: Int
            public let lastUsed: Date
            public let averageQueryTime: TimeInterval
            
            public init(indexName: String, usageCount: Int, lastUsed: Date, averageQueryTime: TimeInterval) {
                self.indexName = indexName
                self.usageCount = usageCount
                self.lastUsed = lastUsed
                self.averageQueryTime = averageQueryTime
            }
        }
        
        /// Get index usage statistics
        /// - Returns: Array of index statistics
        public static func getIndexStats() -> [IndexStats] {
            // This would be implemented to query actual index usage statistics
            // For now, return empty array
            return []
        }
        
        /// Identify unused indexes
        /// - Returns: Array of unused index names
        public static func getUnusedIndexes() -> [String] {
            // This would be implemented to identify unused indexes
            // For now, return empty array
            return []
        }
        
        /// Get slow query recommendations
        /// - Returns: Array of query optimization recommendations
        public static func getSlowQueryRecommendations() -> [String] {
            // This would be implemented to analyze slow queries
            // For now, return empty array
            return []
        }
    }
    
    // MARK: - Index Maintenance
    
    /// Index maintenance utilities
    public struct IndexMaintenance {
        
        /// Rebuild all indexes
        /// - Parameter modelContext: The model context
        public static func rebuildAllIndexes(modelContext: ModelContext) async throws {
            // This would be implemented to rebuild all indexes
            // For now, just log the action
            print("Rebuilding all indexes...")
        }
        
        /// Analyze index usage and suggest optimizations
        /// - Parameter modelContext: The model context
        /// - Returns: Array of optimization suggestions
        public static func analyzeIndexUsage(modelContext: ModelContext) async throws -> [String] {
            // This would be implemented to analyze index usage
            // For now, return empty array
            return []
        }
        
        /// Clean up unused indexes
        /// - Parameter modelContext: The model context
        public static func cleanupUnusedIndexes(modelContext: ModelContext) async throws {
            // This would be implemented to remove unused indexes
            // For now, just log the action
            print("Cleaning up unused indexes...")
        }
    }
}

// MARK: - Index Configuration Extensions

extension DatabaseIndexConfiguration {
    
    /// Get all recommended indexes for an entity
    /// - Parameter entityName: The name of the entity
    /// - Returns: Array of recommended index names
    public static func getIndexes(for entityName: String) -> [String] {
        switch entityName {
        case "ClientEntity":
            return clientEntityIndexes
        case "InvoiceEntity":
            return invoiceEntityIndexes
        case "SessionEntity":
            return sessionEntityIndexes
        case "TravelChargeEntity":
            return travelChargeEntityIndexes
        case "ClientServiceEntity":
            return clientServiceEntityIndexes
        case "NDISItemEntity":
            return ndisItemEntityIndexes
        case "PayeeEntity":
            return payeeEntityIndexes
        case "PlanManagerEntity":
            return planManagerEntityIndexes
        case "AddressEntity":
            return addressEntityIndexes
        default:
            return []
        }
    }
    
    /// Get composite indexes for an entity
    /// - Parameter entityName: The name of the entity
    /// - Returns: Array of composite index definitions
    public static func getCompositeIndexes(for entityName: String) -> [String] {
        return compositeIndexes[entityName] ?? []
    }
    
    /// Get all recommended indexes across all entities
    /// - Returns: Dictionary mapping entity names to their recommended indexes
    public static func getAllIndexes() -> [String: [String]] {
        return [
            "ClientEntity": clientEntityIndexes,
            "InvoiceEntity": invoiceEntityIndexes,
            "SessionEntity": sessionEntityIndexes,
            "TravelChargeEntity": travelChargeEntityIndexes,
            "ClientServiceEntity": clientServiceEntityIndexes,
            "NDISItemEntity": ndisItemEntityIndexes,
            "PayeeEntity": payeeEntityIndexes,
            "PlanManagerEntity": planManagerEntityIndexes,
            "AddressEntity": addressEntityIndexes
        ]
    }
}
