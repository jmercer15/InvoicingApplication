import Foundation
import os.log

/// Monitor for tracking data integrity issues and consistency checks
public final class DataIntegrityMonitor: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = DataIntegrityMonitor()
    
    private init() {}
    
    // MARK: - Logging
    
    private let integrityLogger = Logger(subsystem: "com.invoicingapp.data", category: "data-integrity")
    private let performanceLogger = MappingPerformanceLogger.shared
    
    // MARK: - Integrity Metrics
    
    private var integrityMetrics: [String: IntegrityMetrics] = [:]
    private let metricsQueue = DispatchQueue(label: "integrity.metrics", attributes: .concurrent)
    
    // MARK: - Data Integrity Checks
    
    /// Check for missing required fields in an entity
    /// - Parameters:
    ///   - entity: The entity to check
    ///   - requiredFields: List of required field names
    ///   - entityType: The type of entity being checked
    public func checkRequiredFields<T>(
        entity: T,
        requiredFields: [String],
        entityType: String
    ) {
        let entityId = getEntityId(entity)
        var missingFields: [String] = []
        
        for field in requiredFields {
            if isFieldNil(entity: entity, fieldName: field) {
                missingFields.append(field)
            }
        }
        
        if !missingFields.isEmpty {
            let details = "Missing required fields: \(missingFields.joined(separator: ", "))"
            performanceLogger.logDataIntegrityIssue(
                issue: .missingRequiredField,
                entityType: entityType,
                entityId: entityId,
                details: details
            )
            
            logIntegrityIssue(
                issue: .missingRequiredField,
                entityType: entityType,
                entityId: entityId,
                details: details
            )
        }
    }
    
    /// Check for data type mismatches
    /// - Parameters:
    ///   - entity: The entity to check
    ///   - fieldChecks: Dictionary of field names to expected types
    ///   - entityType: The type of entity being checked
    public func checkDataTypes<T>(
        entity: T,
        fieldChecks: [String: String],
        entityType: String
    ) {
        let entityId = getEntityId(entity)
        
        for (fieldName, expectedType) in fieldChecks {
            if let actualType = getFieldType(entity: entity, fieldName: fieldName),
               actualType != expectedType {
                let details = "Field '\(fieldName)' expected type '\(expectedType)' but got '\(actualType)'"
                performanceLogger.logDataIntegrityIssue(
                    issue: .typeMismatch,
                    entityType: entityType,
                    entityId: entityId,
                    details: details
                )
                
                logIntegrityIssue(
                    issue: .typeMismatch,
                    entityType: entityType,
                    entityId: entityId,
                    details: details
                )
            }
        }
    }
    
    /// Check for invalid data formats
    /// - Parameters:
    ///   - entity: The entity to check
    ///   - formatChecks: Dictionary of field names to validation closures
    ///   - entityType: The type of entity being checked
    public func checkDataFormats<T>(
        entity: T,
        formatChecks: [String: (Any?) -> Bool],
        entityType: String
    ) {
        let entityId = getEntityId(entity)
        
        for (fieldName, validation) in formatChecks {
            let fieldValue = getFieldValue(entity: entity, fieldName: fieldName)
            if !validation(fieldValue) {
                let details = "Field '\(fieldName)' has invalid format: \(String(describing: fieldValue))"
                performanceLogger.logDataIntegrityIssue(
                    issue: .invalidDataFormat,
                    entityType: entityType,
                    entityId: entityId,
                    details: details
                )
                
                logIntegrityIssue(
                    issue: .invalidDataFormat,
                    entityType: entityType,
                    entityId: entityId,
                    details: details
                )
            }
        }
    }
    
    /// Check for relationship integrity
    /// - Parameters:
    ///   - entity: The entity to check
    ///   - relationshipChecks: Dictionary of relationship names to validation closures
    ///   - entityType: The type of entity being checked
    public func checkRelationships<T>(
        entity: T,
        relationshipChecks: [String: (Any?) -> Bool],
        entityType: String
    ) {
        let entityId = getEntityId(entity)
        
        for (relationshipName, validation) in relationshipChecks {
            let relationshipValue = getFieldValue(entity: entity, fieldName: relationshipName)
            if !validation(relationshipValue) {
                let details = "Relationship '\(relationshipName)' is invalid: \(String(describing: relationshipValue))"
                performanceLogger.logDataIntegrityIssue(
                    issue: .relationshipNotFound,
                    entityType: entityType,
                    entityId: entityId,
                    details: details
                )
                
                logIntegrityIssue(
                    issue: .relationshipNotFound,
                    entityType: entityType,
                    entityId: entityId,
                    details: details
                )
            }
        }
    }
    
    /// Check for data corruption indicators
    /// - Parameters:
    ///   - entity: The entity to check
    ///   - corruptionChecks: Dictionary of field names to corruption detection closures
    ///   - entityType: The type of entity being checked
    public func checkDataCorruption<T>(
        entity: T,
        corruptionChecks: [String: (Any?) -> Bool],
        entityType: String
    ) {
        let entityId = getEntityId(entity)
        
        for (fieldName, corruptionCheck) in corruptionChecks {
            let fieldValue = getFieldValue(entity: entity, fieldName: fieldName)
            if corruptionCheck(fieldValue) {
                let details = "Field '\(fieldName)' shows signs of data corruption: \(String(describing: fieldValue))"
                performanceLogger.logDataIntegrityIssue(
                    issue: .dataCorruption,
                    entityType: entityType,
                    entityId: entityId,
                    details: details
                )
                
                logIntegrityIssue(
                    issue: .dataCorruption,
                    entityType: entityType,
                    entityId: entityId,
                    details: details
                )
            }
        }
    }
    
    // MARK: - Comprehensive Integrity Check
    
    /// Perform a comprehensive integrity check on an entity
    /// - Parameters:
    ///   - entity: The entity to check
    ///   - checks: The integrity checks to perform
    ///   - entityType: The type of entity being checked
    public func performIntegrityCheck<T>(
        entity: T,
        checks: IntegrityChecks,
        entityType: String
    ) {
        let entityId = getEntityId(entity)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        integrityLogger.info("Starting integrity check for \(entityType) (ID: \(entityId))")
        
        // Perform all checks
        if let requiredFields = checks.requiredFields {
            checkRequiredFields(entity: entity, requiredFields: requiredFields, entityType: entityType)
        }
        
        if let fieldChecks = checks.fieldChecks {
            checkDataTypes(entity: entity, fieldChecks: fieldChecks, entityType: entityType)
        }
        
        if let formatChecks = checks.formatChecks {
            checkDataFormats(entity: entity, formatChecks: formatChecks, entityType: entityType)
        }
        
        if let relationshipChecks = checks.relationshipChecks {
            checkRelationships(entity: entity, relationshipChecks: relationshipChecks, entityType: entityType)
        }
        
        if let corruptionChecks = checks.corruptionChecks {
            checkDataCorruption(entity: entity, corruptionChecks: corruptionChecks, entityType: entityType)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Log completion
        integrityLogger.info("""
            Integrity check completed for \(entityType) (ID: \(entityId))
            Duration: \(String(format: "%.3f", duration))s
            """)
        
        // Update metrics
        updateIntegrityMetrics(entityType: entityType, duration: duration)
    }
    
    // MARK: - Metrics and Statistics
    
    /// Get integrity statistics for a specific entity type
    /// - Parameter entityType: The entity type
    /// - Returns: Integrity statistics
    public func getIntegrityStats(for entityType: String) -> IntegrityStats {
        return metricsQueue.sync {
            guard let metrics = integrityMetrics[entityType] else {
                return IntegrityStats(entityType: entityType, checkCount: 0, averageDuration: 0, issueCount: 0)
            }
            
            return IntegrityStats(
                entityType: entityType,
                checkCount: metrics.checkCount,
                averageDuration: metrics.totalDuration / Double(metrics.checkCount),
                issueCount: metrics.issueCount
            )
        }
    }
    
    /// Get all integrity statistics
    /// - Returns: Dictionary of integrity statistics by entity type
    public func getAllIntegrityStats() -> [String: IntegrityStats] {
        return metricsQueue.sync {
            return Dictionary(uniqueKeysWithValues: integrityMetrics.map { (entityType, metrics) in
                (entityType, IntegrityStats(
                    entityType: entityType,
                    checkCount: metrics.checkCount,
                    averageDuration: metrics.totalDuration / Double(metrics.checkCount),
                    issueCount: metrics.issueCount
                ))
            })
        }
    }
    
    /// Clear old integrity metrics
    /// - Parameter olderThan: Remove metrics older than this date
    public func clearOldMetrics(olderThan date: Date = Date().addingTimeInterval(-3600)) {
        metricsQueue.async(flags: .barrier) {
            // For now, we'll keep all metrics as they're not time-based
            // In a real implementation, you might want to add timestamps
        }
    }
    
    // MARK: - Private Methods
    
    private func logIntegrityIssue(
        issue: DataIntegrityIssue,
        entityType: String,
        entityId: String,
        details: String
    ) {
        integrityLogger.warning("""
            Data integrity issue: \(issue.rawValue)
            Entity: \(entityType) (ID: \(entityId))
            Details: \(details)
            """)
    }
    
    private func updateIntegrityMetrics(entityType: String, duration: CFAbsoluteTime) {
        metricsQueue.async(flags: .barrier) {
            if var metrics = self.integrityMetrics[entityType] {
                metrics.checkCount += 1
                metrics.totalDuration += duration
                self.integrityMetrics[entityType] = metrics
            } else {
                self.integrityMetrics[entityType] = IntegrityMetrics(
                    checkCount: 1,
                    totalDuration: duration,
                    issueCount: 0
                )
            }
        }
    }
    
    private func getEntityId<T>(_ entity: T) -> String {
        // Try to get ID using reflection
        let mirror = Mirror(reflecting: entity)
        for child in mirror.children {
            if child.label == "id" {
                return String(describing: child.value)
            }
        }
        return "unknown"
    }
    
    private func isFieldNil<T>(entity: T, fieldName: String) -> Bool {
        let mirror = Mirror(reflecting: entity)
        for child in mirror.children {
            if child.label == fieldName {
                return child.value is NSNull || (child.value as AnyObject?) == nil
            }
        }
        return true
    }
    
    private func getFieldType<T>(entity: T, fieldName: String) -> String? {
        let mirror = Mirror(reflecting: entity)
        for child in mirror.children {
            if child.label == fieldName {
                return String(describing: type(of: child.value))
            }
        }
        return nil
    }
    
    private func getFieldValue<T>(entity: T, fieldName: String) -> Any? {
        let mirror = Mirror(reflecting: entity)
        for child in mirror.children {
            if child.label == fieldName {
                return child.value
            }
        }
        return nil
    }
}

// MARK: - Supporting Types

/// Configuration for integrity checks
public struct IntegrityChecks {
    public let requiredFields: [String]?
    public let fieldChecks: [String: String]?
    public let formatChecks: [String: (Any?) -> Bool]?
    public let relationshipChecks: [String: (Any?) -> Bool]?
    public let corruptionChecks: [String: (Any?) -> Bool]?
    
    public init(
        requiredFields: [String]? = nil,
        fieldChecks: [String: String]? = nil,
        formatChecks: [String: (Any?) -> Bool]? = nil,
        relationshipChecks: [String: (Any?) -> Bool]? = nil,
        corruptionChecks: [String: (Any?) -> Bool]? = nil
    ) {
        self.requiredFields = requiredFields
        self.fieldChecks = fieldChecks
        self.formatChecks = formatChecks
        self.relationshipChecks = relationshipChecks
        self.corruptionChecks = corruptionChecks
    }
}

/// Integrity metrics for tracking
private struct IntegrityMetrics {
    var checkCount: Int
    var totalDuration: CFAbsoluteTime
    var issueCount: Int
}

/// Integrity statistics
public struct IntegrityStats {
    public let entityType: String
    public let checkCount: Int
    public let averageDuration: CFAbsoluteTime
    public let issueCount: Int
    
    public var averageDurationMs: Int {
        return Int(averageDuration * 1000)
    }
    
    public var issueRate: Double {
        return checkCount > 0 ? Double(issueCount) / Double(checkCount) : 0.0
    }
    
    public var issueRatePercentage: Int {
        return Int(issueRate * 100)
    }
}
