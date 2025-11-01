import Foundation
import os.log

/// Service for generating and formatting integrity metrics reports
public final class IntegrityMetricsReporter: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = IntegrityMetricsReporter()
    
    private init() {}
    
    // MARK: - Dependencies
    
    private let integrityMetrics = DataIntegrityMetrics.shared
    private let metricsCollector = IntegrityMetricsCollector.shared
    private let reporterLogger = Logger(subsystem: "com.invoicingapp.data", category: "integrity-reporter")
    
    // MARK: - Report Generation
    
    /// Generate a comprehensive integrity report
    /// - Parameter entityType: Optional entity type to focus on
    /// - Returns: Comprehensive integrity report
    public func generateComprehensiveReport(for entityType: String? = nil) -> ComprehensiveIntegrityReport {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let allMetrics = integrityMetrics.getAllIntegrityMetrics()
        let dashboardData = integrityMetrics.generateDashboardData()
        let collectionSummary = metricsCollector.generateCollectionSummary()
        
        let report = ComprehensiveIntegrityReport(
            generatedAt: Date(),
            entityType: entityType,
            overallHealthScore: dashboardData.overallHealthScore,
            totalEntityTypes: allMetrics.count,
            totalChecks: allMetrics.values.reduce(0) { $0 + $1.totalChecks },
            totalIssues: allMetrics.values.reduce(0) { $0 + $1.totalIssues },
            criticalIssues: dashboardData.criticalIssues,
            trendingIssues: dashboardData.trendingIssues,
            entityMetrics: entityType != nil ? [entityType!: allMetrics[entityType!]!] : allMetrics,
            collectionSummary: collectionSummary,
            recommendations: generateOverallRecommendations(dashboardData: dashboardData),
            riskAssessment: assessOverallRisk(dashboardData: dashboardData)
        )
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        reporterLogger.info("""
            Comprehensive integrity report generated:
            Entity type: \(entityType ?? "All")
            Duration: \(String(format: "%.3f", duration))s
            """)
        
        return report
    }
    
    /// Generate a summary report for console output
    /// - Returns: Formatted summary report string
    public func generateSummaryReport() -> String {
        let dashboardData = integrityMetrics.generateDashboardData()
        let collectionSummary = metricsCollector.generateCollectionSummary()
        
        var report = """
        ========================================
        DATA INTEGRITY SUMMARY REPORT
        ========================================
        Generated: \(DateFormatter.reportFormatter.string(from: Date()))
        
        OVERALL HEALTH SCORE: \(Int(dashboardData.overallHealthScore * 100))%
        
        ENTITY METRICS:
        """
        
        for (entityType, metrics) in dashboardData.entityMetrics {
            report += """
            
            \(entityType):
              Health Score: \(metrics.healthScorePercentage)%
              Total Checks: \(metrics.totalChecks)
              Total Issues: \(metrics.totalIssues)
              Issue Rate: \(metrics.issueRatePercentage)%
              Validation Success: \(metrics.validationSuccessRatePercentage)%
              Average Check Duration: \(metrics.averageCheckDurationMs)ms
            """
        }
        
        report += """
        
        
        CRITICAL ISSUES: \(dashboardData.criticalIssues.count)
        """
        
        for issue in dashboardData.criticalIssues {
            report += """
            
            - \(issue.entityType): \(issue.issueType.rawValue)
              Critical: \(issue.criticalCount), High: \(issue.highCount)
              Total: \(issue.totalCount)
              Last Occurrence: \(DateFormatter.reportFormatter.string(from: issue.lastOccurrence))
            """
        }
        
        report += """
        
        
        TRENDING ISSUES: \(dashboardData.trendingIssues.count)
        """
        
        for issue in dashboardData.trendingIssues {
            report += """
            
            - \(issue.entityType): \(issue.checkType.rawValue)
              Issue Count: \(issue.issueCount)
              Trend: \(issue.trendDirection.rawValue)
              Last Updated: \(DateFormatter.reportFormatter.string(from: issue.lastUpdated))
            """
        }
        
        report += """
        
        
        COLLECTION STATUS:
        Collection Enabled: \(collectionSummary.collectionEnabled ? "Yes" : "No")
        Total Entity Types: \(collectionSummary.totalEntityTypes)
        Total Checks: \(collectionSummary.totalChecks)
        Total Issues: \(collectionSummary.totalIssues)
        Issue Rate: \(collectionSummary.issueRatePercentage)%
        Last Collection: \(DateFormatter.reportFormatter.string(from: collectionSummary.lastCollection))
        Next Collection: \(DateFormatter.reportFormatter.string(from: collectionSummary.nextCollection))
        
        ========================================
        """
        
        return report
    }
    
    /// Generate a detailed report for a specific entity type
    /// - Parameter entityType: The entity type to report on
    /// - Returns: Detailed entity report
    public func generateEntityReport(for entityType: String) -> EntityIntegrityReport {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let metrics = integrityMetrics.getEntityIntegrityMetrics(for: entityType)
        let trendAnalysis = integrityMetrics.getTrendAnalysis(for: entityType)
        let healthScore = integrityMetrics.getIntegrityHealthScore(for: entityType)
        let collectionReport = metricsCollector.generateEntityCollectionReport(for: entityType)
        
        let report = EntityIntegrityReport(
            entityType: entityType,
            generatedAt: Date(),
            metrics: metrics,
            trendAnalysis: trendAnalysis,
            healthScore: healthScore,
            collectionReport: collectionReport,
            recommendations: generateEntityRecommendations(metrics: metrics, trendAnalysis: trendAnalysis),
            riskAssessment: assessEntityRisk(metrics: metrics, trendAnalysis: trendAnalysis)
        )
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        reporterLogger.info("""
            Entity integrity report generated:
            Entity type: \(entityType)
            Duration: \(String(format: "%.3f", duration))s
            """)
        
        return report
    }
    
    /// Generate a trend analysis report
    /// - Returns: Trend analysis report
    public func generateTrendAnalysisReport() -> TrendAnalysisReport {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let allMetrics = integrityMetrics.getAllIntegrityMetrics()
        var trendData: [String: TrendAnalysis] = [:]
        
        for entityType in allMetrics.keys {
            trendData[entityType] = integrityMetrics.getTrendAnalysis(for: entityType)
        }
        
        let report = TrendAnalysisReport(
            generatedAt: Date(),
            trendData: trendData,
            overallTrend: calculateOverallTrend(trendData: trendData),
            recommendations: generateTrendRecommendations(trendData: trendData)
        )
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        reporterLogger.info("""
            Trend analysis report generated:
            Duration: \(String(format: "%.3f", duration))s
            """)
        
        return report
    }
    
    /// Generate a performance report
    /// - Returns: Performance report
    public func generatePerformanceReport() -> IntegrityPerformanceReport {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let allMetrics = integrityMetrics.getAllIntegrityMetrics()
        let collectionSummary = metricsCollector.generateCollectionSummary()
        
        let report = IntegrityPerformanceReport(
            generatedAt: Date(),
            totalChecks: allMetrics.values.reduce(0) { $0 + $1.totalChecks },
            totalDuration: allMetrics.values.reduce(0) { $0 + $1.averageCheckDuration },
            averageCheckDuration: calculateAverageCheckDuration(allMetrics),
            slowestEntityType: findSlowestEntityType(allMetrics),
            fastestEntityType: findFastestEntityType(allMetrics),
            collectionPerformance: assessCollectionPerformance(collectionSummary),
            recommendations: generatePerformanceRecommendations(allMetrics: allMetrics)
        )
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        reporterLogger.info("""
            Performance report generated:
            Duration: \(String(format: "%.3f", duration))s
            """)
        
        return report
    }
    
    /// Export report to file
    /// - Parameters:
    ///   - report: The report to export
    ///   - format: The export format
    ///   - filePath: The file path to save to
    public func exportReport(_ report: Any, format: ExportFormat, to filePath: String) throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let content: String
        switch format {
        case .json:
            content = try exportToJSONAny(report)
        case .csv:
            content = try exportToCSV(report)
        case .text:
            content = try exportToText(report)
        case .html:
            content = try exportToHTML(report)
        }
        
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        reporterLogger.info("""
            Report exported:
            Format: \(format.rawValue)
            File: \(filePath)
            Duration: \(String(format: "%.3f", duration))s
            """)
    }
    
    // MARK: - Private Methods
    
    private func generateOverallRecommendations(dashboardData: IntegrityDashboardData) -> [IntegrityRecommendation] {
        var recommendations: [IntegrityRecommendation] = []
        
        if dashboardData.overallHealthScore < 0.8 {
            recommendations.append(IntegrityRecommendation(
                type: .health,
                severity: .high,
                title: "Low Overall Health Score",
                description: "Overall data integrity health score is \(Int(dashboardData.overallHealthScore * 100))%",
                action: "Review and address critical issues across all entity types"
            ))
        }
        
        if !dashboardData.criticalIssues.isEmpty {
            recommendations.append(IntegrityRecommendation(
                type: .integrity,
                severity: .critical,
                title: "Critical Issues Detected",
                description: "\(dashboardData.criticalIssues.count) critical issues require immediate attention",
                action: "Address critical issues immediately to prevent data corruption"
            ))
        }
        
        if !dashboardData.trendingIssues.isEmpty {
            recommendations.append(IntegrityRecommendation(
                type: .trend,
                severity: .medium,
                title: "Trending Issues",
                description: "\(dashboardData.trendingIssues.count) issues are trending upward",
                action: "Investigate root causes and implement preventive measures"
            ))
        }
        
        return recommendations
    }
    
    private func assessOverallRisk(dashboardData: IntegrityDashboardData) -> RiskAssessment {
        var riskLevel: RiskLevel = .low
        var riskFactors: [String] = []
        
        if dashboardData.overallHealthScore < 0.5 {
            riskLevel = .critical
            riskFactors.append("Very low overall health score")
        } else if dashboardData.overallHealthScore < 0.8 {
            riskLevel = .high
            riskFactors.append("Low overall health score")
        }
        
        if !dashboardData.criticalIssues.isEmpty {
            riskLevel = max(riskLevel, .critical)
            riskFactors.append("Critical issues present")
        }
        
        if !dashboardData.trendingIssues.isEmpty {
            riskLevel = max(riskLevel, .medium)
            riskFactors.append("Trending issues detected")
        }
        
        return RiskAssessment(
            riskLevel: riskLevel,
            riskFactors: riskFactors,
            assessedAt: Date()
        )
    }
    
    private func generateEntityRecommendations(metrics: ComprehensiveIntegrityMetrics, trendAnalysis: TrendAnalysis) -> [IntegrityRecommendation] {
        var recommendations: [IntegrityRecommendation] = []
        
        if metrics.healthScore < 0.8 {
            recommendations.append(IntegrityRecommendation(
                type: .health,
                severity: .high,
                title: "Low Entity Health Score",
                description: "\(metrics.entityType) has a health score of \(metrics.healthScorePercentage)%",
                action: "Review and fix integrity issues for this entity type"
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
    
    private func assessEntityRisk(metrics: ComprehensiveIntegrityMetrics, trendAnalysis: TrendAnalysis) -> RiskAssessment {
        var riskLevel: RiskLevel = .low
        var riskFactors: [String] = []
        
        if metrics.healthScore < 0.5 {
            riskLevel = .critical
            riskFactors.append("Very low health score")
        } else if metrics.healthScore < 0.8 {
            riskLevel = .high
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
    
    private func calculateOverallTrend(trendData: [String: TrendAnalysis]) -> TrendDirection {
        let increasingCount = trendData.values.filter { $0.trendDirection == .increasing }.count
        let decreasingCount = trendData.values.filter { $0.trendDirection == .decreasing }.count
        let stableCount = trendData.values.filter { $0.trendDirection == .stable }.count
        
        if increasingCount > decreasingCount && increasingCount > stableCount {
            return .increasing
        } else if decreasingCount > increasingCount && decreasingCount > stableCount {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func generateTrendRecommendations(trendData: [String: TrendAnalysis]) -> [IntegrityRecommendation] {
        var recommendations: [IntegrityRecommendation] = []
        
        let increasingTrends = trendData.filter { $0.value.trendDirection == .increasing }
        if !increasingTrends.isEmpty {
            recommendations.append(IntegrityRecommendation(
                type: .trend,
                severity: .medium,
                title: "Multiple Increasing Trends",
                description: "\(increasingTrends.count) entity types show increasing issue trends",
                action: "Investigate common root causes and implement preventive measures"
            ))
        }
        
        return recommendations
    }
    
    private func calculateAverageCheckDuration(_ allMetrics: [String: ComprehensiveIntegrityMetrics]) -> CFAbsoluteTime {
        guard !allMetrics.isEmpty else { return 0 }
        let totalDuration = allMetrics.values.reduce(0) { $0 + $1.averageCheckDuration }
        return totalDuration / Double(allMetrics.count)
    }
    
    private func findSlowestEntityType(_ allMetrics: [String: ComprehensiveIntegrityMetrics]) -> String? {
        return allMetrics.max { $0.value.averageCheckDuration < $1.value.averageCheckDuration }?.key
    }
    
    private func findFastestEntityType(_ allMetrics: [String: ComprehensiveIntegrityMetrics]) -> String? {
        return allMetrics.min { $0.value.averageCheckDuration < $1.value.averageCheckDuration }?.key
    }
    
    private func assessCollectionPerformance(_ collectionSummary: CollectionSummary) -> CollectionPerformance {
        let issueRate = collectionSummary.issueRate
        let healthScore = collectionSummary.overallHealthScore
        
        var performance: CollectionPerformanceLevel = .excellent
        if issueRate > 0.2 || healthScore < 0.8 {
            performance = .poor
        } else if issueRate > 0.1 || healthScore < 0.9 {
            performance = .fair
        } else if issueRate > 0.05 || healthScore < 0.95 {
            performance = .good
        }
        
        return CollectionPerformance(
            level: performance,
            issueRate: issueRate,
            healthScore: healthScore,
            totalChecks: collectionSummary.totalChecks,
            assessedAt: Date()
        )
    }
    
    private func generatePerformanceRecommendations(allMetrics: [String: ComprehensiveIntegrityMetrics]) -> [IntegrityRecommendation] {
        var recommendations: [IntegrityRecommendation] = []
        
        let slowestEntity = findSlowestEntityType(allMetrics)
        if let slowest = slowestEntity,
           let metrics = allMetrics[slowest],
           metrics.averageCheckDuration > 1.0 {
            recommendations.append(IntegrityRecommendation(
                type: .performance,
                severity: .medium,
                title: "Slow Integrity Checks",
                description: "\(slowest) has the slowest average check duration: \(metrics.averageCheckDurationMs)ms",
                action: "Optimize integrity check logic for this entity type"
            ))
        }
        
        return recommendations
    }
    
    private func exportToJSON<T: Encodable>(_ report: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(report)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func exportToJSONAny(_ report: Any) throws -> String {
        // Try to convert to JSON using JSONSerialization for Any type
        let data = try JSONSerialization.data(withJSONObject: report, options: .prettyPrinted)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func exportToCSV(_ report: Any) throws -> String {
        // Implementation would depend on the specific report type
        // For now, return a placeholder
        return "CSV export not implemented"
    }
    
    private func exportToText(_ report: Any) throws -> String {
        if report is ComprehensiveIntegrityReport {
            return generateSummaryReport()
        }
        return "Text export not implemented for this report type"
    }
    
    private func exportToHTML(_ report: Any) throws -> String {
        // Implementation would depend on the specific report type
        // For now, return a placeholder
        return "HTML export not implemented"
    }
}

// MARK: - Supporting Types

/// Export formats
public enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"
    case text = "Text"
    case html = "HTML"
}

/// Collection performance levels
public enum CollectionPerformanceLevel: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
}

/// Collection performance
public struct CollectionPerformance {
    public let level: CollectionPerformanceLevel
    public let issueRate: Double
    public let healthScore: Double
    public let totalChecks: Int
    public let assessedAt: Date
    
    public var issueRatePercentage: Int {
        return Int(issueRate * 100)
    }
    
    public var healthScorePercentage: Int {
        return Int(healthScore * 100)
    }
}

/// Comprehensive integrity report
public struct ComprehensiveIntegrityReport {
    public let generatedAt: Date
    public let entityType: String?
    public let overallHealthScore: Double
    public let totalEntityTypes: Int
    public let totalChecks: Int
    public let totalIssues: Int
    public let criticalIssues: [CriticalIssue]
    public let trendingIssues: [TrendingIssue]
    public let entityMetrics: [String: ComprehensiveIntegrityMetrics]
    public let collectionSummary: CollectionSummary
    public let recommendations: [IntegrityRecommendation]
    public let riskAssessment: RiskAssessment
    
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

/// Entity integrity report
public struct EntityIntegrityReport {
    public let entityType: String
    public let generatedAt: Date
    public let metrics: ComprehensiveIntegrityMetrics
    public let trendAnalysis: TrendAnalysis
    public let healthScore: Double
    public let collectionReport: EntityCollectionReport
    public let recommendations: [IntegrityRecommendation]
    public let riskAssessment: RiskAssessment
    
    public var healthScorePercentage: Int {
        return Int(healthScore * 100)
    }
}

/// Trend analysis report
public struct TrendAnalysisReport {
    public let generatedAt: Date
    public let trendData: [String: TrendAnalysis]
    public let overallTrend: TrendDirection
    public let recommendations: [IntegrityRecommendation]
}

/// Integrity performance report
public struct IntegrityPerformanceReport {
    public let generatedAt: Date
    public let totalChecks: Int
    public let totalDuration: CFAbsoluteTime
    public let averageCheckDuration: CFAbsoluteTime
    public let slowestEntityType: String?
    public let fastestEntityType: String?
    public let collectionPerformance: CollectionPerformance
    public let recommendations: [IntegrityRecommendation]
    
    public var totalDurationMs: Int {
        return Int(totalDuration * 1000)
    }
    
    public var averageCheckDurationMs: Int {
        return Int(averageCheckDuration * 1000)
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let reportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
