import Foundation
import os.log

/// Health metric for tracking entity health
public struct HealthMetric: Sendable {
    public let entityType: String
    public let healthScore: Double
    public let lastUpdated: Date
    public let issues: [String]
    
    public init(entityType: String, healthScore: Double, lastUpdated: Date, issues: [String] = []) {
        self.entityType = entityType
        self.healthScore = healthScore
        self.lastUpdated = lastUpdated
        self.issues = issues
    }
}

/// Dashboard for monitoring data layer health and performance
public final class DataLayerHealthDashboard: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = DataLayerHealthDashboard()
    
    private init() {}
    
    // MARK: - Dependencies
    
    private let performanceLogger = MappingPerformanceLogger.shared
    private let integrityMonitor = DataIntegrityMonitor.shared
    private let dashboardLogger = Logger(subsystem: "com.invoicingapp.data", category: "health-dashboard")
    
    // MARK: - Health Metrics
    
    private var healthMetrics: [String: HealthMetric] = [:]
    private let metricsQueue = DispatchQueue(label: "health.metrics", attributes: .concurrent)
    
    // MARK: - Health Status
    
    /// Get overall data layer health status
    /// - Returns: Current health status
    public func getHealthStatus() -> DataLayerHealthStatus {
        let performanceStats = performanceLogger.getAllPerformanceStats()
        let integrityStats = integrityMonitor.getAllIntegrityStats()
        
        let overallHealth = calculateOverallHealth(
            performanceStats: performanceStats,
            integrityStats: integrityStats
        )
        
        return DataLayerHealthStatus(
            overallHealth: overallHealth,
            performanceHealth: calculatePerformanceHealth(performanceStats),
            integrityHealth: calculateIntegrityHealth(integrityStats),
            lastUpdated: Date(),
            performanceStats: performanceStats,
            integrityStats: integrityStats
        )
    }
    
    /// Get health status for a specific entity type
    /// - Parameter entityType: The entity type to check
    /// - Returns: Health status for the entity type
    public func getHealthStatus(for entityType: String) -> EntityHealthStatus {
        let performanceStats = performanceLogger.getPerformanceStats(for: .entityToDomain)
        let integrityStats = integrityMonitor.getIntegrityStats(for: entityType)
        
        let health = calculateEntityHealth(
            performanceStats: performanceStats,
            integrityStats: integrityStats
        )
        
        return EntityHealthStatus(
            entityType: entityType,
            health: health,
            performanceStats: performanceStats,
            integrityStats: integrityStats,
            lastUpdated: Date()
        )
    }
    
    /// Get performance summary
    /// - Returns: Performance summary with key metrics
    public func getPerformanceSummary() -> PerformanceSummary {
        let allStats = performanceLogger.getAllPerformanceStats()
        
        let totalOperations = allStats.values.reduce(0) { $0 + $1.count }
        let averageDuration = allStats.values.reduce(0.0) { $0 + $1.averageDuration } / Double(allStats.count)
        let successRate = allStats.values.reduce(0.0) { $0 + $1.successRate } / Double(allStats.count)
        
        let slowOperations = allStats.values.filter { $0.averageDuration > 1.0 }.count
        let failedOperations = allStats.values.filter { $0.successRate < 0.95 }.count
        
        return PerformanceSummary(
            totalOperations: totalOperations,
            averageDuration: averageDuration,
            successRate: successRate,
            slowOperations: slowOperations,
            failedOperations: failedOperations,
            lastUpdated: Date()
        )
    }
    
    /// Get integrity summary
    /// - Returns: Integrity summary with key metrics
    public func getIntegritySummary() -> IntegritySummary {
        let allStats = integrityMonitor.getAllIntegrityStats()
        
        let totalChecks = allStats.values.reduce(0) { $0 + $1.checkCount }
        let totalIssues = allStats.values.reduce(0) { $0 + $1.issueCount }
        let averageCheckDuration = allStats.values.reduce(0.0) { $0 + $1.averageDuration } / Double(allStats.count)
        
        let issueRate = totalChecks > 0 ? Double(totalIssues) / Double(totalChecks) : 0.0
        let entitiesWithIssues = allStats.values.filter { $0.issueCount > 0 }.count
        
        return IntegritySummary(
            totalChecks: totalChecks,
            totalIssues: totalIssues,
            issueRate: issueRate,
            averageCheckDuration: averageCheckDuration,
            entitiesWithIssues: entitiesWithIssues,
            lastUpdated: Date()
        )
    }
    
    /// Get health recommendations
    /// - Returns: List of health recommendations
    public func getHealthRecommendations() -> [HealthRecommendation] {
        var recommendations: [HealthRecommendation] = []
        
        let performanceStats = performanceLogger.getAllPerformanceStats()
        let integrityStats = integrityMonitor.getAllIntegrityStats()
        
        // Performance recommendations
        for (operation, stats) in performanceStats {
            if stats.averageDuration > 1.0 {
                recommendations.append(HealthRecommendation(
                    type: .performance,
                    severity: .warning,
                    title: "Slow Mapping Operation",
                    description: "\(operation.rawValue) operations are taking \(String(format: "%.3f", stats.averageDuration))s on average",
                    action: "Consider optimizing the mapping logic or adding caching"
                ))
            }
            
            if stats.successRate < 0.95 {
                recommendations.append(HealthRecommendation(
                    type: .reliability,
                    severity: .error,
                    title: "High Failure Rate",
                    description: "\(operation.rawValue) operations have a \(Int((1 - stats.successRate) * 100))% failure rate",
                    action: "Investigate and fix the underlying issues causing failures"
                ))
            }
        }
        
        // Integrity recommendations
        for (entityType, stats) in integrityStats {
            if stats.issueRate > 0.1 {
                recommendations.append(HealthRecommendation(
                    type: .integrity,
                    severity: .warning,
                    title: "Data Integrity Issues",
                    description: "\(entityType) has a \(Int(stats.issueRate * 100))% issue rate",
                    action: "Review and fix data integrity issues"
                ))
            }
        }
        
        return recommendations
    }
    
    /// Generate health report
    /// - Returns: Comprehensive health report
    public func generateHealthReport() -> HealthReport {
        let healthStatus = getHealthStatus()
        let performanceSummary = getPerformanceSummary()
        let integritySummary = getIntegritySummary()
        let recommendations = getHealthRecommendations()
        
        return HealthReport(
            generatedAt: Date(),
            healthStatus: healthStatus,
            performanceSummary: performanceSummary,
            integritySummary: integritySummary,
            recommendations: recommendations
        )
    }
    
    /// Log health status to console
    public func logHealthStatus() {
        let healthStatus = getHealthStatus()
        let performanceSummary = getPerformanceSummary()
        let integritySummary = getIntegritySummary()
        
        dashboardLogger.info("""
            Data Layer Health Status:
            Overall Health: \(healthStatus.overallHealth.rawValue)
            Performance Health: \(healthStatus.performanceHealth.rawValue)
            Integrity Health: \(healthStatus.integrityHealth.rawValue)
            
            Performance Summary:
            Total Operations: \(performanceSummary.totalOperations)
            Average Duration: \(String(format: "%.3f", performanceSummary.averageDuration))s
            Success Rate: \(Int(performanceSummary.successRate * 100))%
            Slow Operations: \(performanceSummary.slowOperations)
            Failed Operations: \(performanceSummary.failedOperations)
            
            Integrity Summary:
            Total Checks: \(integritySummary.totalChecks)
            Total Issues: \(integritySummary.totalIssues)
            Issue Rate: \(Int(integritySummary.issueRate * 100))%
            Average Check Duration: \(String(format: "%.3f", integritySummary.averageCheckDuration))s
            Entities with Issues: \(integritySummary.entitiesWithIssues)
            """)
    }
    
    // MARK: - Private Methods
    
    private func calculateOverallHealth(
        performanceStats: [MappingOperation: PerformanceStats],
        integrityStats: [String: IntegrityStats]
    ) -> HealthLevel {
        let performanceHealth = calculatePerformanceHealth(performanceStats)
        let integrityHealth = calculateIntegrityHealth(integrityStats)
        
        // Overall health is the worst of the two
        if performanceHealth == .critical || integrityHealth == .critical {
            return .critical
        } else if performanceHealth == .warning || integrityHealth == .warning {
            return .warning
        } else {
            return .healthy
        }
    }
    
    private func calculatePerformanceHealth(_ stats: [MappingOperation: PerformanceStats]) -> HealthLevel {
        guard !stats.isEmpty else { return .healthy }
        
        let averageSuccessRate = stats.values.reduce(0.0) { $0 + $1.successRate } / Double(stats.count)
        let averageDuration = stats.values.reduce(0.0) { $0 + $1.averageDuration } / Double(stats.count)
        
        if averageSuccessRate < 0.9 || averageDuration > 2.0 {
            return .critical
        } else if averageSuccessRate < 0.95 || averageDuration > 1.0 {
            return .warning
        } else {
            return .healthy
        }
    }
    
    private func calculateIntegrityHealth(_ stats: [String: IntegrityStats]) -> HealthLevel {
        guard !stats.isEmpty else { return .healthy }
        
        let averageIssueRate = stats.values.reduce(0.0) { $0 + $1.issueRate } / Double(stats.count)
        
        if averageIssueRate > 0.2 {
            return .critical
        } else if averageIssueRate > 0.1 {
            return .warning
        } else {
            return .healthy
        }
    }
    
    private func calculateEntityHealth(
        performanceStats: PerformanceStats,
        integrityStats: IntegrityStats
    ) -> HealthLevel {
        let performanceHealth = calculatePerformanceHealth([.entityToDomain: performanceStats])
        let integrityHealth = calculateIntegrityHealth([integrityStats.entityType: integrityStats])
        
        if performanceHealth == .critical || integrityHealth == .critical {
            return .critical
        } else if performanceHealth == .warning || integrityHealth == .warning {
            return .warning
        } else {
            return .healthy
        }
    }
}

// MARK: - Supporting Types

/// Health levels
public enum HealthLevel: String, CaseIterable {
    case healthy = "Healthy"
    case warning = "Warning"
    case critical = "Critical"
    case error = "Error"
}

/// Data layer health status
public struct DataLayerHealthStatus {
    public let overallHealth: HealthLevel
    public let performanceHealth: HealthLevel
    public let integrityHealth: HealthLevel
    public let lastUpdated: Date
    public let performanceStats: [MappingOperation: PerformanceStats]
    public let integrityStats: [String: IntegrityStats]
}

/// Entity health status
public struct EntityHealthStatus {
    public let entityType: String
    public let health: HealthLevel
    public let performanceStats: PerformanceStats
    public let integrityStats: IntegrityStats
    public let lastUpdated: Date
}

/// Performance summary
public struct PerformanceSummary {
    public let totalOperations: Int
    public let averageDuration: CFAbsoluteTime
    public let successRate: Double
    public let slowOperations: Int
    public let failedOperations: Int
    public let lastUpdated: Date
    
    public var averageDurationMs: Int {
        return Int(averageDuration * 1000)
    }
    
    public var successRatePercentage: Int {
        return Int(successRate * 100)
    }
}

/// Integrity summary
public struct IntegritySummary {
    public let totalChecks: Int
    public let totalIssues: Int
    public let issueRate: Double
    public let averageCheckDuration: CFAbsoluteTime
    public let entitiesWithIssues: Int
    public let lastUpdated: Date
    
    public var issueRatePercentage: Int {
        return Int(issueRate * 100)
    }
    
    public var averageCheckDurationMs: Int {
        return Int(averageCheckDuration * 1000)
    }
}

/// Health recommendation
public struct HealthRecommendation {
    public let type: RecommendationType
    public let severity: HealthLevel
    public let title: String
    public let description: String
    public let action: String
}

/// Recommendation types
public enum RecommendationType: String, CaseIterable, Sendable {
    case performance = "Performance"
    case reliability = "Reliability"
    case integrity = "Integrity"
    case security = "Security"
    case health = "Health"
    case trend = "Trend"
    case validation = "Validation"
}

/// Comprehensive health report
public struct HealthReport {
    public let generatedAt: Date
    public let healthStatus: DataLayerHealthStatus
    public let performanceSummary: PerformanceSummary
    public let integritySummary: IntegritySummary
    public let recommendations: [HealthRecommendation]
    
    public var hasIssues: Bool {
        return healthStatus.overallHealth != .healthy || !recommendations.isEmpty
    }
    
    public var criticalIssues: [HealthRecommendation] {
        return recommendations.filter { $0.severity == .critical }
    }
    
    public var warningIssues: [HealthRecommendation] {
        return recommendations.filter { $0.severity == .warning }
    }
}
