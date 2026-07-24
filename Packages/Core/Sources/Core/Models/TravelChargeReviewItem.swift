//
//  TravelChargeReviewItem.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class TravelChargeReviewItem {
    public var id: UUID = UUID()
    public var reason: String?
    public var timestamp: Date?
    public var status: String = "pending" // pending, resolved, overridden, skipped
    public var overrideReason: String?
    public var overrideType: String?
    public var resolutionNotes: String?

    // Snapshot fields for decoupled review (Sendable safety)
    public var sessionID: UUID?
    public var sessionTitle: String?
    public var clientName: String?

    // Enhanced fields for detailed compliance review
    // Store as Data to avoid Core Data Array materialization issues
    public var violationsData: Data? // JSON encoded [String] of violation rule names
    public var violationDetailsData: Data? // JSON encoded [String] of violation descriptions
    public var suggestedActionsData: Data? // JSON encoded [String] of suggested actions
    public var overrideOptionsData: Data? // JSON encoded [String] of available override options
    
    // Computed properties for easy access
    public var violations: [String]? {
        get {
            guard let data = violationsData else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            violationsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    public var violationDetails: [String]? {
        get {
            guard let data = violationDetailsData else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            violationDetailsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    public var suggestedActions: [String]? {
        get {
            guard let data = suggestedActionsData else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            suggestedActionsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    public var overrideOptions: [String]? {
        get {
            guard let data = overrideOptionsData else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            overrideOptionsData = try? JSONEncoder().encode(newValue)
        }
    }

    @Relationship(deleteRule: .nullify, inverse: \Session.reviewItems) public var session: Session?
    
    public init(
        id: UUID = UUID(),
        reason: String? = nil,
        status: String = "pending",
        session: Session? = nil,
        sessionID: UUID? = nil,
        sessionTitle: String? = nil,
        clientName: String? = nil,
        violations: [String]? = nil,
        suggestedActions: [String]? = nil,
        timestamp: Date? = Date()
    ) {
        self.id = id
        self.reason = reason
        self.status = status
        self.session = session
        self.sessionID = sessionID ?? session?.id
        self.sessionTitle = sessionTitle ?? session?.title
        self.clientName = clientName ?? session?.client?.fullName
        self.violations = violations
        self.suggestedActions = suggestedActions
        self.timestamp = timestamp
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if the review item has violations
    public var hasViolations: Bool {
        guard let violations = violations else { return false }
        return !violations.isEmpty
    }
    
    /// Returns the number of violations
    public var violationCount: Int {
        violations?.count ?? 0
    }
    
    // MARK: - Helper Methods
    
    /// Returns a thread-safe snapshot of the TravelChargeReviewItem.
    public func snapshot() -> TravelChargeReviewSnapshot {
        TravelChargeReviewSnapshot(self)
    }
}
