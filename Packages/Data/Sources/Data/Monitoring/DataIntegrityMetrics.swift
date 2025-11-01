import Foundation
import os.log

/// Comprehensive metrics collection for data integrity checks
public final class DataIntegrityMetrics: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = DataIntegrityMetrics()
    
    private init() {}
    
    // MARK: - Dependencies
    
    private let integrityMonitor = DataIntegrityMonitor.shared
    private let metricsLogger = Logger(subsystem: "com.invoicingapp.data", category: "integrity-metrics")
    
    // MARK: - Metrics Storage
    
    private var integrityMetrics: [String: EntityIntegrityMetrics] = [:]
    private var issueMetrics: [String: IssueMetrics] = [:]
    private var trendMetrics: [String: TrendMetrics] = [:]
    private let metricsQueue = DispatchQueue(label: "integrity.metrics", attributes: .concurrent)
    
    // MARK: - Metrics Collection
    
    /// Record an integrity check execution
    /// - Parameters:
    ///   - entityType: The type of entity being checked
    ///   - checkType: The type of integrity check performed
    ///   - duration: Time taken for the check
    ///   - issuesFound: Number of issues found
    ///   - totalFieldsChecked: Total number of fields checked
    public func recordIntegrityCheck(
        entityType: String,
        checkType: IntegrityCheckType,
        duration: CFAbsoluteTime,
        issuesFound: Int,
        totalFieldsChecked: Int
    ) {
        metricsQueue.async(flags: .barrier) {
            self.updateEntityMetrics(
                entityType: entityType,
                checkType: checkType,
                duration: duration,
                issuesFound: issuesFound,
                totalFieldsChecked: totalFieldsChecked
            )
            
            self.updateIssueMetrics(
                entityType: entityType,
                checkType: checkType,
                issuesFound: issuesFound
            )
            
            self.updateTrendMetrics(
                entityType: entityType,
                checkType: checkType,
                issuesFound: issuesFound
            )
        }
    }
    
    /// Record a specific integrity issue
    /// - Parameters:
    ///   - entityType: The type of entity
    ///   - issueType: The type of integrity issue
    ///   - severity: The severity of the issue
    ///   - fieldName: The field where the issue was found
    ///   - entityId: The ID of the affected entity
    public func recordIntegrityIssue(
        entityType: String,
        issueType: DataIntegrityIssue,
        severity: IssueSeverity,
        fieldName: String?,
        entityId: String
    ) {
        metricsQueue.async(flags: .barrier) {
            let issueKey = "\(entityType)_\(issueType.rawValue)"
            
            if var metrics = self.issueMetrics[issueKey] {
                metrics.totalIssues += 1
                metrics.severityCounts[severity, default: 0] += 1
                metrics.fieldCounts[fieldName ?? "unknown", default: 0] += 1
                metrics.entityIds.insert(entityId)
                metrics.lastOccurrence = Date()
                self.issueMetrics[issueKey] = metrics
            } else {
                self.issueMetrics[issueKey] = IssueMetrics(
                    entityType: entityType,
                    issueType: issueType,
                    totalIssues: 1,
                    severityCounts: [severity: 1],
                    fieldCounts: [fieldName ?? "unknown": 1],
                    entityIds: Set([entityId]),
                    firstOccurrence: Date(),
                    lastOccurrence: Date()
                )
            }
            
            // Log significant issues
            if severity == .critical || severity == .high {
                self.metricsLogger.warning("""
                    Critical integrity issue recorded:
                    Entity: \(entityType)
                    Issue: \(issueType.rawValue)
                    Severity: \(severity.rawValue)
                    Field: \(fieldName ?? "unknown")
                    Entity ID: \(entityId)
                    """)
            }
        }
    }
    
    /// Record a data validation result
    /// - Parameters:
    ///   - entityType: The type of entity
    ///   - validationType: The type of validation performed
    ///   - isValid: Whether the validation passed
    ///   - errorMessage: Error message if validation failed
    public func recordValidationResult(
        entityType: String,
        validationType: ValidationType,
        isValid: Bool,
        errorMessage: String? = nil
    ) {
        metricsQueue.async(flags: .barrier) {
            let validationKey = "\(entityType)_\(validationType.rawValue)"
            
            if var metrics = self.integrityMetrics[validationKey] {
                metrics.totalValidations += 1
                if isValid {
                    metrics.passedValidations += 1
                } else {
                    metrics.failedValidations += 1
                    metrics.lastError = errorMessage
                }
                self.integrityMetrics[validationKey] = metrics
            } else {
                self.integrityMetrics[validationKey] = EntityIntegrityMetrics(
                    entityType: entityType,
                    checkType: .validation,
                    totalChecks: 1,
                    totalValidations: 1,
                    passedValidations: isValid ? 1 : 0,
                    failedValidations: isValid ? 0 : 1,
                    totalIssues: isValid ? 0 : 1,
                    totalDuration: 0,
                    totalFieldsChecked: 0,
                    lastError: errorMessage,
                    firstCheck: Date(),
                    lastCheck: Date()
                )
            }
        }
    }
    
    // MARK: - Metrics Retrieval
    
    /// Get comprehensive integrity metrics for an entity type
    /// - Parameter entityType: The entity type
    /// - Returns: Comprehensive integrity metrics
    public func getEntityIntegrityMetrics(for entityType: String) -> ComprehensiveIntegrityMetrics {
        return metricsQueue.sync {
            let entityMetrics = integrityMetrics.values.filter { $0.entityType == entityType }
            let issueMetrics = self.issueMetrics.values.filter { $0.entityType == entityType }
            let trendMetrics = self.trendMetrics.values.filter { $0.entityType == entityType }
            
            return ComprehensiveIntegrityMetrics(
                entityType: entityType,
                totalChecks: entityMetrics.reduce(0) { $0 + $1.totalChecks },
                totalValidations: entityMetrics.reduce(0) { $0 + $1.totalValidations },
                passedValidations: entityMetrics.reduce(0) { $0 + $1.passedValidations },
                failedValidations: entityMetrics.reduce(0) { $0 + $1.failedValidations },
                totalIssues: entityMetrics.reduce(0) { $0 + $1.totalIssues },
                averageCheckDuration: calculateAverageDuration(entityMetrics),
                totalFieldsChecked: entityMetrics.reduce(0) { $0 + $1.totalFieldsChecked },
                issueBreakdown: createIssueBreakdown(issueMetrics),
                trendAnalysis: createTrendAnalysis(trendMetrics),
                healthScore: calculateHealthScore(entityMetrics, issueMetrics),
                lastUpdated: Date()
            )
        }
    }
    
    /// Get all integrity metrics
    /// - Returns: Dictionary of comprehensive integrity metrics by entity type
    public func getAllIntegrityMetrics() -> [String: ComprehensiveIntegrityMetrics] {
        return metricsQueue.sync {
            let entityTypes = Set(integrityMetrics.values.map { $0.entityType })
            return Dictionary(uniqueKeysWithValues: entityTypes.map { entityType in
                (entityType, getEntityIntegrityMetrics(for: entityType))
            })
        }
    }
    
    /// Get issue metrics for a specific issue type
    /// - Parameter issueType: The type of integrity issue
    /// - Returns: Issue metrics for the specified issue type
    public func getIssueMetrics(for issueType: DataIntegrityIssue) -> [String: IssueMetrics] {
        return metricsQueue.sync {
            return issueMetrics.filter { $0.value.issueType == issueType }
        }
    }
    
    /// Get trend analysis for an entity type
    /// - Parameter entityType: The entity type
    /// - Returns: Trend analysis metrics
    public func getTrendAnalysis(for entityType: String) -> TrendAnalysis {
        return metricsQueue.sync {
            let entityTrends = trendMetrics.values.filter { $0.entityType == entityType }
            
            guard !entityTrends.isEmpty else {
                return TrendAnalysis(
                    entityType: entityType,
                    trendDirection: .stable,
                    trendStrength: 0.0,
                    averageIssuesPerCheck: 0.0,
                    trendPeriod: 0,
                    lastUpdated: Date()
                )
            }
            
            let totalIssues = entityTrends.reduce(0) { $0 + $1.issuesFound }
            let totalChecks = entityTrends.count
            let averageIssuesPerCheck = Double(totalIssues) / Double(totalChecks)
            
            let trendDirection = calculateTrendDirection(entityTrends)
            let trendStrength = calculateTrendStrength(entityTrends)
            
            return TrendAnalysis(
                entityType: entityType,
                trendDirection: trendDirection,
                trendStrength: trendStrength,
                averageIssuesPerCheck: averageIssuesPerCheck,
                trendPeriod: totalChecks,
                lastUpdated: Date()
            )
        }
    }
    
    /// Get integrity health score for an entity type
    /// - Parameter entityType: The entity type
    /// - Returns: Health score (0.0 to 1.0, where 1.0 is perfect health)
    public func getIntegrityHealthScore(for entityType: String) -> Double {
        return metricsQueue.sync {
            let entityMetrics = integrityMetrics.values.filter { $0.entityType == entityType }
            let issueMetrics = self.issueMetrics.values.filter { $0.entityType == entityType }
            return calculateHealthScore(entityMetrics, issueMetrics)
        }
    }
    
    // MARK: - Metrics Analysis
    
    /// Generate integrity report for an entity type
    /// - Parameter entityType: The entity type
    /// - Returns: Comprehensive integrity report
    public func generateIntegrityReport(for entityType: String) -> IntegrityReport {
        let metrics = getEntityIntegrityMetrics(for: entityType)
        let trendAnalysis = getTrendAnalysis(for: entityType)
        let healthScore = getIntegrityHealthScore(for: entityType)
        
        let recommendations = generateRecommendations(metrics: metrics, trendAnalysis: trendAnalysis)
        let riskAssessment = assessRisk(metrics: metrics, trendAnalysis: trendAnalysis)
        
        return IntegrityReport(
            entityType: entityType,
            generatedAt: Date(),
            metrics: metrics,
            trendAnalysis: trendAnalysis,
            healthScore: healthScore,
            riskAssessment: riskAssessment,
            recommendations: recommendations
        )
    }
    
    /// Generate comprehensive integrity dashboard data
    /// - Returns: Dashboard data with all integrity metrics
    public func generateDashboardData() -> IntegrityDashboardData {
        let allMetrics = getAllIntegrityMetrics()
        let overallHealthScore = calculateOverallHealthScore(allMetrics)
        let criticalIssues = identifyCriticalIssues()
        let trendingIssues = identifyTrendingIssues()
        
        return IntegrityDashboardData(
            overallHealthScore: overallHealthScore,
            entityMetrics: allMetrics,
            criticalIssues: criticalIssues,
            trendingIssues: trendingIssues,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Metrics Cleanup
    
    /// Clear old metrics data
    /// - Parameter olderThan: Remove metrics older than this date
    public func clearOldMetrics(olderThan date: Date = Date().addingTimeInterval(-3600)) {
        metricsQueue.async(flags: .barrier) {
            let cutoffTime = date.timeIntervalSince1970
            
            // Clear old entity metrics
            self.integrityMetrics = self.integrityMetrics.filter { _, metrics in
                metrics.lastCheck.timeIntervalSince1970 >= cutoffTime
            }
            
            // Clear old issue metrics
            self.issueMetrics = self.issueMetrics.filter { _, metrics in
                metrics.lastOccurrence.timeIntervalSince1970 >= cutoffTime
            }
            
            // Clear old trend metrics
            self.trendMetrics = self.trendMetrics.filter { _, metrics in
                metrics.timestamp.timeIntervalSince1970 >= cutoffTime
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateEntityMetrics(
        entityType: String,
        checkType: IntegrityCheckType,
        duration: CFAbsoluteTime,
        issuesFound: Int,
        totalFieldsChecked: Int
    ) {
        let key = "\(entityType)_\(checkType.rawValue)"
        
        if var metrics = integrityMetrics[key] {
            metrics.totalChecks += 1
            metrics.totalIssues += issuesFound
            metrics.totalDuration += duration
            metrics.totalFieldsChecked += totalFieldsChecked
            metrics.lastCheck = Date()
            integrityMetrics[key] = metrics
        } else {
            integrityMetrics[key] = EntityIntegrityMetrics(
                entityType: entityType,
                checkType: checkType,
                totalChecks: 1,
                totalValidations: 0,
                passedValidations: 0,
                failedValidations: 0,
                totalIssues: issuesFound,
                totalDuration: duration,
                totalFieldsChecked: totalFieldsChecked,
                lastError: nil,
                firstCheck: Date(),
                lastCheck: Date()
            )
        }
    }
    
    private func updateIssueMetrics(
        entityType: String,
        checkType: IntegrityCheckType,
        issuesFound: Int
    ) {
        let key = "\(entityType)_\(checkType.rawValue)_issues"
        
        if var metrics = issueMetrics[key] {
            metrics.totalIssues += issuesFound
            metrics.lastOccurrence = Date()
            issueMetrics[key] = metrics
        } else {
            issueMetrics[key] = IssueMetrics(
                entityType: entityType,
                issueType: .missingRequiredField, // Default, will be updated
                totalIssues: issuesFound,
                severityCounts: [:],
                fieldCounts: [:],
                entityIds: Set(),
                firstOccurrence: Date(),
                lastOccurrence: Date()
            )
        }
    }
    
    private func updateTrendMetrics(
        entityType: String,
        checkType: IntegrityCheckType,
        issuesFound: Int
    ) {
        let key = "\(entityType)_\(checkType.rawValue)_trend"
        
        if var metrics = trendMetrics[key] {
            metrics.issuesFound += issuesFound
            metrics.checkCount += 1
            metrics.timestamp = Date()
            trendMetrics[key] = metrics
        } else {
            trendMetrics[key] = TrendMetrics(
                entityType: entityType,
                checkType: checkType,
                issuesFound: issuesFound,
                checkCount: 1,
                timestamp: Date()
            )
        }
    }
    
    private func calculateAverageDuration(_ metrics: [EntityIntegrityMetrics]) -> CFAbsoluteTime {
        guard !metrics.isEmpty else { return 0 }
        let totalDuration = metrics.reduce(0) { $0 + $1.totalDuration }
        let totalChecks = metrics.reduce(0) { $0 + $1.totalChecks }
        return totalChecks > 0 ? totalDuration / Double(totalChecks) : 0
    }
    
    private func createIssueBreakdown(_ issueMetrics: [IssueMetrics]) -> [String: Int] {
        var breakdown: [String: Int] = [:]
        for metrics in issueMetrics {
            breakdown[metrics.issueType.rawValue] = metrics.totalIssues
        }
        return breakdown
    }
    
    private func createTrendAnalysis(_ trendMetrics: [TrendMetrics]) -> TrendAnalysis {
        guard !trendMetrics.isEmpty else {
            return TrendAnalysis(
                entityType: "unknown",
                trendDirection: .stable,
                trendStrength: 0.0,
                averageIssuesPerCheck: 0.0,
                trendPeriod: 0,
                lastUpdated: Date()
            )
        }
        
        let totalIssues = trendMetrics.reduce(0) { $0 + $1.issuesFound }
        let totalChecks = trendMetrics.reduce(0) { $0 + $1.checkCount }
        let averageIssuesPerCheck = Double(totalIssues) / Double(totalChecks)
        
        let trendDirection = calculateTrendDirection(trendMetrics)
        let trendStrength = calculateTrendStrength(trendMetrics)
        
        return TrendAnalysis(
            entityType: trendMetrics.first?.entityType ?? "unknown",
            trendDirection: trendDirection,
            trendStrength: trendStrength,
            averageIssuesPerCheck: averageIssuesPerCheck,
            trendPeriod: totalChecks,
            lastUpdated: Date()
        )
    }
    
    private func calculateHealthScore(_ entityMetrics: [EntityIntegrityMetrics], _ issueMetrics: [IssueMetrics]) -> Double {
        guard !entityMetrics.isEmpty else { return 1.0 }
        
        let totalChecks = entityMetrics.reduce(0) { $0 + $1.totalChecks }
        let totalIssues = entityMetrics.reduce(0) { $0 + $1.totalIssues }
        let totalValidations = entityMetrics.reduce(0) { $0 + $1.totalValidations }
        let passedValidations = entityMetrics.reduce(0) { $0 + $1.passedValidations }
        
        let issueRate = totalChecks > 0 ? Double(totalIssues) / Double(totalChecks) : 0.0
        let validationRate = totalValidations > 0 ? Double(passedValidations) / Double(totalValidations) : 1.0
        
        // Health score is based on low issue rate and high validation rate
        let healthScore = (1.0 - issueRate) * validationRate
        return max(0.0, min(1.0, healthScore))
    }
    
    private func calculateTrendDirection(_ trendMetrics: [TrendMetrics]) -> TrendDirection {
        guard trendMetrics.count >= 2 else { return .stable }
        
        let sortedMetrics = trendMetrics.sorted { $0.timestamp < $1.timestamp }
        let firstHalf = Array(sortedMetrics.prefix(sortedMetrics.count / 2))
        let secondHalf = Array(sortedMetrics.suffix(sortedMetrics.count / 2))
        
        let firstHalfAverage = Double(firstHalf.reduce(0) { $0 + $1.issuesFound }) / Double(firstHalf.count)
        let secondHalfAverage = Double(secondHalf.reduce(0) { $0 + $1.issuesFound }) / Double(secondHalf.count)
        
        if secondHalfAverage > firstHalfAverage * 1.1 {
            return .increasing
        } else if secondHalfAverage < firstHalfAverage * 0.9 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func calculateTrendStrength(_ trendMetrics: [TrendMetrics]) -> Double {
        guard trendMetrics.count >= 2 else { return 0.0 }
        
        let sortedMetrics = trendMetrics.sorted { $0.timestamp < $1.timestamp }
        let firstHalf = Array(sortedMetrics.prefix(sortedMetrics.count / 2))
        let secondHalf = Array(sortedMetrics.suffix(sortedMetrics.count / 2))
        
        let firstHalfAverage = Double(firstHalf.reduce(0) { $0 + $1.issuesFound }) / Double(firstHalf.count)
        let secondHalfAverage = Double(secondHalf.reduce(0) { $0 + $1.issuesFound }) / Double(secondHalf.count)
        
        if firstHalfAverage == 0 {
            return secondHalfAverage > 0 ? 1.0 : 0.0
        }
        
        let change = abs(secondHalfAverage - firstHalfAverage) / firstHalfAverage
        return min(1.0, change)
    }
    
    private func calculateOverallHealthScore(_ allMetrics: [String: ComprehensiveIntegrityMetrics]) -> Double {
        guard !allMetrics.isEmpty else { return 1.0 }
        
        let totalHealthScore = allMetrics.values.reduce(0.0) { $0 + $1.healthScore }
        return totalHealthScore / Double(allMetrics.count)
    }
    
    private func identifyCriticalIssues() -> [CriticalIssue] {
        return issueMetrics.values.compactMap { metrics in
            let criticalCount = metrics.severityCounts[.critical, default: 0]
            let highCount = metrics.severityCounts[.high, default: 0]
            
            if criticalCount > 0 || highCount > 5 {
                return CriticalIssue(
                    entityType: metrics.entityType,
                    issueType: metrics.issueType,
                    criticalCount: criticalCount,
                    highCount: highCount,
                    totalCount: metrics.totalIssues,
                    lastOccurrence: metrics.lastOccurrence
                )
            }
            return nil
        }
    }
    
    private func identifyTrendingIssues() -> [TrendingIssue] {
        return trendMetrics.values.compactMap { metrics in
            let trendDirection = calculateTrendDirection([metrics])
            if trendDirection == .increasing && metrics.issuesFound > 0 {
                return TrendingIssue(
                    entityType: metrics.entityType,
                    checkType: metrics.checkType,
                    issueCount: metrics.issuesFound,
                    trendDirection: trendDirection,
                    lastUpdated: metrics.timestamp
                )
            }
            return nil
        }
    }
    
    private func generateRecommendations(metrics: ComprehensiveIntegrityMetrics, trendAnalysis: TrendAnalysis) -> [IntegrityRecommendation] {
        var recommendations: [IntegrityRecommendation] = []
        
        if metrics.healthScore < 0.8 {
            recommendations.append(IntegrityRecommendation(
                type: .health,
                severity: .high,
                title: "Low Integrity Health Score",
                description: "Entity \(metrics.entityType) has a health score of \(Int(metrics.healthScore * 100))%",
                action: "Review and fix integrity issues to improve health score"
            ))
        }
        
        if trendAnalysis.trendDirection == .increasing {
            recommendations.append(IntegrityRecommendation(
                type: .trend,
                severity: .medium,
                title: "Increasing Issue Trend",
                description: "Issues in \(metrics.entityType) are trending upward",
                action: "Investigate root causes and implement preventive measures"
            ))
        }
        
        if metrics.failedValidations > metrics.passedValidations {
            recommendations.append(IntegrityRecommendation(
                type: .validation,
                severity: .high,
                title: "High Validation Failure Rate",
                description: "More validations are failing than passing for \(metrics.entityType)",
                action: "Review validation logic and data quality"
            ))
        }
        
        return recommendations
    }
    
    private func assessRisk(metrics: ComprehensiveIntegrityMetrics, trendAnalysis: TrendAnalysis) -> RiskAssessment {
        var riskLevel: RiskLevel = .low
        var riskFactors: [String] = []
        
        if metrics.healthScore < 0.5 {
            riskLevel = .high
            riskFactors.append("Very low health score")
        } else if metrics.healthScore < 0.8 {
            riskLevel = .medium
            riskFactors.append("Low health score")
        }
        
        if trendAnalysis.trendDirection == .increasing {
            riskLevel = max(riskLevel, .medium)
            riskFactors.append("Increasing issue trend")
        }
        
        if metrics.failedValidations > metrics.passedValidations {
            riskLevel = max(riskLevel, .high)
            riskFactors.append("High validation failure rate")
        }
        
        return RiskAssessment(
            riskLevel: riskLevel,
            riskFactors: riskFactors,
            assessedAt: Date()
        )
    }
}

// MARK: - Supporting Types

/// Types of integrity checks
public enum IntegrityCheckType: String, CaseIterable, Sendable {
    case requiredFields = "Required Fields"
    case dataTypes = "Data Types"
    case formats = "Formats"
    case relationships = "Relationships"
    case corruption = "Corruption"
    case validation = "Validation"
    case comprehensive = "Comprehensive"
}

/// Types of validation
public enum ValidationType: String, CaseIterable, Sendable {
    case fieldValidation = "Field Validation"
    case formatValidation = "Format Validation"
    case businessRuleValidation = "Business Rule Validation"
    case relationshipValidation = "Relationship Validation"
    case dataConsistencyValidation = "Data Consistency Validation"
}

/// Issue severity levels
public enum IssueSeverity: String, CaseIterable, Comparable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    public static func < (lhs: IssueSeverity, rhs: IssueSeverity) -> Bool {
        let levels: [IssueSeverity] = [.low, .medium, .high, .critical]
        guard let lhsIndex = levels.firstIndex(of: lhs),
              let rhsIndex = levels.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

/// Trend directions
public enum TrendDirection: String, CaseIterable {
    case increasing = "Increasing"
    case decreasing = "Decreasing"
    case stable = "Stable"
}

/// Risk levels
public enum RiskLevel: String, CaseIterable, Comparable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        let levels: [RiskLevel] = [.low, .medium, .high, .critical]
        guard let lhsIndex = levels.firstIndex(of: lhs),
              let rhsIndex = levels.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

/// Entity integrity metrics
private struct EntityIntegrityMetrics {
    let entityType: String
    let checkType: IntegrityCheckType
    var totalChecks: Int
    var totalValidations: Int
    var passedValidations: Int
    var failedValidations: Int
    var totalIssues: Int
    var totalDuration: CFAbsoluteTime
    var totalFieldsChecked: Int
    var lastError: String?
    let firstCheck: Date
    var lastCheck: Date
}

/// Issue metrics
public struct IssueMetrics: Sendable {
    let entityType: String
    let issueType: DataIntegrityIssue
    var totalIssues: Int
    var severityCounts: [IssueSeverity: Int]
    var fieldCounts: [String: Int]
    var entityIds: Set<String>
    let firstOccurrence: Date
    var lastOccurrence: Date
}

/// Trend metrics
private struct TrendMetrics {
    let entityType: String
    let checkType: IntegrityCheckType
    var issuesFound: Int
    var checkCount: Int
    var timestamp: Date
}

/// Comprehensive integrity metrics
public struct ComprehensiveIntegrityMetrics {
    public let entityType: String
    public let totalChecks: Int
    public let totalValidations: Int
    public let passedValidations: Int
    public let failedValidations: Int
    public let totalIssues: Int
    public let averageCheckDuration: CFAbsoluteTime
    public let totalFieldsChecked: Int
    public let issueBreakdown: [String: Int]
    public let trendAnalysis: TrendAnalysis
    public let healthScore: Double
    public let lastUpdated: Date
    
    public var averageCheckDurationMs: Int {
        return Int(averageCheckDuration * 1000)
    }
    
    public var healthScorePercentage: Int {
        return Int(healthScore * 100)
    }
    
    public var validationSuccessRate: Double {
        return totalValidations > 0 ? Double(passedValidations) / Double(totalValidations) : 1.0
    }
    
    public var validationSuccessRatePercentage: Int {
        return Int(validationSuccessRate * 100)
    }
    
    public var issueRate: Double {
        return totalChecks > 0 ? Double(totalIssues) / Double(totalChecks) : 0.0
    }
    
    public var issueRatePercentage: Int {
        return Int(issueRate * 100)
    }
}

/// Trend analysis
public struct TrendAnalysis {
    public let entityType: String
    public let trendDirection: TrendDirection
    public let trendStrength: Double
    public let averageIssuesPerCheck: Double
    public let trendPeriod: Int
    public let lastUpdated: Date
    
    public var trendStrengthPercentage: Int {
        return Int(trendStrength * 100)
    }
}

/// Critical issue
public struct CriticalIssue {
    public let entityType: String
    public let issueType: DataIntegrityIssue
    public let criticalCount: Int
    public let highCount: Int
    public let totalCount: Int
    public let lastOccurrence: Date
}

/// Trending issue
public struct TrendingIssue {
    public let entityType: String
    public let checkType: IntegrityCheckType
    public let issueCount: Int
    public let trendDirection: TrendDirection
    public let lastUpdated: Date
}

/// Integrity recommendation
public struct IntegrityRecommendation {
    public let type: RecommendationType
    public let severity: IssueSeverity
    public let title: String
    public let description: String
    public let action: String
}

/// Risk assessment
public struct RiskAssessment {
    public let riskLevel: RiskLevel
    public let riskFactors: [String]
    public let assessedAt: Date
}

/// Integrity report
public struct IntegrityReport {
    public let entityType: String
    public let generatedAt: Date
    public let metrics: ComprehensiveIntegrityMetrics
    public let trendAnalysis: TrendAnalysis
    public let healthScore: Double
    public let riskAssessment: RiskAssessment
    public let recommendations: [IntegrityRecommendation]
}

/// Integrity dashboard data
public struct IntegrityDashboardData {
    public let overallHealthScore: Double
    public let entityMetrics: [String: ComprehensiveIntegrityMetrics]
    public let criticalIssues: [CriticalIssue]
    public let trendingIssues: [TrendingIssue]
    public let lastUpdated: Date
    
    public var overallHealthScorePercentage: Int {
        return Int(overallHealthScore * 100)
    }
}
