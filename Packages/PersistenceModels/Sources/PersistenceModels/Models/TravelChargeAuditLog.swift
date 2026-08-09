//
//  TravelChargeAuditLog.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import Core
import SwiftData


@Model public class TravelChargeAuditLog {
    public var id: UUID = UUID()
    public var timestamp: Date?
    public var summary: String?
    public var action: String?
    public var details: String?
    @Relationship(deleteRule: .nullify, inverse: \TravelCharge.auditLogs) public var charge: TravelCharge?
    public init(
        id: UUID = UUID(),
        travelChargeId: UUID? = nil,
        action: String? = nil,
        timestamp: Date? = nil,
        details: String? = nil,
        performedBy: String? = nil
    ) {
        self.id = id
        self.action = action
        self.timestamp = timestamp
        self.details = details
        self.summary = performedBy
        _ = travelChargeId
    }
    
    /// Returns a thread-safe snapshot of the TravelChargeAuditLog.
    public func snapshot() -> TravelChargeAuditLogSnapshot {
        TravelChargeAuditLogSnapshot(self)
    }
}
