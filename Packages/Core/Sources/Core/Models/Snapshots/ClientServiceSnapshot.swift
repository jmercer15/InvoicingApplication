//
//  ClientServiceSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation

// MARK: - ClientServiceSnapshot

public struct ClientServiceSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let serviceName: String
    public let ndisCode: String?
    public let unit: String
    public let rate: Decimal
    public let isActive: Bool
    public let startDate: Date?
    public let endDate: Date?
    public let isDefault: Bool
    public let ndisItemNumber: String?
    public let gstCode: String?
    public let consecutiveMonths: Int?
    public let status: String?
    public let clientId: UUID?
    public let ndisItemId: UUID?


    public init(
        id: UUID,
        serviceName: String,
        ndisCode: String?,
        unit: String,
        rate: Decimal,
        isActive: Bool,
        startDate: Date?,
        endDate: Date?,
        isDefault: Bool,
        ndisItemNumber: String?,
        gstCode: String?,
        consecutiveMonths: Int?,
        status: String?,
        clientId: UUID?,
        ndisItemId: UUID?
    ) {
        self.id = id
        self.serviceName = serviceName
        self.ndisCode = ndisCode
        self.unit = unit
        self.rate = rate
        self.isActive = isActive
        self.startDate = startDate
        self.endDate = endDate
        self.isDefault = isDefault
        self.ndisItemNumber = ndisItemNumber
        self.gstCode = gstCode
        self.consecutiveMonths = consecutiveMonths
        self.status = status
        self.clientId = clientId
        self.ndisItemId = ndisItemId
    }

}
