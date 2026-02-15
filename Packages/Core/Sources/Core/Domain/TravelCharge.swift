import Foundation

/// Domain model for a travel charge
public struct TravelCharge: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let sessionId: UUID
    public let clientId: UUID
    public let serviceId: UUID?
    public let amount: Double
    public let distance: Double?
    public let travelTime: TimeInterval?
    public let fromAddress: String?
    public let toAddress: String?
    public let status: TravelChargeStatus
    public let chargeType: String
    public let travelDirection: String
    public let vehicleType: String?
    public let participantCount: Int
    public let splitCosts: Bool
    public let parkingCost: Double
    public let tollCost: Double
    public let createdDate: Date
    public let lastModifiedDate: Date?
    public let notes: String?
    
    public init(
        id: UUID,
        sessionId: UUID,
        clientId: UUID,
        serviceId: UUID? = nil,
        amount: Double,
        distance: Double? = nil,
        travelTime: TimeInterval? = nil,
        fromAddress: String? = nil,
        toAddress: String? = nil,
        status: TravelChargeStatus = .pending,
        chargeType: String = "standard",
        travelDirection: String = "to_client",
        vehicleType: String? = nil,
        participantCount: Int = 1,
        splitCosts: Bool = false,
        parkingCost: Double = 0.0,
        tollCost: Double = 0.0,
        createdDate: Date = Date(),
        lastModifiedDate: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.clientId = clientId
        self.serviceId = serviceId
        self.amount = amount
        self.distance = distance
        self.travelTime = travelTime
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.status = status
        self.chargeType = chargeType
        self.travelDirection = travelDirection
        self.vehicleType = vehicleType
        self.participantCount = participantCount
        self.splitCosts = splitCosts
        self.parkingCost = parkingCost
        self.tollCost = tollCost
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
    public var sessionId: UUID?
    public var sessionTitle: String?
    public var clientName: String?
    public var reason: String?
    public var timestamp: Date?
    public var status: String
    public var overrideReason: String?
    public var overrideType: String?
    public var resolutionNotes: String?
    public var violationDetails: [String]?
    public var suggestedActions: [String]?
    public var overrideOptions: [String]?
    
    public init(
        id: UUID,
        sessionId: UUID? = nil,
        sessionTitle: String? = nil,
        clientName: String? = nil,
        reason: String? = nil,
        timestamp: Date? = nil,
        status: String = "pending",
        overrideReason: String? = nil,
        overrideType: String? = nil,
        resolutionNotes: String? = nil,
        violationDetails: [String]? = nil,
        suggestedActions: [String]? = nil,
        overrideOptions: [String]? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.sessionTitle = sessionTitle
        self.clientName = clientName
        self.reason = reason
        self.timestamp = timestamp
        self.status = status
        self.overrideReason = overrideReason
        self.overrideType = overrideType
        self.resolutionNotes = resolutionNotes
        self.violationDetails = violationDetails
        self.suggestedActions = suggestedActions
        self.overrideOptions = overrideOptions
    }
    
    public var hasViolations: Bool {
        !(violationDetails?.isEmpty ?? true)
    }
    
    public var violationCount: Int {
        violationDetails?.count ?? 0
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

// MARK: - Compliance & Review Models

/// Detailed violation information for compliance checking
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

/// Enhanced review item with detailed violation information (Domain version)
public struct DetailedReviewItem: Identifiable, Sendable {
    public let id: UUID
    public let session: Session
    public let clientName: String?
    public let reason: String
    public let violations: [ComplianceViolation]
    public let suggestedActions: [String]
    public let overrideOptions: [String]
    public let timestamp: Date
    
    public init(
        id: UUID = UUID(),
        session: Session,
        clientName: String? = nil,
        reason: String,
        violations: [ComplianceViolation],
        suggestedActions: [String],
        overrideOptions: [String],
        timestamp: Date
    ) {
        self.id = id
        self.session = session
        self.clientName = clientName
        self.reason = reason
        self.violations = violations
        self.suggestedActions = suggestedActions
        self.overrideOptions = overrideOptions
        self.timestamp = timestamp
    }
}
