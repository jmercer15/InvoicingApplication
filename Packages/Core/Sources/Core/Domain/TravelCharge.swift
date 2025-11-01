import Foundation

/// Domain model for a travel charge
public struct TravelCharge: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let sessionId: UUID
    public let amount: Double
    public let distance: Double?
    public let travelTime: TimeInterval?
    public let fromAddress: String?
    public let toAddress: String?
    public let status: TravelChargeStatus
    public let createdDate: Date
    public let lastModifiedDate: Date?
    public let notes: String?
    
    public init(
        id: UUID,
        sessionId: UUID,
        amount: Double,
        distance: Double? = nil,
        travelTime: TimeInterval? = nil,
        fromAddress: String? = nil,
        toAddress: String? = nil,
        status: TravelChargeStatus = .pending,
        createdDate: Date = Date(),
        lastModifiedDate: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.amount = amount
        self.distance = distance
        self.travelTime = travelTime
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.status = status
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
        self.notes = notes
    }
}

/// Status of a travel charge
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

/// Domain model for a travel charge review item
public struct TravelChargeReviewItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let travelChargeId: UUID
    public let hasViolations: Bool
    public let violationDescription: String?
    public let reviewDate: Date
    public let reviewedBy: String?
    
    public init(
        id: UUID,
        travelChargeId: UUID,
        hasViolations: Bool = false,
        violationDescription: String? = nil,
        reviewDate: Date = Date(),
        reviewedBy: String? = nil
    ) {
        self.id = id
        self.travelChargeId = travelChargeId
        self.hasViolations = hasViolations
        self.violationDescription = violationDescription
        self.reviewDate = reviewDate
        self.reviewedBy = reviewedBy
    }
}

/// Domain model for a travel charge audit log entry
public struct TravelChargeAuditLog: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let travelChargeId: UUID
    public let action: String
    public let timestamp: Date
    public let details: String?
    public let performedBy: String?
    
    public init(
        id: UUID,
        travelChargeId: UUID,
        action: String,
        timestamp: Date = Date(),
        details: String? = nil,
        performedBy: String? = nil
    ) {
        self.id = id
        self.travelChargeId = travelChargeId
        self.action = action
        self.timestamp = timestamp
        self.details = details
        self.performedBy = performedBy
    }
}
