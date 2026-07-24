//
//  BillableDraftSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

// MARK: - BillableDraftSnapshot

public struct BillableDraftSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let sessionId: UUID
    public let clientId: UUID
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
        self.serviceId = serviceId
        self.computedAt = computedAt
        self.billingContextSnapshot = billingContextSnapshot
        self.draftStatus = draftStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(_ draft: BillableDraft) {
        self.id = draft.id
        self.sessionId = draft.sessionId
        self.clientId = draft.clientId
        self.serviceId = draft.serviceId
        self.computedAt = draft.computedAt
        self.billingContextSnapshot = draft.billingContextSnapshot
        self.draftStatus = draft.draftStatus
        self.createdAt = draft.createdAt
        self.updatedAt = draft.updatedAt
    }
}

