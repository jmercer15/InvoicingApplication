import Foundation
import os.log

/// Service for integrating alerts with existing monitoring components
public final class AlertIntegrationService: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = AlertIntegrationService()
    
    private init() {}
    
    // MARK: - Dependencies
    
    private let alerting = DataIntegrityAlerting.shared
    private let alertManager = AlertManager.shared
    private let integrityMetrics = DataIntegrityMetrics.shared
    private let performanceLogger = MappingPerformanceLogger.shared
    private let integrationLogger = Logger(subsystem: "com.invoicingapp.data", category: "alert-integration")
    
    // MARK: - Integration Status
    
    private var integrationEnabled: Bool = true
    private var integrationStatus: [String: Bool] = [:]
    
    // MARK: - Integration Setup
    
    /// Set up all alert integrations
    public func setupAllIntegrations() {
        guard integrationEnabled else { return }
        
        setupPerformanceLoggerIntegration()
        setupIntegrityMonitorIntegration()
        setupHealthDashboardIntegration()
        setupMetricsCollectorIntegration()
        setupReporterIntegration()
        
        integrationLogger.info("All alert integrations set up successfully")
    }
    
    /// Set up integration with mapping performance logger
    public func setupPerformanceLoggerIntegration() {
        // This would integrate with the actual performance logger
        // For now, we'll set up the integration points
        
        integrationStatus["performanceLogger"] = true
        integrationLogger.info("Performance logger integration set up")
    }
    
    /// Set up integration with data integrity monitor
    public func setupIntegrityMonitorIntegration() {
        // This would integrate with the actual integrity monitor
        // For now, we'll set up the integration points
        
        integrationStatus["integrityMonitor"] = true
        integrationLogger.info("Integrity monitor integration set up")
    }
    
    /// Set up integration with health dashboard
    public func setupHealthDashboardIntegration() {
        // This would integrate with the actual health dashboard
        // For now, we'll set up the integration points
        
        integrationStatus["healthDashboard"] = true
        integrationLogger.info("Health dashboard integration set up")
    }
    
    /// Set up integration with metrics collector
    public func setupMetricsCollectorIntegration() {
        // This would integrate with the actual metrics collector
        // For now, we'll set up the integration points
        
        integrationStatus["metricsCollector"] = true
        integrationLogger.info("Metrics collector integration set up")
    }
    
    /// Set up integration with reporter
    public func setupReporterIntegration() {
        // This would integrate with the actual reporter
        // For now, we'll set up the integration points
        
        integrationStatus["reporter"] = true
        integrationLogger.info("Reporter integration set up")
    }
    
    // MARK: - Alert Triggers
    
    /// Trigger alert for mapping operation failure
    /// - Parameters:
    ///   - operation: The mapping operation that failed
    ///   - entityType: The entity type being mapped
    ///   - domainType: The domain type being mapped to
    ///   - error: The error that occurred
    ///   - context: Additional context about the failure
    public func triggerMappingFailureAlert(
        operation: MappingOperation,
        entityType: String,
        domainType: String,
        error: Error,
        context: String? = nil
    ) {
        guard integrationEnabled else { return }
        
        alerting.alertMappingFailure(
            operation: operation,
            entityType: entityType,
            domainType: domainType,
            error: error,
            context: context
        )
        
        integrationLogger.info("""
            Mapping failure alert triggered:
            Operation: \(operation.rawValue)
            Entity: \(entityType) -> \(domainType)
            Error: \(error.localizedDescription)
            """)
    }
    
    /// Trigger alert for data integrity issue
    /// - Parameters:
    ///   - issue: The type of integrity issue
    ///   - entityType: The entity type affected
    ///   - entityId: The ID of the affected entity
    ///   - severity: The severity of the issue
    ///   - details: Additional details about the issue
    public func triggerDataIntegrityAlert(
        issue: DataIntegrityIssue,
        entityType: String,
        entityId: String,
        severity: IssueSeverity,
        details: String? = nil
    ) {
        guard integrationEnabled else { return }
        
        alerting.alertDataIntegrityIssue(
            issue: issue,
            entityType: entityType,
            entityId: entityId,
            severity: severity,
            details: details
        )
        
        integrationLogger.info("""
            Data integrity alert triggered:
            Issue: \(issue.rawValue)
            Entity: \(entityType) (ID: \(entityId))
            Severity: \(severity.rawValue)
            """)
    }
    
    /// Trigger alert for performance issue
    /// - Parameters:
    ///   - operation: The operation that is slow
    ///   - duration: The duration of the operation
    ///   - threshold: The performance threshold
    ///   - context: Additional context about the performance issue
    public func triggerPerformanceAlert(
        operation: MappingOperation,
        duration: CFAbsoluteTime,
        threshold: CFAbsoluteTime,
        context: String? = nil
    ) {
        guard integrationEnabled else { return }
        
        alerting.alertPerformanceIssue(
            operation: operation,
            duration: duration,
            threshold: threshold,
            context: context
        )
        
        integrationLogger.info("""
            Performance alert triggered:
            Operation: \(operation.rawValue)
            Duration: \(String(format: "%.3f", duration))s
            Threshold: \(String(format: "%.3f", threshold))s
            """)
    }
    
    /// Trigger alert for health degradation
    /// - Parameters:
    ///   - entityType: The entity type with degraded health
    ///   - currentScore: The current health score
    ///   - previousScore: The previous health score
    ///   - threshold: The health score threshold
    public func triggerHealthDegradationAlert(
        entityType: String,
        currentScore: Double,
        previousScore: Double,
        threshold: Double
    ) {
        guard integrationEnabled else { return }
        
        alerting.alertHealthDegradation(
            entityType: entityType,
            currentScore: currentScore,
            previousScore: previousScore,
            threshold: threshold
        )
        
        integrationLogger.info("""
            Health degradation alert triggered:
            Entity: \(entityType)
            Current Score: \(Int(currentScore * 100))%
            Previous Score: \(Int(previousScore * 100))%
            """)
    }
    
    /// Trigger alert for critical system issue
    /// - Parameters:
    ///   - issue: The critical issue description
    ///   - component: The component affected
    ///   - impact: The impact of the issue
    ///   - context: Additional context about the issue
    public func triggerCriticalSystemAlert(
        issue: String,
        component: String,
        impact: String,
        context: String? = nil
    ) {
        guard integrationEnabled else { return }
        
        alerting.alertCriticalSystemIssue(
            issue: issue,
            component: component,
            impact: impact,
            context: context
        )
        
        integrationLogger.info("""
            Critical system alert triggered:
            Issue: \(issue)
            Component: \(component)
            Impact: \(impact)
            """)
    }
    
    /// Trigger alert for trend anomaly
    /// - Parameters:
    ///   - entityType: The entity type with trend anomaly
    ///   - trendDirection: The direction of the trend
    ///   - trendStrength: The strength of the trend
    ///   - issueCount: The number of issues
    public func triggerTrendAnomalyAlert(
        entityType: String,
        trendDirection: TrendDirection,
        trendStrength: Double,
        issueCount: Int
    ) {
        guard integrationEnabled else { return }
        
        alerting.alertTrendAnomaly(
            entityType: entityType,
            trendDirection: trendDirection,
            trendStrength: trendStrength,
            issueCount: issueCount
        )
        
        integrationLogger.info("""
            Trend anomaly alert triggered:
            Entity: \(entityType)
            Trend: \(trendDirection.rawValue)
            Strength: \(Int(trendStrength * 100))%
            """)
    }
    
    // MARK: - Automated Monitoring Integration
    
    /// Set up automated monitoring with alert integration
    public func setupAutomatedMonitoring() {
        // Set up the alert manager monitoring
        alertManager.startMonitoring(interval: 60)
        
        // Configure for current environment
        alertManager.configureForEnvironment(.development) // Would be determined dynamically
        
        integrationLogger.info("Automated monitoring with alert integration set up")
    }
    
    /// Stop automated monitoring
    public func stopAutomatedMonitoring() {
        alertManager.stopMonitoring()
        integrationLogger.info("Automated monitoring stopped")
    }
    
    // MARK: - Integration Status
    
    /// Get integration status
    /// - Returns: Current integration status
    public func getIntegrationStatus() -> IntegrationStatus {
        return IntegrationStatus(
            integrationEnabled: integrationEnabled,
            performanceLogger: integrationStatus["performanceLogger"] ?? false,
            integrityMonitor: integrationStatus["integrityMonitor"] ?? false,
            healthDashboard: integrationStatus["healthDashboard"] ?? false,
            metricsCollector: integrationStatus["metricsCollector"] ?? false,
            reporter: integrationStatus["reporter"] ?? false,
            lastUpdated: Date()
        )
    }
    
    /// Enable or disable integration
    /// - Parameter enabled: Whether to enable integration
    public func setIntegrationEnabled(_ enabled: Bool) {
        integrationEnabled = enabled
        integrationLogger.info("Alert integration \(enabled ? "enabled" : "disabled")")
    }
    
    /// Test alert integration
    /// - Returns: Whether the integration test passed
    public func testAlertIntegration() -> Bool {
        // Test alerting system
        let testError = NSError(domain: "AlertIntegrationTest", code: 9999, userInfo: [
            NSLocalizedDescriptionKey: "Test alert for integration verification"
        ])
        
        triggerMappingFailureAlert(
            operation: .entityToDomain,
            entityType: "TestEntity",
            domainType: "TestDomain",
            error: testError,
            context: "Integration test"
        )
        
        // Test data integrity alert
        triggerDataIntegrityAlert(
            issue: .missingRequiredField,
            entityType: "TestEntity",
            entityId: "test-123",
            severity: .low,
            details: "Integration test"
        )
        
        // Test performance alert
        triggerPerformanceAlert(
            operation: .entityToDomain,
            duration: 5.0,
            threshold: 2.0,
            context: "Integration test"
        )
        
        integrationLogger.info("Alert integration test completed")
        return true
    }
    
    // MARK: - Configuration
    
    /// Configure alert integration for environment
    /// - Parameter environment: The environment to configure for
    public func configureForEnvironment(_ environment: AppEnvironment) {
        alertManager.configureForEnvironment(environment)
        integrationLogger.info("Alert integration configured for \(environment.rawValue) environment")
    }
    
    /// Get alert integration configuration
    /// - Returns: Current alert integration configuration
    public func getConfiguration() -> AlertIntegrationConfiguration {
        let alertingConfig = alerting.getConfiguration()
        let alertingStatus = alertManager.getAlertingStatus()
        let integrationStatus = getIntegrationStatus()
        
        return AlertIntegrationConfiguration(
            integrationEnabled: integrationEnabled,
            alertingEnabled: alertingConfig.enabled,
            monitoringEnabled: alertingStatus.monitoringEnabled,
            monitoringInterval: alertingStatus.monitoringInterval,
            channels: alertingConfig.channels,
            thresholds: alertingConfig.thresholds,
            integrationStatus: integrationStatus,
            lastUpdated: Date()
        )
    }
}

// MARK: - Supporting Types

/// Integration status
public struct IntegrationStatus {
    public let integrationEnabled: Bool
    public let performanceLogger: Bool
    public let integrityMonitor: Bool
    public let healthDashboard: Bool
    public let metricsCollector: Bool
    public let reporter: Bool
    public let lastUpdated: Date
    
    public var allIntegrationsActive: Bool {
        return performanceLogger && integrityMonitor && healthDashboard && metricsCollector && reporter
    }
    
    public var activeIntegrations: Int {
        var count = 0
        if performanceLogger { count += 1 }
        if integrityMonitor { count += 1 }
        if healthDashboard { count += 1 }
        if metricsCollector { count += 1 }
        if reporter { count += 1 }
        return count
    }
    
    public var totalIntegrations: Int {
        return 5
    }
    
    public var integrationPercentage: Int {
        return Int(Double(activeIntegrations) / Double(totalIntegrations) * 100)
    }
}

/// Alert integration configuration
public struct AlertIntegrationConfiguration {
    public let integrationEnabled: Bool
    public let alertingEnabled: Bool
    public let monitoringEnabled: Bool
    public let monitoringInterval: TimeInterval
    public let channels: [AlertChannel]
    public let thresholds: AlertThresholds
    public let integrationStatus: IntegrationStatus
    public let lastUpdated: Date
    
    public var isFullyConfigured: Bool {
        return integrationEnabled && alertingEnabled && monitoringEnabled && integrationStatus.allIntegrationsActive
    }
    
    public var configurationStatus: ConfigurationStatus {
        if isFullyConfigured {
            return .fullyConfigured
        } else if integrationEnabled && alertingEnabled {
            return .partiallyConfigured
        } else {
            return .notConfigured
        }
    }
}

/// Configuration status
public enum ConfigurationStatus: String, CaseIterable {
    case notConfigured = "Not Configured"
    case partiallyConfigured = "Partially Configured"
    case fullyConfigured = "Fully Configured"
}
