import Foundation

public struct SupportLogDraft: Sendable {
    public var participantName: String = ""
    public var participantNdisNumber: String = ""
    public var supportItemNumber: String = ""
    public var serviceDescription: String = ""
    public var location: String = ""
    public var deliveredFrom: Date = Date()
    public var deliveredTo: Date = Date()
    public var quantityHours: Double = 1.0
    public var deliveredBy: String = ""
    public var attestedBy: String = ""
    public var attestedAt: Date = Date()
    public var signatureMethod: String? = "attestation"
    public var signedBy: String? = nil
    public var signedAt: Date? = nil
    public var cancellationReasonCode: String? = nil
    public var notes: String? = nil

    public init() {}

    public init(
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
        notes: String?
    ) {
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
