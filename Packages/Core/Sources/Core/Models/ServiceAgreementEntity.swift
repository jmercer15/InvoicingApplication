import Foundation
import SwiftData

@Model public class ServiceAgreement {
    #Index<ServiceAgreement>([\.effectiveFrom], [\.effectiveTo], [\.isArchived])

    public var id: UUID = UUID()
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

    @Relationship(deleteRule: .nullify, inverse: \Client.serviceAgreements) public var client: Client?

    public init(id: UUID = UUID()) {
        self.id = id
    }
    
    /// Returns a thread-safe snapshot of the ServiceAgreement.
    public func snapshot() -> ServiceAgreementSnapshot {
        ServiceAgreementSnapshot(self)
    }
}
