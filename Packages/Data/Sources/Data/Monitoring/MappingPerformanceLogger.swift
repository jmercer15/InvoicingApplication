import Foundation
import os.log

/// Logger for tracking mapping operation performance and metrics
public final class MappingPerformanceLogger: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = MappingPerformanceLogger()
    
    private init() {}
    
    // MARK: - Logging Categories
    
    private let mappingLogger = Logger(subsystem: "com.invoicingapp.data", category: "mapping")
    private let performanceLogger = Logger(subsystem: "com.invoicingapp.data", category: "performance")
    private let errorLogger = Logger(subsystem: "com.invoicingapp.data", category: "mapping-errors")
    
    // MARK: - Performance Metrics
    
    private var performanceMetrics: [String: PerformanceMetrics] = [:]
    private let metricsQueue = DispatchQueue(label: "mapping.metrics", attributes: .concurrent)
    
    // MARK: - Logging Methods
    
    /// Log the start of a mapping operation
    /// - Parameters:
    ///   - operation: The type of mapping operation
    ///   - entityType: The entity type being mapped
    ///   - domainType: The domain type being mapped to
    ///   - operationId: Unique identifier for this operation
    public func logMappingStart(
        operation: MappingOperation,
        entityType: String,
        domainType: String,
        operationId: String = UUID().uuidString
    ) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        mappingLogger.info("""
            Mapping started: \(operation.rawValue) from \(entityType) to \(domainType)
            Operation ID: \(operationId)
            """)
        
        metricsQueue.async(flags: .barrier) {
            self.performanceMetrics[operationId] = PerformanceMetrics(
                operation: operation,
                entityType: entityType,
                domainType: domainType,
                startTime: startTime,
                operationId: operationId
            )
        }
    }
    
    /// Log the completion of a mapping operation
    /// - Parameters:
    ///   - operationId: Unique identifier for this operation
    ///   - success: Whether the operation was successful
    ///   - error: Error if the operation failed
    public func logMappingCompletion(
        operationId: String,
        success: Bool,
        error: Error? = nil
    ) {
        let endTime = CFAbsoluteTimeGetCurrent()
        
        metricsQueue.async(flags: .barrier) {
            guard var metrics = self.performanceMetrics[operationId] else {
                self.errorLogger.error("No metrics found for operation ID: \(operationId)")
                return
            }
            
            metrics.endTime = endTime
            metrics.duration = endTime - metrics.startTime
            metrics.success = success
            metrics.error = error
            
            self.performanceMetrics[operationId] = metrics
            
            // Log completion
            if success {
                self.mappingLogger.info("""
                    Mapping completed: \(metrics.operation.rawValue) from \(metrics.entityType) to \(metrics.domainType)
                    Duration: \(String(format: "%.3f", metrics.duration))s
                    Operation ID: \(operationId)
                    """)
            } else {
                self.errorLogger.error("""
                    Mapping failed: \(metrics.operation.rawValue) from \(metrics.entityType) to \(metrics.domainType)
                    Duration: \(String(format: "%.3f", metrics.duration))s
                    Error: \(error?.localizedDescription ?? "Unknown error")
                    Operation ID: \(operationId)
                    """)
            }
            
            // Check for performance issues
            self.checkPerformanceThresholds(metrics: metrics)
        }
    }
    
    /// Log a batch mapping operation
    /// - Parameters:
    ///   - operation: The type of mapping operation
    ///   - entityType: The entity type being mapped
    ///   - domainType: The domain type being mapped to
    ///   - count: Number of items being mapped
    ///   - operationId: Unique identifier for this operation
    public func logBatchMappingStart(
        operation: MappingOperation,
        entityType: String,
        domainType: String,
        count: Int,
        operationId: String = UUID().uuidString
    ) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        mappingLogger.info("""
            Batch mapping started: \(operation.rawValue) from \(entityType) to \(domainType)
            Count: \(count)
            Operation ID: \(operationId)
            """)
        
        metricsQueue.async(flags: .barrier) {
            self.performanceMetrics[operationId] = PerformanceMetrics(
                operation: operation,
                entityType: entityType,
                domainType: domainType,
                startTime: startTime,
                operationId: operationId,
                batchSize: count
            )
        }
    }
    
    /// Log the completion of a batch mapping operation
    /// - Parameters:
    ///   - operationId: Unique identifier for this operation
    ///   - success: Whether the operation was successful
    ///   - processedCount: Number of items successfully processed
    ///   - error: Error if the operation failed
    public func logBatchMappingCompletion(
        operationId: String,
        success: Bool,
        processedCount: Int,
        error: Error? = nil
    ) {
        let endTime = CFAbsoluteTimeGetCurrent()
        
        metricsQueue.async(flags: .barrier) {
            guard var metrics = self.performanceMetrics[operationId] else {
                self.errorLogger.error("No metrics found for batch operation ID: \(operationId)")
                return
            }
            
            metrics.endTime = endTime
            metrics.duration = endTime - metrics.startTime
            metrics.success = success
            metrics.error = error
            metrics.processedCount = processedCount
            
            self.performanceMetrics[operationId] = metrics
            
            // Calculate performance metrics
            let itemsPerSecond = (metrics.batchSize ?? 0) > 0 ? Double(processedCount) / metrics.duration : 0.0
            
            if success {
                self.mappingLogger.info("""
                    Batch mapping completed: \(metrics.operation.rawValue) from \(metrics.entityType) to \(metrics.domainType)
                    Processed: \(processedCount)/\(metrics.batchSize ?? 0)
                    Duration: \(String(format: "%.3f", metrics.duration))s
                    Rate: \(String(format: "%.1f", itemsPerSecond)) items/sec
                    Operation ID: \(operationId)
                    """)
            } else {
                self.errorLogger.error("""
                    Batch mapping failed: \(metrics.operation.rawValue) from \(metrics.entityType) to \(metrics.domainType)
                    Processed: \(processedCount)/\(metrics.batchSize ?? 0)
                    Duration: \(String(format: "%.3f", metrics.duration))s
                    Error: \(error?.localizedDescription ?? "Unknown error")
                    Operation ID: \(operationId)
                    """)
            }
            
            // Check for performance issues
            self.checkPerformanceThresholds(metrics: metrics)
        }
    }
    
    /// Log a mapping error
    /// - Parameters:
    ///   - operation: The type of mapping operation
    ///   - entityType: The entity type being mapped
    ///   - domainType: The domain type being mapped to
    ///   - error: The error that occurred
    ///   - context: Additional context about the error
    public func logMappingError(
        operation: MappingOperation,
        entityType: String,
        domainType: String,
        error: Error,
        context: String? = nil
    ) {
        errorLogger.error("""
            Mapping error: \(operation.rawValue) from \(entityType) to \(domainType)
            Error: \(error.localizedDescription)
            Context: \(context ?? "None")
            """)
    }
    
    /// Log a data integrity issue
    /// - Parameters:
    ///   - issue: The type of integrity issue
    ///   - entityType: The entity type affected
    ///   - entityId: The ID of the affected entity
    ///   - details: Additional details about the issue
    public func logDataIntegrityIssue(
        issue: DataIntegrityIssue,
        entityType: String,
        entityId: String,
        details: String? = nil
    ) {
        errorLogger.warning("""
            Data integrity issue: \(issue.rawValue)
            Entity: \(entityType) (ID: \(entityId))
            Details: \(details ?? "None")
            """)
    }
    
    // MARK: - Performance Monitoring
    
    /// Get performance statistics for a specific operation type
    /// - Parameter operation: The mapping operation type
    /// - Returns: Performance statistics for the operation
    public func getPerformanceStats(for operation: MappingOperation) -> PerformanceStats {
        return metricsQueue.sync {
            let relevantMetrics = performanceMetrics.values.filter { $0.operation == operation }
            
            guard !relevantMetrics.isEmpty else {
                return PerformanceStats(operation: operation, count: 0, averageDuration: 0, minDuration: 0, maxDuration: 0, successRate: 0)
            }
            
            let durations = relevantMetrics.compactMap { $0.duration }
            let successCount = relevantMetrics.filter { $0.success }.count
            
            return PerformanceStats(
                operation: operation,
                count: relevantMetrics.count,
                averageDuration: durations.reduce(0, +) / Double(durations.count),
                minDuration: durations.min() ?? 0,
                maxDuration: durations.max() ?? 0,
                successRate: Double(successCount) / Double(relevantMetrics.count)
            )
        }
    }
    
    /// Get all performance statistics
    /// - Returns: Dictionary of performance statistics by operation type
    public func getAllPerformanceStats() -> [MappingOperation: PerformanceStats] {
        return metricsQueue.sync {
            let operations = Set(performanceMetrics.values.map { $0.operation })
            return Dictionary(uniqueKeysWithValues: operations.map { operation in
                (operation, getPerformanceStats(for: operation))
            })
        }
    }
    
    /// Clear old performance metrics
    /// - Parameter olderThan: Remove metrics older than this date
    public func clearOldMetrics(olderThan date: Date = Date().addingTimeInterval(-3600)) {
        metricsQueue.async(flags: .barrier) {
            let cutoffTime = date.timeIntervalSince1970
            self.performanceMetrics = self.performanceMetrics.filter { _, metrics in
                metrics.startTime >= cutoffTime
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func checkPerformanceThresholds(metrics: PerformanceMetrics) {
        // Check for slow operations
        if metrics.duration > 1.0 { // 1 second threshold
            performanceLogger.warning("""
                Slow mapping operation detected: \(metrics.operation.rawValue)
                Duration: \(String(format: "%.3f", metrics.duration))s
                Entity: \(metrics.entityType) -> \(metrics.domainType)
                Operation ID: \(metrics.operationId)
                """)
        }
        
        // Check for batch performance issues
        if let batchSize = metrics.batchSize, batchSize > 0 {
            let itemsPerSecond = Double(metrics.processedCount) / metrics.duration
            if itemsPerSecond < 10.0 { // Less than 10 items per second
                performanceLogger.warning("""
                    Slow batch mapping detected: \(metrics.operation.rawValue)
                    Rate: \(String(format: "%.1f", itemsPerSecond)) items/sec
                    Batch size: \(batchSize)
                    Operation ID: \(metrics.operationId)
                    """)
            }
        }
    }
}

// MARK: - Supporting Types

/// Types of mapping operations
public enum MappingOperation: String, CaseIterable, Sendable {
    case entityToDomain = "Entity to Domain"
    case domainToEntity = "Domain to Entity"
    case batchEntityToDomain = "Batch Entity to Domain"
    case batchDomainToEntity = "Batch Domain to Entity"
    case roundTrip = "Round Trip"
}

/// Types of data integrity issues
public enum DataIntegrityIssue: String, CaseIterable, Sendable {
    case missingRequiredField = "Missing Required Field"
    case invalidDataFormat = "Invalid Data Format"
    case typeMismatch = "Type Mismatch"
    case relationshipNotFound = "Relationship Not Found"
    case dataCorruption = "Data Corruption"
}

/// Performance metrics for a single mapping operation
private struct PerformanceMetrics {
    let operation: MappingOperation
    let entityType: String
    let domainType: String
    let startTime: CFAbsoluteTime
    let operationId: String
    let batchSize: Int?
    
    var endTime: CFAbsoluteTime?
    var duration: CFAbsoluteTime = 0
    var success: Bool = false
    var error: Error?
    var processedCount: Int = 0
    
    init(
        operation: MappingOperation,
        entityType: String,
        domainType: String,
        startTime: CFAbsoluteTime,
        operationId: String,
        batchSize: Int? = nil
    ) {
        self.operation = operation
        self.entityType = entityType
        self.domainType = domainType
        self.startTime = startTime
        self.operationId = operationId
        self.batchSize = batchSize
    }
}

/// Performance statistics for a mapping operation type
public struct PerformanceStats {
    public let operation: MappingOperation
    public let count: Int
    public let averageDuration: CFAbsoluteTime
    public let minDuration: CFAbsoluteTime
    public let maxDuration: CFAbsoluteTime
    public let successRate: Double
    
    public var averageDurationMs: Int {
        return Int(averageDuration * 1000)
    }
    
    public var minDurationMs: Int {
        return Int(minDuration * 1000)
    }
    
    public var maxDurationMs: Int {
        return Int(maxDuration * 1000)
    }
    
    public var successRatePercentage: Int {
        return Int(successRate * 100)
    }
}
