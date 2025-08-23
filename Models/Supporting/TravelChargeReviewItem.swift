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
    public var id: UUID
    var reason: String?
    var timestamp: Date?
    var status: String = "pending" // pending, resolved, overridden, skipped
    var overrideReason: String?
    var overrideType: String?
    var resolutionNotes: String?
    
    // Enhanced fields for detailed compliance review
    var violations: [String]? // Array of violation rule names
    var violationDetails: [String]? // Array of violation descriptions
    var suggestedActions: [String]? // Array of suggested actions
    var overrideOptions: [String]? // Array of available override options
    
    @Relationship(deleteRule: .nullify, inverse: \SessionEntity.reviewItems) var session: SessionEntity?
    
    public init(id: UUID) {
        self.id = id
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if the review item has been resolved
    var isResolved: Bool {
        status != "pending"
    }
    
    /// Returns true if the review item has violations
    var hasViolations: Bool {
        guard let violations = violations else { return false }
        return !violations.isEmpty
    }
    
    /// Returns the number of violations
    var violationCount: Int {
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
