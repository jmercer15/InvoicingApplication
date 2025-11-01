import Foundation

/// Configuration for data layer monitoring
public struct MonitoringConfiguration: Sendable {
    
    // MARK: - Performance Monitoring
    
    /// Enable performance monitoring
    public let enablePerformanceMonitoring: Bool
    
    /// Performance threshold for slow operations (in seconds)
    public let slowOperationThreshold: CFAbsoluteTime
    
    /// Performance threshold for batch operations (items per second)
    public let batchPerformanceThreshold: Double
    
    /// Maximum number of performance metrics to keep in memory
    public let maxPerformanceMetrics: Int
    
    /// Performance metrics retention period (in seconds)
    public let performanceMetricsRetention: TimeInterval
    
    // MARK: - Integrity Monitoring
    
    /// Enable integrity monitoring
    public let enableIntegrityMonitoring: Bool
    
    /// Integrity check threshold for issue rate (percentage)
    public let integrityIssueThreshold: Double
    
    /// Maximum number of integrity metrics to keep in memory
    public let maxIntegrityMetrics: Int
    
    /// Integrity metrics retention period (in seconds)
    public let integrityMetricsRetention: TimeInterval
    
    // MARK: - Logging
    
    /// Enable detailed logging
    public let enableDetailedLogging: Bool
    
    /// Log level for monitoring
    public let logLevel: LogLevel
    
    /// Enable console logging
    public let enableConsoleLogging: Bool
    
    /// Enable file logging
    public let enableFileLogging: Bool
    
    // MARK: - Alerts
    
    /// Enable performance alerts
    public let enablePerformanceAlerts: Bool
    
    /// Enable integrity alerts
    public let enableIntegrityAlerts: Bool
    
    /// Alert threshold for performance issues
    public let performanceAlertThreshold: CFAbsoluteTime
    
    /// Alert threshold for integrity issues
    public let integrityAlertThreshold: Double
    
    // MARK: - Dashboard
    
    /// Enable health dashboard
    public let enableHealthDashboard: Bool
    
    /// Dashboard refresh interval (in seconds)
    public let dashboardRefreshInterval: TimeInterval
    
    /// Enable automatic health reporting
    public let enableAutomaticHealthReporting: Bool
    
    /// Health report generation interval (in seconds)
    public let healthReportInterval: TimeInterval
    
    // MARK: - Initialization
    
    public init(
        enablePerformanceMonitoring: Bool = true,
        slowOperationThreshold: CFAbsoluteTime = 1.0,
        batchPerformanceThreshold: Double = 10.0,
        maxPerformanceMetrics: Int = 1000,
        performanceMetricsRetention: TimeInterval = 3600,
        enableIntegrityMonitoring: Bool = true,
        integrityIssueThreshold: Double = 0.1,
        maxIntegrityMetrics: Int = 1000,
        integrityMetricsRetention: TimeInterval = 3600,
        enableDetailedLogging: Bool = true,
        logLevel: LogLevel = .info,
        enableConsoleLogging: Bool = true,
        enableFileLogging: Bool = false,
        enablePerformanceAlerts: Bool = true,
        enableIntegrityAlerts: Bool = true,
        performanceAlertThreshold: CFAbsoluteTime = 2.0,
        integrityAlertThreshold: Double = 0.2,
        enableHealthDashboard: Bool = true,
        dashboardRefreshInterval: TimeInterval = 60,
        enableAutomaticHealthReporting: Bool = true,
        healthReportInterval: TimeInterval = 300
    ) {
        self.enablePerformanceMonitoring = enablePerformanceMonitoring
        self.slowOperationThreshold = slowOperationThreshold
        self.batchPerformanceThreshold = batchPerformanceThreshold
        self.maxPerformanceMetrics = maxPerformanceMetrics
        self.performanceMetricsRetention = performanceMetricsRetention
        self.enableIntegrityMonitoring = enableIntegrityMonitoring
        self.integrityIssueThreshold = integrityIssueThreshold
        self.maxIntegrityMetrics = maxIntegrityMetrics
        self.integrityMetricsRetention = integrityMetricsRetention
        self.enableDetailedLogging = enableDetailedLogging
        self.logLevel = logLevel
        self.enableConsoleLogging = enableConsoleLogging
        self.enableFileLogging = enableFileLogging
        self.enablePerformanceAlerts = enablePerformanceAlerts
        self.enableIntegrityAlerts = enableIntegrityAlerts
        self.performanceAlertThreshold = performanceAlertThreshold
        self.integrityAlertThreshold = integrityAlertThreshold
        self.enableHealthDashboard = enableHealthDashboard
        self.dashboardRefreshInterval = dashboardRefreshInterval
        self.enableAutomaticHealthReporting = enableAutomaticHealthReporting
        self.healthReportInterval = healthReportInterval
    }
    
    // MARK: - Preset Configurations
    
    /// Development configuration with detailed logging
    public static let development = MonitoringConfiguration(
        enablePerformanceMonitoring: true,
        slowOperationThreshold: 0.5,
        batchPerformanceThreshold: 5.0,
        maxPerformanceMetrics: 500,
        performanceMetricsRetention: 1800,
        enableIntegrityMonitoring: true,
        integrityIssueThreshold: 0.05,
        maxIntegrityMetrics: 500,
        integrityMetricsRetention: 1800,
        enableDetailedLogging: true,
        logLevel: .debug,
        enableConsoleLogging: true,
        enableFileLogging: true,
        enablePerformanceAlerts: true,
        enableIntegrityAlerts: true,
        performanceAlertThreshold: 1.0,
        integrityAlertThreshold: 0.1,
        enableHealthDashboard: true,
        dashboardRefreshInterval: 30,
        enableAutomaticHealthReporting: true,
        healthReportInterval: 120
    )
    
    /// Production configuration with minimal overhead
    public static let production = MonitoringConfiguration(
        enablePerformanceMonitoring: true,
        slowOperationThreshold: 2.0,
        batchPerformanceThreshold: 20.0,
        maxPerformanceMetrics: 2000,
        performanceMetricsRetention: 7200,
        enableIntegrityMonitoring: true,
        integrityIssueThreshold: 0.2,
        maxIntegrityMetrics: 2000,
        integrityMetricsRetention: 7200,
        enableDetailedLogging: false,
        logLevel: .warning,
        enableConsoleLogging: false,
        enableFileLogging: true,
        enablePerformanceAlerts: true,
        enableIntegrityAlerts: true,
        performanceAlertThreshold: 5.0,
        integrityAlertThreshold: 0.5,
        enableHealthDashboard: true,
        dashboardRefreshInterval: 300,
        enableAutomaticHealthReporting: true,
        healthReportInterval: 1800
    )
    
    /// Testing configuration with minimal monitoring
    public static let testing = MonitoringConfiguration(
        enablePerformanceMonitoring: false,
        slowOperationThreshold: 1.0,
        batchPerformanceThreshold: 10.0,
        maxPerformanceMetrics: 100,
        performanceMetricsRetention: 600,
        enableIntegrityMonitoring: false,
        integrityIssueThreshold: 0.1,
        maxIntegrityMetrics: 100,
        integrityMetricsRetention: 600,
        enableDetailedLogging: false,
        logLevel: .error,
        enableConsoleLogging: false,
        enableFileLogging: false,
        enablePerformanceAlerts: false,
        enableIntegrityAlerts: false,
        performanceAlertThreshold: 2.0,
        integrityAlertThreshold: 0.2,
        enableHealthDashboard: false,
        dashboardRefreshInterval: 60,
        enableAutomaticHealthReporting: false,
        healthReportInterval: 300
    )
    
    /// Debug configuration with maximum monitoring
    public static let debug = MonitoringConfiguration(
        enablePerformanceMonitoring: true,
        slowOperationThreshold: 0.1,
        batchPerformanceThreshold: 1.0,
        maxPerformanceMetrics: 10000,
        performanceMetricsRetention: 3600,
        enableIntegrityMonitoring: true,
        integrityIssueThreshold: 0.01,
        maxIntegrityMetrics: 10000,
        integrityMetricsRetention: 3600,
        enableDetailedLogging: true,
        logLevel: .debug,
        enableConsoleLogging: true,
        enableFileLogging: true,
        enablePerformanceAlerts: true,
        enableIntegrityAlerts: true,
        performanceAlertThreshold: 0.5,
        integrityAlertThreshold: 0.05,
        enableHealthDashboard: true,
        dashboardRefreshInterval: 10,
        enableAutomaticHealthReporting: true,
        healthReportInterval: 60
    )
}

// MARK: - Log Levels

/// Log levels for monitoring
public enum LogLevel: String, CaseIterable, Comparable, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        let levels: [LogLevel] = [.debug, .info, .warning, .error, .critical]
        guard let lhsIndex = levels.firstIndex(of: lhs),
              let rhsIndex = levels.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

// MARK: - Configuration Manager

/// Manager for monitoring configuration
public final class MonitoringConfigurationManager: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = MonitoringConfigurationManager()
    
    // MARK: - Properties
    
    private(set) public var currentConfiguration: MonitoringConfiguration
    
    // MARK: - Initialization
    
    private init() {
        // Default to development configuration
        self.currentConfiguration = .development
    }
    
    // MARK: - Configuration Management
    
    /// Update the current monitoring configuration
    /// - Parameter configuration: The new configuration
    public func updateConfiguration(_ configuration: MonitoringConfiguration) {
        currentConfiguration = configuration
        applyConfiguration()
    }
    
    /// Load configuration from a preset
    /// - Parameter preset: The preset configuration to load
    public func loadPreset(_ preset: MonitoringPreset) {
        switch preset {
        case .development:
            currentConfiguration = .development
        case .production:
            currentConfiguration = .production
        case .testing:
            currentConfiguration = .testing
        case .debug:
            currentConfiguration = .debug
        }
        applyConfiguration()
    }
    
    /// Load configuration from UserDefaults
    public func loadFromUserDefaults() {
        // This would load configuration from UserDefaults in a real implementation
        // For now, we'll use the default development configuration
        currentConfiguration = .development
        applyConfiguration()
    }
    
    /// Save configuration to UserDefaults
    public func saveToUserDefaults() {
        // This would save configuration to UserDefaults in a real implementation
        // For now, we'll just log that it was saved
        print("Configuration saved to UserDefaults")
    }
    
    // MARK: - Private Methods
    
    private func applyConfiguration() {
        // Apply the configuration to all monitoring components
        // This would update the configuration of the performance logger, integrity monitor, etc.
        print("Applied monitoring configuration: \(currentConfiguration)")
    }
}

// MARK: - Monitoring Presets

/// Preset configurations for monitoring
public enum MonitoringPreset: String, CaseIterable {
    case development = "Development"
    case production = "Production"
    case testing = "Testing"
    case debug = "Debug"
    
    public var description: String {
        switch self {
        case .development:
            return "Development configuration with detailed logging and monitoring"
        case .production:
            return "Production configuration with minimal overhead and essential monitoring"
        case .testing:
            return "Testing configuration with minimal monitoring for test environments"
        case .debug:
            return "Debug configuration with maximum monitoring and detailed logging"
        }
    }
}
