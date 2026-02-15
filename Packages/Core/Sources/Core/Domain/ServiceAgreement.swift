import Foundation

public struct ServiceAgreement: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let clientId: UUID
    public var effectiveFrom: Date
    public var effectiveTo: Date?
    public var pricingDisclosureAcceptedAt: Date?
    public var cancellationPolicyType: String
    public var allowsProviderTravel: Bool
    public var allowsTelehealth: Bool
    public var allowsNonFaceToFace: Bool
    public var participantSignatoryName: String?
    public var participantSignatoryRole: String?
    public var signedAt: Date?
    public var signatureMethod: String?
    public var notes: String?
    public var isArchived: Bool

    public init(
        id: UUID,
        clientId: UUID,
        effectiveFrom: Date,
        effectiveTo: Date? = nil,
        pricingDisclosureAcceptedAt: Date? = nil,
        cancellationPolicyType: String = CancellationPolicyType.twoClearBusinessDays.rawValue,
        allowsProviderTravel: Bool = false,
        allowsTelehealth: Bool = false,
        allowsNonFaceToFace: Bool = false,
        participantSignatoryName: String? = nil,
        participantSignatoryRole: String? = nil,
        signedAt: Date? = nil,
        signatureMethod: String? = nil,
        notes: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.clientId = clientId
        self.effectiveFrom = effectiveFrom
        self.effectiveTo = effectiveTo
        self.pricingDisclosureAcceptedAt = pricingDisclosureAcceptedAt
        self.cancellationPolicyType = cancellationPolicyType
        self.allowsProviderTravel = allowsProviderTravel
        self.allowsTelehealth = allowsTelehealth
        self.allowsNonFaceToFace = allowsNonFaceToFace
        self.participantSignatoryName = participantSignatoryName
        self.participantSignatoryRole = participantSignatoryRole
        self.signedAt = signedAt
        self.signatureMethod = signatureMethod
        self.notes = notes
        self.isArchived = isArchived
    }
}
