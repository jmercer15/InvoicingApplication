//
//  SupportLogSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

// MARK: - SupportLogSnapshot

public struct SupportLogSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let participantName: String
    public let participantNdisNumber: String
    public let supportItemNumber: String
    public let serviceDescription: String
    public let location: String
    public let deliveredFrom: Date
    public let deliveredTo: Date
    public let quantityHours: Double
    public let deliveredBy: String
    public let attestedBy: String
    public let attestedAt: Date
    public let signatureMethod: String?
    public let signedBy: String?
    public let signedAt: Date?
    public let cancellationReasonCode: String?
    public let notes: String?
    public let clientId: UUID?
    public let sessionId: UUID?

    public init(_ log: SupportLog) {
        self.id = log.id
        self.participantName = log.participantName
        self.participantNdisNumber = log.participantNdisNumber
        self.supportItemNumber = log.supportItemNumber
        self.serviceDescription = log.serviceDescription
        self.location = log.location
        self.deliveredFrom = log.deliveredFrom
        self.deliveredTo = log.deliveredTo
        self.quantityHours = log.quantityHours
        self.deliveredBy = log.deliveredBy
        self.attestedBy = log.attestedBy
        self.attestedAt = log.attestedAt
        self.signatureMethod = log.signatureMethod
        self.signedBy = log.signedBy
        self.signedAt = log.signedAt
        self.cancellationReasonCode = log.cancellationReasonCode
        self.notes = log.notes
        self.clientId = log.client?.id
        self.sessionId = log.session?.id
    }
}

