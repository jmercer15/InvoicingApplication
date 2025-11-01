import Foundation
import os.log

/// Manager for coordinating alerts across the data layer monitoring system
public final class AlertManager: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = AlertManager()
    
    private init() {}
    
    // MARK: - Dependencies
    
    private let alerting = DataIntegrityAlerting.shared
    private let integrityMetrics = DataIntegrityMetrics.shared
    private let performanceLogger = MappingPerformanceLogger.shared
    private let managerLogger = Logger(subsystem: "com.invoicingapp.data", category: "alert-manager")
    
    // MARK: - Alert Monitoring
    
    private var monitoringEnabled: Bool = true
    private var monitoringTimer: Timer?
    private var monitoringInterval: TimeInterval = 60 // 1 minute
    
    // MARK: - Alert Monitoring
    
    /// Start automated alert monitoring
    /// - Parameter interval: Monitoring interval in seconds
    public func startMonitoring(interval: TimeInterval = 60) {
        guard monitoringEnabled else { return }
        
        monitoringInterval = interval
        stopMonitoring() // Stop any existing timer
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performMonitoring()
        }
        
        managerLogger.info("Alert monitoring started with \(interval)s interval")
    }
    
    /// Stop automated alert monitoring
    public func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        managerLogger.info("Alert monitoring stopped")
    }
    
    /// Enable or disable alert monitoring
    /// - Parameter enabled: Whether to enable monitoring
    public func setMonitoringEnabled(_ enabled: Bool) {
        monitoringEnabled = enabled
        if !enabled {
            stopMonitoring()
        }
        managerLogger.info("Alert monitoring \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Performance Monitoring
    
    /// Monitor mapping performance and generate alerts
    public func monitorMappingPerformance() {
        let performanceStats = performanceLogger.getAllPerformanceStats()
        
        for (operation, stats) in performanceStats {
            // Check for slow operations
            if stats.averageDuration > 2.0 {
                alerting.alertPerformanceIssue(
                    operation: operation,
                    duration: stats.averageDuration,
                    threshold: 2.0,
                    context: "Average duration exceeds threshold"
                )
            }
            
            // Check for high failure rates
            if stats.successRate < 0.95 {
                alerting.alertMappingFailure(
                    operation: operation,
                    entityType: "Unknown",
                    domainType: "Unknown",
                    error: NSError(domain: "MappingPerformance", code: 1001, userInfo: [
                        NSLocalizedDescriptionKey: "High failure rate: \(Int((1 - stats.successRate) * 100))%"
                    ]),
                    context: "Success rate below threshold"
                )
            }
        }
    }
    
    /// Monitor data integrity and generate alerts
    public func monitorDataIntegrity() {
        let allMetrics = integrityMetrics.getAllIntegrityMetrics()
        
        for (entityType, metrics) in allMetrics {
            // Check for low health scores
            if metrics.healthScore < 0.8 {
                alerting.alertHealthDegradation(
                    entityType: entityType,
                    currentScore: metrics.healthScore,
                    previousScore: 0.9, // Would be tracked in real implementation
                    threshold: 0.8
                )
            }
            
            // Check for high issue rates
            if metrics.issueRate > 0.1 {
                alerting.alertDataIntegrityIssue(
                    issue: .invalidDataFormat,
                    entityType: entityType,
                    entityId: "system",
                    severity: .high,
                    details: "High issue rate: \(metrics.issueRatePercentage)%"
                )
            }
            
            // Check for high validation failure rates
            if metrics.failedValidations > metrics.passedValidations {
                alerting.alertDataIntegrityIssue(
                    issue: .invalidDataFormat,
                    entityType: entityType,
                    entityId: "system",
                    severity: .critical,
                    details: "More validations failing than passing"
                )
            }
        }
    }
    
    /// Monitor trend anomalies and generate alerts
    public func monitorTrendAnomalies() {
        let allMetrics = integrityMetrics.getAllIntegrityMetrics()
        
        for (entityType, _) in allMetrics {
            let trendAnalysis = integrityMetrics.getTrendAnalysis(for: entityType)
            
            // Check for increasing trends
            if trendAnalysis.trendDirection == .increasing && trendAnalysis.trendStrength > 0.6 {
                alerting.alertTrendAnomaly(
                    entityType: entityType,
                    trendDirection: trendAnalysis.trendDirection,
                    trendStrength: trendAnalysis.trendStrength,
                    issueCount: Int(trendAnalysis.averageIssuesPerCheck * Double(trendAnalysis.trendPeriod))
                )
            }
        }
    }
    
    /// Monitor system health and generate alerts
    public func monitorSystemHealth() {
        // Check for critical system issues
        let allMetrics = integrityMetrics.getAllIntegrityMetrics()
        let totalIssues = allMetrics.values.reduce(0) { $0 + $1.totalIssues }
        let totalChecks = allMetrics.values.reduce(0) { $0 + $1.totalChecks }
        
        if totalChecks > 0 {
            let overallIssueRate = Double(totalIssues) / Double(totalChecks)
            
            if overallIssueRate > 0.2 {
                alerting.alertCriticalSystemIssue(
                    issue: "High overall issue rate",
                    component: "Data Layer",
                    impact: "Data integrity compromised",
                    context: "Overall issue rate: \(Int(overallIssueRate * 100))%"
                )
            }
        }
        
        // Check for system performance issues
        let performanceStats = performanceLogger.getAllPerformanceStats()
        let totalOperations = performanceStats.values.reduce(0) { $0 + $1.count }
        let failedOperations = performanceStats.values.reduce(0) { $0 + Int((1 - $1.successRate) * Double($1.count)) }
        
        if totalOperations > 0 {
            let overallFailureRate = Double(failedOperations) / Double(totalOperations)
            
            if overallFailureRate > 0.1 {
                alerting.alertCriticalSystemIssue(
                    issue: "High overall failure rate",
                    component: "Mapping Operations",
                    impact: "System reliability compromised",
                    context: "Overall failure rate: \(Int(overallFailureRate * 100))%"
                )
            }
        }
    }
    
    // MARK: - Alert Integration
    
    /// Integrate with mapping performance logger
    public func integrateWithPerformanceLogger() {
        // This would be called when the performance logger detects issues
        // For now, we'll set up the integration points
        
        managerLogger.info("Integrated with mapping performance logger")
    }
    
    /// Integrate with data integrity monitor
    public func integrateWithIntegrityMonitor() {
        // This would be called when the integrity monitor detects issues
        // For now, we'll set up the integration points
        
        managerLogger.info("Integrated with data integrity monitor")
    }
    
    /// Integrate with health dashboard
    public func integrateWithHealthDashboard() {
        // This would be called when the health dashboard detects issues
        // For now, we'll set up the integration points
        
        managerLogger.info("Integrated with health dashboard")
    }
    
    // MARK: - Alert Configuration
    
    /// Configure alerting for different environments
    /// - Parameter environment: The environment to configure for
    public func configureForEnvironment(_ environment: AppEnvironment) {
        switch environment {
        case .development:
            alerting.configure(
                enabled: true,
                thresholds: AlertThresholds(
                    mappingFailureThreshold: 3,
                    performanceThreshold: 1.0,
                    healthScoreThreshold: 0.7,
                    trendStrengthThreshold: 0.5,
                    issueRateThreshold: 0.05
                ),
                channels: [.console, .log]
            )
            
        case .testing:
            alerting.configure(
                enabled: true,
                thresholds: AlertThresholds(
                    mappingFailureThreshold: 5,
                    performanceThreshold: 1.5,
                    healthScoreThreshold: 0.8,
                    trendStrengthThreshold: 0.6,
                    issueRateThreshold: 0.1
                ),
                channels: [.log]
            )
            
        case .production:
            alerting.configure(
                enabled: true,
                thresholds: AlertThresholds(
                    mappingFailureThreshold: 10,
                    performanceThreshold: 3.0,
                    healthScoreThreshold: 0.9,
                    trendStrengthThreshold: 0.8,
                    issueRateThreshold: 0.2
                ),
                channels: [.log, .file("/var/log/data-integrity-alerts.log")]
            )
            
        case .debug:
            alerting.configure(
                enabled: true,
                thresholds: AlertThresholds(
                    mappingFailureThreshold: 1,
                    performanceThreshold: 0.5,
                    healthScoreThreshold: 0.6,
                    trendStrengthThreshold: 0.3,
                    issueRateThreshold: 0.01
                ),
                channels: [.console, .log, .file("/tmp/debug-alerts.log")]
            )
        }
        
        managerLogger.info("Alerting configured for \(environment.rawValue) environment")
    }
    
    /// Get current alerting status
    /// - Returns: Current alerting status
    public func getAlertingStatus() -> AlertingStatus {
        let configuration = alerting.getConfiguration()
        let statistics = alerting.getAlertStatistics()
        
        return AlertingStatus(
            monitoringEnabled: monitoringEnabled,
            alertingEnabled: configuration.enabled,
            monitoringInterval: monitoringInterval,
            totalAlerts: statistics.totalAlerts,
            criticalAlerts: statistics.criticalAlerts,
            highAlerts: statistics.highAlerts,
            mediumAlerts: statistics.mediumAlerts,
            lowAlerts: statistics.lowAlerts,
            lastUpdated: Date()
        )
    }
    
    /// Generate alert summary report
    /// - Returns: Alert summary report
    public func generateAlertSummary() -> AlertSummary {
        let statistics = alerting.getAlertStatistics()
        let configuration = alerting.getConfiguration()
        
        return AlertSummary(
            totalAlerts: statistics.totalAlerts,
            criticalAlerts: statistics.criticalAlerts,
            highAlerts: statistics.highAlerts,
            mediumAlerts: statistics.mediumAlerts,
            lowAlerts: statistics.lowAlerts,
            alertingEnabled: configuration.enabled,
            monitoringEnabled: monitoringEnabled,
            channels: configuration.channels,
            thresholds: configuration.thresholds,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func performMonitoring() {
        managerLogger.info("Performing automated alert monitoring")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Monitor all aspects of the system
        monitorMappingPerformance()
        monitorDataIntegrity()
        monitorTrendAnomalies()
        monitorSystemHealth()
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        managerLogger.info("""
            Automated alert monitoring completed:
            Duration: \(String(format: "%.3f", duration))s
            """)
    }
}

// MARK: - Supporting Types

/// Environment types
public enum AppEnvironment: String, CaseIterable {
    case development = "Development"
    case testing = "Testing"
    case production = "Production"
    case debug = "Debug"
}

/// Alerting status
public struct AlertingStatus {
    public let monitoringEnabled: Bool
    public let alertingEnabled: Bool
    public let monitoringInterval: TimeInterval
    public let totalAlerts: Int
    public let criticalAlerts: Int
    public let highAlerts: Int
    public let mediumAlerts: Int
    public let lowAlerts: Int
    public let lastUpdated: Date
    
    public var alertRate: Double {
        return totalAlerts > 0 ? Double(criticalAlerts + highAlerts) / Double(totalAlerts) : 0.0
    }
    
    public var alertRatePercentage: Int {
        return Int(alertRate * 100)
    }
}

/// Alert summary
public struct AlertSummary {
    public let totalAlerts: Int
    public let criticalAlerts: Int
    public let highAlerts: Int
    public let mediumAlerts: Int
    public let lowAlerts: Int
    public let alertingEnabled: Bool
    public let monitoringEnabled: Bool
    public let channels: [AlertChannel]
    public let thresholds: AlertThresholds
    public let lastUpdated: Date
    
    public var hasCriticalAlerts: Bool {
        return criticalAlerts > 0
    }
    
    public var hasHighAlerts: Bool {
        return highAlerts > 0
    }
    
    public var hasMediumAlerts: Bool {
        return mediumAlerts > 0
    }
    
    public var hasLowAlerts: Bool {
        return lowAlerts > 0
    }
    
    public var alertLevel: AlertLevel {
        if hasCriticalAlerts {
            return .critical
        } else if hasHighAlerts {
            return .high
        } else if hasMediumAlerts {
            return .medium
        } else if hasLowAlerts {
            return .low
        } else {
            return .none
        }
    }
}

/// Alert levels
public enum AlertLevel: String, CaseIterable {
    case none = "None"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}
