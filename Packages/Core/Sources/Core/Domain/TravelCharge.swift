import Foundation

// TravelCharge, TravelChargeReviewItem, TravelChargeAuditLog domain structs removed.
// Use the SwiftData @Model equivalents (Packages/Data) as the primary domain types.

// MARK: - Travel Charge Status

public enum TravelChargeStatus: String, CaseIterable, Codable, Sendable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    case paid = "paid"
    
    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .paid: return "Paid"
        }
    }
}

// MARK: - Compliance & Review Value Types (retained — pure domain logic, no @Model counterpart)

/// Detailed violation information for compliance checking.
public struct ComplianceViolation: Sendable, Codable, Equatable {
    public let rule: String
    public let currentValue: String
    public let limit: String
    public let description: String
    public let severity: ViolationSeverity

    public enum ViolationSeverity: String, Sendable, Codable, Equatable {
        case warning
        case error
        case critical
    }

    public init(rule: String, currentValue: String, limit: String, description: String, severity: ViolationSeverity) {
        self.rule = rule
        self.currentValue = currentValue
        self.limit = limit
        self.description = description
        self.severity = severity
    }
}

/// Enhanced review item with detailed violation information — used as a transient result type
/// by the compliance engine. Not persisted; the @Model `TravelChargeReviewItem` holds the
/// persisted representation.
public struct DetailedReviewItem: Identifiable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let sessionTitle: String
    public let clientName: String?
    public let reason: String
    public let violations: [ComplianceViolation]
    public let suggestedActions: [String]
    public let overrideOptions: [String]
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        sessionTitle: String,
        clientName: String? = nil,
        reason: String,
        violations: [ComplianceViolation],
        suggestedActions: [String],
        overrideOptions: [String],
        timestamp: Date
    ) {
        self.id = id
        self.sessionID = sessionID
        self.sessionTitle = sessionTitle
        self.clientName = clientName
        self.reason = reason
        self.violations = violations
        self.suggestedActions = suggestedActions
        self.overrideOptions = overrideOptions
        self.timestamp = timestamp
    }
}
