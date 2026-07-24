//
//  ClientServiceSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

// MARK: - ClientServiceSnapshot

public struct ClientServiceSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let serviceName: String
    public let ndisCode: String?
    public let unit: String
    public let rate: Double
    public let isActive: Bool
    public let startDate: Date?
    public let endDate: Date?
    public let isDefault: Bool
    public let ndisItemNumber: String?
    public let gstCode: String?
    public let status: String?
    public let clientId: UUID?
    public let ndisItemId: UUID?

    public init(_ service: ClientService) {
        self.id = service.id
        self.serviceName = service.serviceName
        self.ndisCode = service.ndisCode
        self.unit = service.unit
        self.rate = service.rate
        self.isActive = service.isActive
        self.startDate = service.startDate
        self.endDate = service.endDate
        self.isDefault = service.isDefault
        self.ndisItemNumber = service.ndisItemNumber
        self.gstCode = service.gstCode
        self.status = service.status
        self.clientId = service.client?.id
        self.ndisItemId = service.ndisItem?.id
    }
}

