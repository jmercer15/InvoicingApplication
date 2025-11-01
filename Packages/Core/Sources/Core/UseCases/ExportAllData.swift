import Foundation

/// Use case for exporting all data
public struct ExportAllData: Sendable {
    private let exporter: DataExporter
    
    public init(exporter: DataExporter) {
        self.exporter = exporter
    }
    
    /// Export all data to external format
    public func callAsFunction() async throws -> ExportResult {
        try await exporter.exportAllData()
    }
}

/// Protocol for data export operations
public protocol DataExporter: Sendable {
    func exportAllData() async throws -> ExportResult
}

/// Result of data export operation
public struct ExportResult: Codable, Sendable {
    public let success: Bool
    public let filePath: String?
    public let exportedCounts: [String: Int]
    public let errors: [String]
    public let timestamp: Date
    
    public init(success: Bool, filePath: String? = nil, exportedCounts: [String: Int], errors: [String], timestamp: Date = Date()) {
        self.success = success
        self.filePath = filePath
        self.exportedCounts = exportedCounts
        self.errors = errors
        self.timestamp = timestamp
    }
}
