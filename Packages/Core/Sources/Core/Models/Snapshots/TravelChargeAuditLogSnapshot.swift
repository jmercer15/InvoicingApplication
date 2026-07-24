//
//  TravelChargeAuditLogSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

// MARK: - TravelChargeAuditLogSnapshot

public struct TravelChargeAuditLogSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let timestamp: Date?
    public let summary: String?
    public let action: String?
    public let details: String?
    public let travelChargeId: UUID?

    public init(
        id: UUID,
        timestamp: Date? = nil,
        summary: String? = nil,
        action: String? = nil,
        details: String? = nil,
        travelChargeId: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.summary = summary
        self.action = action
        self.details = details
        self.travelChargeId = travelChargeId
    }

    public init(_ log: TravelChargeAuditLog) {
        self.id = log.id
        self.timestamp = log.timestamp
        self.summary = log.summary
        self.action = log.action
        self.details = log.details
        self.travelChargeId = log.charge?.id
    }
}

