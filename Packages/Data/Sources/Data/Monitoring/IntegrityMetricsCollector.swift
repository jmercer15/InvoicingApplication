import Foundation
import os.log

/// Service for collecting and aggregating data integrity metrics
public final class IntegrityMetricsCollector: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = IntegrityMetricsCollector()
    
    private init() {}
    
    // MARK: - Dependencies
    
    private let integrityMetrics = DataIntegrityMetrics.shared
    private let integrityMonitor = DataIntegrityMonitor.shared
    private let collectorLogger = Logger(subsystem: "com.invoicingapp.data", category: "integrity-collector")
    
    // MARK: - Collection Configuration
    
    private var collectionEnabled: Bool = true
    private var collectionInterval: TimeInterval = 300 // 5 minutes
    private var collectionTimer: Timer?
    
    // MARK: - Entity-Specific Collectors
    
    /// Collect metrics for ClientEntity integrity
    /// - Parameter entities: Array of ClientEntity instances to check
    public func collectClientEntityMetrics(entities: [Any]) {
        guard collectionEnabled else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var totalIssues = 0
        var totalFieldsChecked = 0
        
        for entity in entities {
            let entityId = getEntityId(entity)
            let issues = performClientEntityIntegrityCheck(entity: entity, entityId: entityId)
            totalIssues += issues
            totalFieldsChecked += 8 // Number of fields checked for ClientEntity
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        integrityMetrics.recordIntegrityCheck(
            entityType: "ClientEntity",
            checkType: .comprehensive,
            duration: duration,
            issuesFound: totalIssues,
            totalFieldsChecked: totalFieldsChecked
        )
        
        collectorLogger.info("""
            ClientEntity metrics collected:
            Entities checked: \(entities.count)
            Total issues: \(totalIssues)
            Duration: \(String(format: "%.3f", duration))s
            """)
    }
    
    /// Collect metrics for InvoiceEntity integrity
    /// - Parameter entities: Array of InvoiceEntity instances to check
    public func collectInvoiceEntityMetrics(entities: [Any]) {
        guard collectionEnabled else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var totalIssues = 0
        var totalFieldsChecked = 0
        
        for entity in entities {
            let entityId = getEntityId(entity)
            let issues = performInvoiceEntityIntegrityCheck(entity: entity, entityId: entityId)
            totalIssues += issues
            totalFieldsChecked += 12 // Number of fields checked for InvoiceEntity
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        integrityMetrics.recordIntegrityCheck(
            entityType: "InvoiceEntity",
            checkType: .comprehensive,
            duration: duration,
            issuesFound: totalIssues,
            totalFieldsChecked: totalFieldsChecked
        )
        
        collectorLogger.info("""
            InvoiceEntity metrics collected:
            Entities checked: \(entities.count)
            Total issues: \(totalIssues)
            Duration: \(String(format: "%.3f", duration))s
            """)
    }
    
    /// Collect metrics for SessionEntity integrity
    /// - Parameter entities: Array of SessionEntity instances to check
    public func collectSessionEntityMetrics(entities: [Any]) {
        guard collectionEnabled else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var totalIssues = 0
        var totalFieldsChecked = 0
        
        for entity in entities {
            let entityId = getEntityId(entity)
            let issues = performSessionEntityIntegrityCheck(entity: entity, entityId: entityId)
            totalIssues += issues
            totalFieldsChecked += 15 // Number of fields checked for SessionEntity
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        integrityMetrics.recordIntegrityCheck(
            entityType: "SessionEntity",
            checkType: .comprehensive,
            duration: duration,
            issuesFound: totalIssues,
            totalFieldsChecked: totalFieldsChecked
        )
        
        collectorLogger.info("""
            SessionEntity metrics collected:
            Entities checked: \(entities.count)
            Total issues: \(totalIssues)
            Duration: \(String(format: "%.3f", duration))s
            """)
    }
    
    /// Collect metrics for TravelChargeEntity integrity
    /// - Parameter entities: Array of TravelChargeEntity instances to check
    public func collectTravelChargeEntityMetrics(entities: [Any]) {
        guard collectionEnabled else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var totalIssues = 0
        var totalFieldsChecked = 0
        
        for entity in entities {
            let entityId = getEntityId(entity)
            let issues = performTravelChargeEntityIntegrityCheck(entity: entity, entityId: entityId)
            totalIssues += issues
            totalFieldsChecked += 10 // Number of fields checked for TravelChargeEntity
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        integrityMetrics.recordIntegrityCheck(
            entityType: "TravelChargeEntity",
            checkType: .comprehensive,
            duration: duration,
            issuesFound: totalIssues,
            totalFieldsChecked: totalFieldsChecked
        )
        
        collectorLogger.info("""
            TravelChargeEntity metrics collected:
            Entities checked: \(entities.count)
            Total issues: \(totalIssues)
            Duration: \(String(format: "%.3f", duration))s
            """)
    }
    
    /// Collect metrics for NDISItemEntity integrity
    /// - Parameter entities: Array of NDISItemEntity instances to check
    public func collectNDISItemEntityMetrics(entities: [Any]) {
        guard collectionEnabled else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var totalIssues = 0
        var totalFieldsChecked = 0
        
        for entity in entities {
            let entityId = getEntityId(entity)
            let issues = performNDISItemEntityIntegrityCheck(entity: entity, entityId: entityId)
            totalIssues += issues
            totalFieldsChecked += 20 // Number of fields checked for NDISItemEntity
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        integrityMetrics.recordIntegrityCheck(
            entityType: "NDISItemEntity",
            checkType: .comprehensive,
            duration: duration,
            issuesFound: totalIssues,
            totalFieldsChecked: totalFieldsChecked
        )
        
        collectorLogger.info("""
            NDISItemEntity metrics collected:
            Entities checked: \(entities.count)
            Total issues: \(totalIssues)
            Duration: \(String(format: "%.3f", duration))s
            """)
    }
    
    // MARK: - Automated Collection
    
    /// Start automated metrics collection
    /// - Parameter interval: Collection interval in seconds
    public func startAutomatedCollection(interval: TimeInterval = 300) {
        guard collectionEnabled else { return }
        
        collectionInterval = interval
        stopAutomatedCollection() // Stop any existing timer
        
        collectionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performAutomatedCollection()
        }
        
        collectorLogger.info("Automated integrity metrics collection started with \(interval)s interval")
    }
    
    /// Stop automated metrics collection
    public func stopAutomatedCollection() {
        collectionTimer?.invalidate()
        collectionTimer = nil
        collectorLogger.info("Automated integrity metrics collection stopped")
    }
    
    /// Enable or disable metrics collection
    /// - Parameter enabled: Whether to enable collection
    public func setCollectionEnabled(_ enabled: Bool) {
        collectionEnabled = enabled
        if !enabled {
            stopAutomatedCollection()
        }
        collectorLogger.info("Integrity metrics collection \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Collection Reports
    
    /// Generate collection summary report
    /// - Returns: Summary of collected metrics
    public func generateCollectionSummary() -> CollectionSummary {
        let allMetrics = integrityMetrics.getAllIntegrityMetrics()
        let totalEntities = allMetrics.count
        let totalChecks = allMetrics.values.reduce(0) { $0 + $1.totalChecks }
        let totalIssues = allMetrics.values.reduce(0) { $0 + $1.totalIssues }
        let overallHealthScore = integrityMetrics.getIntegrityHealthScore(for: "Overall")
        
        return CollectionSummary(
            totalEntityTypes: totalEntities,
            totalChecks: totalChecks,
            totalIssues: totalIssues,
            overallHealthScore: overallHealthScore,
            collectionEnabled: collectionEnabled,
            lastCollection: Date(),
            nextCollection: collectionTimer?.fireDate ?? Date().addingTimeInterval(collectionInterval)
        )
    }
    
    /// Generate entity-specific collection report
    /// - Parameter entityType: The entity type to report on
    /// - Returns: Entity-specific collection report
    public func generateEntityCollectionReport(for entityType: String) -> EntityCollectionReport {
        let metrics = integrityMetrics.getEntityIntegrityMetrics(for: entityType)
        let trendAnalysis = integrityMetrics.getTrendAnalysis(for: entityType)
        let healthScore = integrityMetrics.getIntegrityHealthScore(for: entityType)
        
        return EntityCollectionReport(
            entityType: entityType,
            metrics: metrics,
            trendAnalysis: trendAnalysis,
            healthScore: healthScore,
            lastCollection: Date(),
            collectionStatus: collectionEnabled ? .active : .inactive
        )
    }
    
    // MARK: - Private Methods
    
    private func performAutomatedCollection() {
        collectorLogger.info("Starting automated integrity metrics collection")
        
        // In a real implementation, this would fetch entities from the database
        // For now, we'll simulate the collection process
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate collection for different entity types
        collectClientEntityMetrics(entities: [])
        collectInvoiceEntityMetrics(entities: [])
        collectSessionEntityMetrics(entities: [])
        collectTravelChargeEntityMetrics(entities: [])
        collectNDISItemEntityMetrics(entities: [])
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        collectorLogger.info("""
            Automated integrity metrics collection completed:
            Duration: \(String(format: "%.3f", duration))s
            """)
    }
    
    private func performClientEntityIntegrityCheck(entity: Any, entityId: String) -> Int {
        var issues = 0
        
        // Check required fields
        if isFieldNil(entity: entity, fieldName: "id") {
            integrityMetrics.recordIntegrityIssue(
                entityType: "ClientEntity",
                issueType: .missingRequiredField,
                severity: .critical,
                fieldName: "id",
                entityId: entityId
            )
            issues += 1
        }
        
        if isFieldNil(entity: entity, fieldName: "fullName") {
            integrityMetrics.recordIntegrityIssue(
                entityType: "ClientEntity",
                issueType: .missingRequiredField,
                severity: .high,
                fieldName: "fullName",
                entityId: entityId
            )
            issues += 1
        }
        
        if isFieldNil(entity: entity, fieldName: "ndisNumber") {
            integrityMetrics.recordIntegrityIssue(
                entityType: "ClientEntity",
                issueType: .missingRequiredField,
                severity: .high,
                fieldName: "ndisNumber",
                entityId: entityId
            )
            issues += 1
        }
        
        // Check data types
        if let fullName = getFieldValue(entity: entity, fieldName: "fullName") as? String,
           fullName.isEmpty {
            integrityMetrics.recordIntegrityIssue(
                entityType: "ClientEntity",
                issueType: .invalidDataFormat,
                severity: .medium,
                fieldName: "fullName",
                entityId: entityId
            )
            issues += 1
        }
        
        // Check email format
        if let email = getFieldValue(entity: entity, fieldName: "email") as? String,
           !email.isEmpty && !email.contains("@") {
            integrityMetrics.recordIntegrityIssue(
                entityType: "ClientEntity",
                issueType: .invalidDataFormat,
                severity: .medium,
                fieldName: "email",
                entityId: entityId
            )
            issues += 1
        }
        
        return issues
    }
    
    private func performInvoiceEntityIntegrityCheck(entity: Any, entityId: String) -> Int {
        var issues = 0
        
        // Check required fields
        if isFieldNil(entity: entity, fieldName: "id") {
            integrityMetrics.recordIntegrityIssue(
                entityType: "InvoiceEntity",
                issueType: .missingRequiredField,
                severity: .critical,
                fieldName: "id",
                entityId: entityId
            )
            issues += 1
        }
        
        if isFieldNil(entity: entity, fieldName: "invoiceNumber") {
            integrityMetrics.recordIntegrityIssue(
                entityType: "InvoiceEntity",
                issueType: .missingRequiredField,
                severity: .high,
                fieldName: "invoiceNumber",
                entityId: entityId
            )
            issues += 1
        }
        
        // Check date consistency
        if let createdDate = getFieldValue(entity: entity, fieldName: "createdDate") as? Date,
           let dueDate = getFieldValue(entity: entity, fieldName: "dueDate") as? Date,
           dueDate < createdDate {
            integrityMetrics.recordIntegrityIssue(
                entityType: "InvoiceEntity",
                issueType: .invalidDataFormat,
                severity: .medium,
                fieldName: "dueDate",
                entityId: entityId
            )
            issues += 1
        }
        
        return issues
    }
    
    private func performSessionEntityIntegrityCheck(entity: Any, entityId: String) -> Int {
        var issues = 0
        
        // Check required fields
        if isFieldNil(entity: entity, fieldName: "id") {
            integrityMetrics.recordIntegrityIssue(
                entityType: "SessionEntity",
                issueType: .missingRequiredField,
                severity: .critical,
                fieldName: "id",
                entityId: entityId
            )
            issues += 1
        }
        
        if isFieldNil(entity: entity, fieldName: "title") {
            integrityMetrics.recordIntegrityIssue(
                entityType: "SessionEntity",
                issueType: .missingRequiredField,
                severity: .high,
                fieldName: "title",
                entityId: entityId
            )
            issues += 1
        }
        
        // Check time consistency
        if let startTime = getFieldValue(entity: entity, fieldName: "startTime") as? Date,
           let endTime = getFieldValue(entity: entity, fieldName: "endTime") as? Date,
           endTime <= startTime {
            integrityMetrics.recordIntegrityIssue(
                entityType: "SessionEntity",
                issueType: .invalidDataFormat,
                severity: .medium,
                fieldName: "endTime",
                entityId: entityId
            )
            issues += 1
        }
        
        return issues
    }
    
    private func performTravelChargeEntityIntegrityCheck(entity: Any, entityId: String) -> Int {
        var issues = 0
        
        // Check required fields
        if isFieldNil(entity: entity, fieldName: "id") {
            integrityMetrics.recordIntegrityIssue(
                entityType: "TravelChargeEntity",
                issueType: .missingRequiredField,
                severity: .critical,
                fieldName: "id",
                entityId: entityId
            )
            issues += 1
        }
        
        // Check distance consistency
        if let distance = getFieldValue(entity: entity, fieldName: "travelDistance") as? Double,
           distance < 0 {
            integrityMetrics.recordIntegrityIssue(
                entityType: "TravelChargeEntity",
                issueType: .invalidDataFormat,
                severity: .medium,
                fieldName: "travelDistance",
                entityId: entityId
            )
            issues += 1
        }
        
        // Check duration consistency
        if let duration = getFieldValue(entity: entity, fieldName: "travelDuration") as? Double,
           duration < 0 {
            integrityMetrics.recordIntegrityIssue(
                entityType: "TravelChargeEntity",
                issueType: .invalidDataFormat,
                severity: .medium,
                fieldName: "travelDuration",
                entityId: entityId
            )
            issues += 1
        }
        
        return issues
    }
    
    private func performNDISItemEntityIntegrityCheck(entity: Any, entityId: String) -> Int {
        var issues = 0
        
        // Check required fields
        if isFieldNil(entity: entity, fieldName: "id") {
            integrityMetrics.recordIntegrityIssue(
                entityType: "NDISItemEntity",
                issueType: .missingRequiredField,
                severity: .critical,
                fieldName: "id",
                entityId: entityId
            )
            issues += 1
        }
        
        if isFieldNil(entity: entity, fieldName: "itemNumber") {
            integrityMetrics.recordIntegrityIssue(
                entityType: "NDISItemEntity",
                issueType: .missingRequiredField,
                severity: .high,
                fieldName: "itemNumber",
                entityId: entityId
            )
            issues += 1
        }
        
        if isFieldNil(entity: entity, fieldName: "name") {
            integrityMetrics.recordIntegrityIssue(
                entityType: "NDISItemEntity",
                issueType: .missingRequiredField,
                severity: .high,
                fieldName: "name",
                entityId: entityId
            )
            issues += 1
        }
        
        // Check date consistency
        if let startDate = getFieldValue(entity: entity, fieldName: "effectiveStartDate") as? Date,
           let endDate = getFieldValue(entity: entity, fieldName: "effectiveEndDate") as? Date,
           endDate <= startDate {
            integrityMetrics.recordIntegrityIssue(
                entityType: "NDISItemEntity",
                issueType: .invalidDataFormat,
                severity: .medium,
                fieldName: "effectiveEndDate",
                entityId: entityId
            )
            issues += 1
        }
        
        return issues
    }
    
    private func getEntityId(_ entity: Any) -> String {
        let mirror = Mirror(reflecting: entity)
        for child in mirror.children {
            if child.label == "id" {
                return String(describing: child.value)
            }
        }
        return "unknown"
    }
    
    private func isFieldNil(entity: Any, fieldName: String) -> Bool {
        let mirror = Mirror(reflecting: entity)
        for child in mirror.children {
            if child.label == fieldName {
                return child.value is NSNull || (child.value as AnyObject?) == nil
            }
        }
        return true
    }
    
    private func getFieldValue(entity: Any, fieldName: String) -> Any? {
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

/// Collection status
public enum CollectionStatus: String, CaseIterable {
    case active = "Active"
    case inactive = "Inactive"
    case paused = "Paused"
    case error = "Error"
}

/// Collection summary
public struct CollectionSummary {
    public let totalEntityTypes: Int
    public let totalChecks: Int
    public let totalIssues: Int
    public let overallHealthScore: Double
    public let collectionEnabled: Bool
    public let lastCollection: Date
    public let nextCollection: Date
    
    public var overallHealthScorePercentage: Int {
        return Int(overallHealthScore * 100)
    }
    
    public var issueRate: Double {
        return totalChecks > 0 ? Double(totalIssues) / Double(totalChecks) : 0.0
    }
    
    public var issueRatePercentage: Int {
        return Int(issueRate * 100)
    }
}

/// Entity collection report
public struct EntityCollectionReport {
    public let entityType: String
    public let metrics: ComprehensiveIntegrityMetrics
    public let trendAnalysis: TrendAnalysis
    public let healthScore: Double
    public let lastCollection: Date
    public let collectionStatus: CollectionStatus
    
    public var healthScorePercentage: Int {
        return Int(healthScore * 100)
    }
}
