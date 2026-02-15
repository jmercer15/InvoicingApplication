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
    public var timestamp: Date?
    public var summary: String?
    public var action: String?
    public var details: String?
    @Relationship(deleteRule: .nullify) public var charge: TravelChargeEntity?
    public init(id: UUID) {
        self.id = id
    }
}

public typealias TravelChargeAuditLogEntity = TravelChargeAuditLog
