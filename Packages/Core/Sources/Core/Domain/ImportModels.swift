import Foundation

/// Public enum for import source types
public enum ImportSource: String, Codable, CaseIterable, Sendable, Identifiable {
    case clients
    case payees
    case services
    case ndisItems
    case invoices
    case sessions
    case allData
    case unknown

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .clients: return "Clients"
        case .payees: return "Payees"
        case .services: return "Services"
        case .ndisItems: return "NDIS Items"
        case .invoices: return "Invoices"
        case .sessions: return "Sessions"
        case .allData: return "All Data (Export)"
        case .unknown: return "Unknown"
        }
    }
}

/// Public wrapper for import results
public struct ImportResult: Codable, Sendable {
    public let source: ImportSource
    public let success: Bool
    public let successful: Int
    public let failed: Int
    public let importedCounts: [String: Int]
    public let messages: [String]
    public let fileName: String
    public let timestamp: Date

    public init(
        source: ImportSource,
        success: Bool,
        successful: Int,
        failed: Int,
        importedCounts: [String: Int] = [:],
        messages: [String],
        fileName: String,
        timestamp: Date = Date()
    ) {
        self.source = source
        self.success = success
        self.successful = successful
        self.failed = failed
        self.importedCounts = importedCounts
        self.messages = messages
        self.fileName = fileName
        self.timestamp = timestamp
    }
}
