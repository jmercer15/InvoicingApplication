import Foundation

public struct SupportLog: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let clientId: UUID
    public let sessionId: UUID?
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

    public init(
        id: UUID,
        clientId: UUID,
        sessionId: UUID? = nil,
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
        signatureMethod: String? = nil,
        signedBy: String? = nil,
        signedAt: Date? = nil,
        cancellationReasonCode: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.sessionId = sessionId
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
    }
}
