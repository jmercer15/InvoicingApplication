//
//  TravelChargeAuditLog.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class TravelChargeAuditLog {
    public var id: UUID
    var timestamp: Date?
    var summary: String?
    var action: String?
    var details: String?
    @Relationship(deleteRule: .nullify, inverse: \TravelChargeEntity.auditLogs) var charge: TravelChargeEntity?
    public init(id: UUID) {
        self.id = id
    }
}
