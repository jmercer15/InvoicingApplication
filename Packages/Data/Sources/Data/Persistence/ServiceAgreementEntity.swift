import Foundation
import SwiftData

@Model public class ServiceAgreementEntity {
    #Index<ServiceAgreementEntity>([\.effectiveFrom], [\.effectiveTo], [\.isArchived])

    public var id: UUID
    public var effectiveFrom: Date = Date()
    public var effectiveTo: Date?
    public var pricingDisclosureAcceptedAt: Date?
    public var cancellationPolicyType: String = "2_clear_business_days"
    public var allowsProviderTravel: Bool = false
    public var allowsTelehealth: Bool = false
    public var allowsNonFaceToFace: Bool = false
    public var participantSignatoryName: String?
    public var participantSignatoryRole: String?
    public var signedAt: Date?
    public var signatureMethod: String?
    public var notes: String?
    public var isArchived: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \ClientEntity.serviceAgreements) public var client: ClientEntity?

    public init(id: UUID) {
        self.id = id
    }
}
