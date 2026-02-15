//
//  TravelChargeReviewItem.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class TravelChargeReviewItemEntity {
    public var id: UUID
    public var reason: String?
    public var timestamp: Date?
    public var status: String = "pending" // pending, resolved, overridden, skipped
    public var overrideReason: String?
    public var overrideType: String?
    public var resolutionNotes: String?

    // Enhanced fields for detailed compliance review
    // Store as Data to avoid Core Data Array materialization issues
    public var violationsData: Data? // JSON encoded [String] of violation rule names
    public var violationDetailsData: Data? // JSON encoded [String] of violation descriptions
    public var suggestedActionsData: Data? // JSON encoded [String] of suggested actions
    public var overrideOptionsData: Data? // JSON encoded [String] of available override options
    
    // Computed properties for easy access
    var violations: [String]? {
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

    @Relationship(deleteRule: .nullify, inverse: \SessionEntity.reviewItems) public var session: SessionEntity?
    
    public init(id: UUID) {
        self.id = id
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if the review item has been resolved
    var isResolved: Bool {
        status != "pending"
    }
    
    /// Returns true if the review item has violations
    public var hasViolations: Bool {
        guard let violations = violations else { return false }
        return !violations.isEmpty
    }
    
    /// Returns the number of violations
    public var violationCount: Int {
        violations?.count ?? 0
    }
    
    /// Returns a formatted summary of the review item
    var summary: String {
        let sessionTitle = session?.title ?? "Unknown Session"
        let clientName = session?.client?.fullName ?? "Unknown Client"
        return "\(sessionTitle) - \(clientName) - \(reason ?? "No reason")"
    }
    
    // MARK: - Helper Methods
    
    /// Marks the review item as resolved with the given status and notes
    func resolve(status: String, notes: String? = nil) {
        self.status = status
        self.resolutionNotes = notes
        self.timestamp = Date()
    }
    
    /// Applies an override with the given type and reason
    func applyOverride(type: String, reason: String? = nil) {
        self.status = "overridden"
        self.overrideType = type
        self.overrideReason = reason
        self.timestamp = Date()
    }
    
    /// Marks the review item as skipped
    func skip(reason: String? = nil) {
        self.status = "skipped"
        self.resolutionNotes = reason
        self.timestamp = Date()
    }
}
