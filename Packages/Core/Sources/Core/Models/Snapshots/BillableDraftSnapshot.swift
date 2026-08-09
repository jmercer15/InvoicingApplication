//
//  BillableDraftSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation

// MARK: - BillableDraftSnapshot

public struct BillableDraftSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let sessionId: UUID
    public let clientId: UUID
    public let clientPlanManagementType: String
    public let serviceId: UUID
    public let computedAt: Date
    public let billingContextSnapshot: Data
    public let draftStatus: String
    public let createdAt: Date
    public let updatedAt: Date?

    public init(
        id: UUID,
        sessionId: UUID,
        clientId: UUID,
        clientPlanManagementType: String = "",
        serviceId: UUID,
        computedAt: Date,
        billingContextSnapshot: Data,
        draftStatus: String,
        createdAt: Date,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.clientId = clientId
        self.clientPlanManagementType = clientPlanManagementType
        self.serviceId = serviceId
        self.computedAt = computedAt
        self.billingContextSnapshot = billingContextSnapshot
        self.draftStatus = draftStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

}

