import Foundation

/// Use case for importing all data
public struct ImportAllData: Sendable {
    private let importer: DataImporter
    
    public init(importer: DataImporter) {
        self.importer = importer
    }
    
    /// Import all data from external sources
    public func callAsFunction() async throws -> ImportResult {
        try await importer.importAllData()
    }
}

/// Protocol for data import operations
public protocol DataImporter: Sendable {
    func importAllData() async throws -> ImportResult
}

/// Result of data import operation
public struct ImportResult: Codable, Sendable {
    public let success: Bool
    public let importedCounts: [String: Int]
    public let errors: [String]
    public let timestamp: Date
    
    public init(success: Bool, importedCounts: [String: Int], errors: [String], timestamp: Date = Date()) {
        self.success = success
        self.importedCounts = importedCounts
        self.errors = errors
        self.timestamp = timestamp
    }
}
