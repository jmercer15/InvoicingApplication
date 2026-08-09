//
//  TravelChargeReviewSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation

// MARK: - TravelChargeReviewSnapshot

public struct TravelChargeReviewSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let reason: String?
    public let timestamp: Date?
    public let status: String
    public let overrideReason: String?
    public let overrideType: String?
    public let resolutionNotes: String?
    public let sessionID: UUID?
    public let sessionTitle: String?
    public let clientName: String?
    public let violations: [String]?
    public let violationDetails: [String]?
    public let suggestedActions: [String]?
    public let overrideOptions: [String]?
    public let sessionId: UUID?

    public init(
        id: UUID,
        reason: String? = nil,
        timestamp: Date? = nil,
        status: String = "pending",
        overrideReason: String? = nil,
        overrideType: String? = nil,
        resolutionNotes: String? = nil,
        sessionID: UUID? = nil,
        sessionTitle: String? = nil,
        clientName: String? = nil,
        violations: [String]? = nil,
        violationDetails: [String]? = nil,
        suggestedActions: [String]? = nil,
        overrideOptions: [String]? = nil,
        sessionId: UUID? = nil
    ) {
        self.id = id
        self.reason = reason
        self.timestamp = timestamp
        self.status = status
        self.overrideReason = overrideReason
        self.overrideType = overrideType
        self.resolutionNotes = resolutionNotes
        self.sessionID = sessionID
        self.sessionTitle = sessionTitle
        self.clientName = clientName
        self.violations = violations
        self.violationDetails = violationDetails
        self.suggestedActions = suggestedActions
        self.overrideOptions = overrideOptions
        self.sessionId = sessionId
    }

}

