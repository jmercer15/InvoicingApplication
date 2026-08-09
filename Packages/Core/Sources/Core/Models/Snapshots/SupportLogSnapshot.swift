//
//  SupportLogSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation

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


    public init(
        id: UUID,
        participantName: String,
        participantNdisNumber: String,
        supportItemNumber: String,
        serviceDescription: String,
        location: String,
        deliveredFrom: Date,
        deliveredTo: Date,
        quantityHours: Double,
        deliveredBy: String,
        attestedBy: String,
        attestedAt: Date,
        signatureMethod: String?,
        signedBy: String?,
        signedAt: Date?,
        cancellationReasonCode: String?,
        notes: String?,
        clientId: UUID?,
        sessionId: UUID?
    ) {
        self.id = id
        self.participantName = participantName
        self.participantNdisNumber = participantNdisNumber
        self.supportItemNumber = supportItemNumber
        self.serviceDescription = serviceDescription
        self.location = location
        self.deliveredFrom = deliveredFrom
        self.deliveredTo = deliveredTo
        self.quantityHours = quantityHours
        self.deliveredBy = deliveredBy
        self.attestedBy = attestedBy
        self.attestedAt = attestedAt
        self.signatureMethod = signatureMethod
        self.signedBy = signedBy
        self.signedAt = signedAt
        self.cancellationReasonCode = cancellationReasonCode
        self.notes = notes
        self.clientId = clientId
        self.sessionId = sessionId
    }
}
