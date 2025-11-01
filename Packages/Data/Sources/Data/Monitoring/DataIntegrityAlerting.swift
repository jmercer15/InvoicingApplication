import Foundation
import os.log

/// Comprehensive alerting system for mapping failures and data inconsistencies
public final class DataIntegrityAlerting: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = DataIntegrityAlerting()
    
    private init() {}
    
    // MARK: - Dependencies
    
    private let integrityMetrics = DataIntegrityMetrics.shared
    private let performanceLogger = MappingPerformanceLogger.shared
    private let alertLogger = Logger(subsystem: "com.invoicingapp.data", category: "integrity-alerts")
    
    // MARK: - Alert Configuration
    
    private var alertingEnabled: Bool = true
    private var alertThresholds: AlertThresholds = AlertThresholds.`default`
    private var alertChannels: [AlertChannel] = [.console, .log]
    private var alertCooldowns: [String: Date] = [:]
    
    // MARK: - Alert Types
    
    /// Alert for mapping operation failures
    /// - Parameters:
    ///   - operation: The mapping operation that failed
    ///   - entityType: The entity type being mapped
    ///   - domainType: The domain type being mapped to
    ///   - error: The error that occurred
    ///   - context: Additional context about the failure
    public func alertMappingFailure(
        operation: MappingOperation,
        entityType: String,
        domainType: String,
        error: Error,
        context: String? = nil
    ) {
        guard alertingEnabled else { return }
        
        let alert = MappingFailureAlert(
            id: UUID().uuidString,
            timestamp: Date(),
            operation: operation,
            entityType: entityType,
            domainType: domainType,
            error: error,
            context: context,
            severity: determineMappingFailureSeverity(error: error),
            category: .mappingFailure
        )
        
        processAlert(alert)
    }
    
    /// Alert for data integrity issues
    /// - Parameters:
    ///   - issue: The type of integrity issue
    ///   - entityType: The entity type affected
    ///   - entityId: The ID of the affected entity
    ///   - severity: The severity of the issue
    ///   - details: Additional details about the issue
    public func alertDataIntegrityIssue(
        issue: DataIntegrityIssue,
        entityType: String,
        entityId: String,
        severity: IssueSeverity,
        details: String? = nil
    ) {
        guard alertingEnabled else { return }
        
        let alert = DataIntegrityAlert(
            id: UUID().uuidString,
            timestamp: Date(),
            issue: issue,
            entityType: entityType,
            entityId: entityId,
            severity: convertToAlertSeverity(severity),
            details: details,
            category: .dataIntegrity
        )
        
        processAlert(alert)
    }
    
    /// Alert for performance issues
    /// - Parameters:
    ///   - operation: The operation that is slow
    ///   - duration: The duration of the operation
    ///   - threshold: The performance threshold
    ///   - context: Additional context about the performance issue
    public func alertPerformanceIssue(
        operation: MappingOperation,
        duration: CFAbsoluteTime,
        threshold: CFAbsoluteTime,
        context: String? = nil
    ) {
        guard alertingEnabled else { return }
        
        let alert = PerformanceAlert(
            id: UUID().uuidString,
            timestamp: Date(),
            operation: operation,
            duration: duration,
            threshold: threshold,
            context: context,
            severity: determinePerformanceSeverity(duration: duration, threshold: threshold),
            category: .performance
        )
        
        processAlert(alert)
    }
    
    /// Alert for health score degradation
    /// - Parameters:
    ///   - entityType: The entity type with degraded health
    ///   - currentScore: The current health score
    ///   - previousScore: The previous health score
    ///   - threshold: The health score threshold
    public func alertHealthDegradation(
        entityType: String,
        currentScore: Double,
        previousScore: Double,
        threshold: Double
    ) {
        guard alertingEnabled else { return }
        
        let alert = HealthDegradationAlert(
            id: UUID().uuidString,
            timestamp: Date(),
            entityType: entityType,
            currentScore: currentScore,
            previousScore: previousScore,
            threshold: threshold,
            severity: determineHealthSeverity(currentScore: currentScore, threshold: threshold),
            category: .health
        )
        
        processAlert(alert)
    }
    
    /// Alert for critical system issues
    /// - Parameters:
    ///   - issue: The critical issue description
    ///   - component: The component affected
    ///   - impact: The impact of the issue
    ///   - context: Additional context about the issue
    public func alertCriticalSystemIssue(
        issue: String,
        component: String,
        impact: String,
        context: String? = nil
    ) {
        guard alertingEnabled else { return }
        
        let alert = CriticalSystemAlert(
            id: UUID().uuidString,
            timestamp: Date(),
            issue: issue,
            component: component,
            impact: impact,
            context: context,
            severity: .critical,
            category: .system
        )
        
        processAlert(alert)
    }
    
    /// Alert for trend anomalies
    /// - Parameters:
    ///   - entityType: The entity type with trend anomaly
    ///   - trendDirection: The direction of the trend
    ///   - trendStrength: The strength of the trend
    ///   - issueCount: The number of issues
    public func alertTrendAnomaly(
        entityType: String,
        trendDirection: TrendDirection,
        trendStrength: Double,
        issueCount: Int
    ) {
        guard alertingEnabled else { return }
        
        let alert = TrendAnomalyAlert(
            id: UUID().uuidString,
            timestamp: Date(),
            entityType: entityType,
            trendDirection: trendDirection,
            trendStrength: trendStrength,
            issueCount: issueCount,
            severity: determineTrendSeverity(trendDirection: trendDirection, trendStrength: trendStrength),
            category: .trend
        )
        
        processAlert(alert)
    }
    
    // MARK: - Alert Processing
    
    private func processAlert(_ alert: Alert) {
        // Check cooldown
        if isInCooldown(alert: alert) {
            return
        }
        
        // Update cooldown
        updateCooldown(alert: alert)
        
        // Log alert
        logAlert(alert)
        
        // Send to channels
        sendToChannels(alert)
        
        // Record alert metrics
        recordAlertMetrics(alert)
    }
    
    private func isInCooldown(alert: Alert) -> Bool {
        let cooldownKey = "\(alert.category.rawValue)_\(alert.severity.rawValue)"
        guard let lastAlert = alertCooldowns[cooldownKey] else { return false }
        
        let cooldownDuration = getCooldownDuration(for: alert.severity)
        return Date().timeIntervalSince(lastAlert) < cooldownDuration
    }
    
    private func updateCooldown(alert: Alert) {
        let cooldownKey = "\(alert.category.rawValue)_\(alert.severity.rawValue)"
        alertCooldowns[cooldownKey] = Date()
    }
    
    private func getCooldownDuration(for severity: AlertSeverity) -> TimeInterval {
        switch severity {
        case .critical:
            return 60 // 1 minute
        case .high:
            return 300 // 5 minutes
        case .medium:
            return 900 // 15 minutes
        case .low:
            return 1800 // 30 minutes
        }
    }
    
    private func logAlert(_ alert: Alert) {
        let message = formatAlertMessage(alert)
        
        switch alert.severity {
        case .critical:
            alertLogger.critical("\(message)")
        case .high:
            alertLogger.error("\(message)")
        case .medium:
            alertLogger.warning("\(message)")
        case .low:
            alertLogger.info("\(message)")
        }
    }
    
    private func formatAlertMessage(_ alert: Alert) -> String {
        let timestamp = DateFormatter.alertFormatter.string(from: alert.timestamp)
        
        switch alert {
        case let mappingAlert as MappingFailureAlert:
            return """
            MAPPING FAILURE ALERT [\(alert.severity.rawValue)]
            Time: \(timestamp)
            Operation: \(mappingAlert.operation.rawValue)
            Entity: \(mappingAlert.entityType) -> \(mappingAlert.domainType)
            Error: \(mappingAlert.error.localizedDescription)
            Context: \(mappingAlert.context ?? "None")
            """
            
        case let integrityAlert as DataIntegrityAlert:
            return """
            DATA INTEGRITY ALERT [\(alert.severity.rawValue)]
            Time: \(timestamp)
            Issue: \(integrityAlert.issue.rawValue)
            Entity: \(integrityAlert.entityType) (ID: \(integrityAlert.entityId))
            Severity: \(integrityAlert.severity.rawValue)
            Details: \(integrityAlert.details ?? "None")
            """
            
        case let performanceAlert as PerformanceAlert:
            return """
            PERFORMANCE ALERT [\(alert.severity.rawValue)]
            Time: \(timestamp)
            Operation: \(performanceAlert.operation.rawValue)
            Duration: \(String(format: "%.3f", performanceAlert.duration))s
            Threshold: \(String(format: "%.3f", performanceAlert.threshold))s
            Context: \(performanceAlert.context ?? "None")
            """
            
        case let healthAlert as HealthDegradationAlert:
            return """
            HEALTH DEGRADATION ALERT [\(alert.severity.rawValue)]
            Time: \(timestamp)
            Entity: \(healthAlert.entityType)
            Current Score: \(Int(healthAlert.currentScore * 100))%
            Previous Score: \(Int(healthAlert.previousScore * 100))%
            Threshold: \(Int(healthAlert.threshold * 100))%
            """
            
        case let systemAlert as CriticalSystemAlert:
            return """
            CRITICAL SYSTEM ALERT [\(alert.severity.rawValue)]
            Time: \(timestamp)
            Issue: \(systemAlert.issue)
            Component: \(systemAlert.component)
            Impact: \(systemAlert.impact)
            Context: \(systemAlert.context ?? "None")
            """
            
        case let trendAlert as TrendAnomalyAlert:
            return """
            TREND ANOMALY ALERT [\(alert.severity.rawValue)]
            Time: \(timestamp)
            Entity: \(trendAlert.entityType)
            Trend: \(trendAlert.trendDirection.rawValue)
            Strength: \(Int(trendAlert.trendStrength * 100))%
            Issue Count: \(trendAlert.issueCount)
            """
            
        default:
            return """
            ALERT [\(alert.severity.rawValue)]
            Time: \(timestamp)
            Category: \(alert.category.rawValue)
            """
        }
    }
    
    private func sendToChannels(_ alert: Alert) {
        for channel in alertChannels {
            switch channel {
            case .console:
                sendToConsole(alert)
            case .log:
                // Already handled in logAlert
                break
            case .file(let filePath):
                sendToFile(alert, filePath: filePath)
            case .email(let recipients):
                sendToEmail(alert, recipients: recipients)
            case .webhook(let url):
                sendToWebhook(alert, url: url)
            case .notification:
                sendToNotification(alert)
            }
        }
    }
    
    private func sendToConsole(_ alert: Alert) {
        let message = formatAlertMessage(alert)
        print("🚨 \(message)")
    }
    
    private func sendToFile(_ alert: Alert, filePath: String) {
        let message = formatAlertMessage(alert)
        let logEntry = "\(message)\n"
        
        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: filePath) {
                if let fileHandle = FileHandle(forWritingAtPath: filePath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: filePath))
            }
        }
    }
    
    private func sendToEmail(_ alert: Alert, recipients: [String]) {
        // Email implementation would go here
        // For now, just log that email would be sent
        alertLogger.info("Email alert would be sent to: \(recipients.joined(separator: ", "))")
    }
    
    private func sendToWebhook(_ alert: Alert, url: String) {
        // Webhook implementation would go here
        // For now, just log that webhook would be called
        alertLogger.info("Webhook alert would be sent to: \(url)")
    }
    
    private func sendToNotification(_ alert: Alert) {
        // System notification implementation would go here
        // For now, just log that notification would be sent
        alertLogger.info("System notification would be sent")
    }
    
    private func recordAlertMetrics(_ alert: Alert) {
        // Record alert metrics for analysis
        // This would integrate with the metrics system
        alertLogger.info("Alert metrics recorded for \(alert.category.rawValue) - \(alert.severity.rawValue)")
    }
    
    // MARK: - Severity Determination
    
    private func determineMappingFailureSeverity(error: Error) -> AlertSeverity {
        // Determine severity based on error type and message
        let errorMessage = error.localizedDescription.lowercased()
        
        if errorMessage.contains("critical") || errorMessage.contains("fatal") {
            return .critical
        } else if errorMessage.contains("error") || errorMessage.contains("failed") {
            return .high
        } else if errorMessage.contains("warning") || errorMessage.contains("issue") {
            return .medium
        } else {
            return .low
        }
    }
    
    private func determinePerformanceSeverity(duration: CFAbsoluteTime, threshold: CFAbsoluteTime) -> AlertSeverity {
        let ratio = duration / threshold
        
        if ratio > 5.0 {
            return .critical
        } else if ratio > 3.0 {
            return .high
        } else if ratio > 2.0 {
            return .medium
        } else {
            return .low
        }
    }
    
    private func determineHealthSeverity(currentScore: Double, threshold: Double) -> AlertSeverity {
        if currentScore < 0.3 {
            return .critical
        } else if currentScore < 0.5 {
            return .high
        } else if currentScore < 0.7 {
            return .medium
        } else {
            return .low
        }
    }
    
    private func determineTrendSeverity(trendDirection: TrendDirection, trendStrength: Double) -> AlertSeverity {
        if trendDirection == .increasing && trendStrength > 0.8 {
            return .critical
        } else if trendDirection == .increasing && trendStrength > 0.6 {
            return .high
        } else if trendDirection == .increasing && trendStrength > 0.4 {
            return .medium
        } else {
            return .low
        }
    }
    
    // MARK: - Configuration
    
    /// Configure alerting settings
    /// - Parameters:
    ///   - enabled: Whether alerting is enabled
    ///   - thresholds: Alert thresholds
    ///   - channels: Alert channels
    public func configure(
        enabled: Bool = true,
        thresholds: AlertThresholds = AlertThresholds.`default`,
        channels: [AlertChannel] = [.console, .log]
    ) {
        alertingEnabled = enabled
        alertThresholds = thresholds
        alertChannels = channels
        
        alertLogger.info("""
            Alerting configuration updated:
            Enabled: \(enabled)
            Channels: \(channels.map { $0.description }.joined(separator: ", "))
            """)
    }
    
    /// Get current alerting configuration
    /// - Returns: Current alerting configuration
    public func getConfiguration() -> AlertingConfiguration {
        return AlertingConfiguration(
            enabled: alertingEnabled,
            thresholds: alertThresholds,
            channels: alertChannels,
            cooldowns: alertCooldowns
        )
    }
    
    /// Clear alert cooldowns
    public func clearCooldowns() {
        alertCooldowns.removeAll()
        alertLogger.info("Alert cooldowns cleared")
    }
    
    /// Get alert statistics
    /// - Returns: Alert statistics
    public func getAlertStatistics() -> AlertStatistics {
        let totalAlerts = alertCooldowns.count
        let criticalAlerts = alertCooldowns.filter { $0.key.contains("critical") }.count
        let highAlerts = alertCooldowns.filter { $0.key.contains("high") }.count
        let mediumAlerts = alertCooldowns.filter { $0.key.contains("medium") }.count
        let lowAlerts = alertCooldowns.filter { $0.key.contains("low") }.count
        
        return AlertStatistics(
            totalAlerts: totalAlerts,
            criticalAlerts: criticalAlerts,
            highAlerts: highAlerts,
            mediumAlerts: mediumAlerts,
            lowAlerts: lowAlerts,
            lastUpdated: Date()
        )
    }
}

// MARK: - Supporting Types

/// Alert severity levels
public enum AlertSeverity: String, CaseIterable, Comparable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    public static func < (lhs: AlertSeverity, rhs: AlertSeverity) -> Bool {
        let levels: [AlertSeverity] = [.low, .medium, .high, .critical]
        guard let lhsIndex = levels.firstIndex(of: lhs),
              let rhsIndex = levels.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

/// Alert categories
public enum AlertCategory: String, CaseIterable {
    case mappingFailure = "Mapping Failure"
    case dataIntegrity = "Data Integrity"
    case performance = "Performance"
    case health = "Health"
    case system = "System"
    case trend = "Trend"
}

/// Alert channels
public enum AlertChannel {
    case console
    case log
    case file(String)
    case email([String])
    case webhook(String)
    case notification
    
    var description: String {
        switch self {
        case .console:
            return "Console"
        case .log:
            return "Log"
        case .file(let path):
            return "File(\(path))"
        case .email(let recipients):
            return "Email(\(recipients.count) recipients)"
        case .webhook(let url):
            return "Webhook(\(url))"
        case .notification:
            return "Notification"
        }
    }
}

/// Alert thresholds
public struct AlertThresholds: @unchecked Sendable {
    public let mappingFailureThreshold: Int
    public let performanceThreshold: CFAbsoluteTime
    public let healthScoreThreshold: Double
    public let trendStrengthThreshold: Double
    public let issueRateThreshold: Double
    
    public static let `default` = AlertThresholds(
        mappingFailureThreshold: 5,
        performanceThreshold: 2.0,
        healthScoreThreshold: 0.8,
        trendStrengthThreshold: 0.6,
        issueRateThreshold: 0.1
    )
    
    public init(
        mappingFailureThreshold: Int = 5,
        performanceThreshold: CFAbsoluteTime = 2.0,
        healthScoreThreshold: Double = 0.8,
        trendStrengthThreshold: Double = 0.6,
        issueRateThreshold: Double = 0.1
    ) {
        self.mappingFailureThreshold = mappingFailureThreshold
        self.performanceThreshold = performanceThreshold
        self.healthScoreThreshold = healthScoreThreshold
        self.trendStrengthThreshold = trendStrengthThreshold
        self.issueRateThreshold = issueRateThreshold
    }
}

/// Base alert protocol
public protocol Alert {
    var id: String { get }
    var timestamp: Date { get }
    var severity: AlertSeverity { get }
    var category: AlertCategory { get }
}

/// Mapping failure alert
public struct MappingFailureAlert: Alert {
    public let id: String
    public let timestamp: Date
    public let operation: MappingOperation
    public let entityType: String
    public let domainType: String
    public let error: Error
    public let context: String?
    public let severity: AlertSeverity
    public let category: AlertCategory
}

/// Data integrity alert
public struct DataIntegrityAlert: Alert {
    public let id: String
    public let timestamp: Date
    public let issue: DataIntegrityIssue
    public let entityType: String
    public let entityId: String
    public let severity: AlertSeverity
    public let details: String?
    public let category: AlertCategory
}

/// Performance alert
public struct PerformanceAlert: Alert {
    public let id: String
    public let timestamp: Date
    public let operation: MappingOperation
    public let duration: CFAbsoluteTime
    public let threshold: CFAbsoluteTime
    public let context: String?
    public let severity: AlertSeverity
    public let category: AlertCategory
}

/// Health degradation alert
public struct HealthDegradationAlert: Alert {
    public let id: String
    public let timestamp: Date
    public let entityType: String
    public let currentScore: Double
    public let previousScore: Double
    public let threshold: Double
    public let severity: AlertSeverity
    public let category: AlertCategory
}

/// Critical system alert
public struct CriticalSystemAlert: Alert {
    public let id: String
    public let timestamp: Date
    public let issue: String
    public let component: String
    public let impact: String
    public let context: String?
    public let severity: AlertSeverity
    public let category: AlertCategory
}

/// Trend anomaly alert
public struct TrendAnomalyAlert: Alert {
    public let id: String
    public let timestamp: Date
    public let entityType: String
    public let trendDirection: TrendDirection
    public let trendStrength: Double
    public let issueCount: Int
    public let severity: AlertSeverity
    public let category: AlertCategory
}

/// Alerting configuration
public struct AlertingConfiguration {
    public let enabled: Bool
    public let thresholds: AlertThresholds
    public let channels: [AlertChannel]
    public let cooldowns: [String: Date]
}

/// Alert statistics
public struct AlertStatistics {
    public let totalAlerts: Int
    public let criticalAlerts: Int
    public let highAlerts: Int
    public let mediumAlerts: Int
    public let lowAlerts: Int
    public let lastUpdated: Date
}

// MARK: - Extensions

extension DateFormatter {
    static let alertFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - Helper Functions

/// Convert IssueSeverity to AlertSeverity
private func convertToAlertSeverity(_ issueSeverity: IssueSeverity) -> AlertSeverity {
    switch issueSeverity {
    case .low:
        return .low
    case .medium:
        return .medium
    case .high:
        return .high
    case .critical:
        return .critical
    }
}
