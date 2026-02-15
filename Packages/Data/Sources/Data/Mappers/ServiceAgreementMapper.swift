import Foundation
import Core

public struct ServiceAgreementMapper: ModelMapper {
    public typealias DomainModel = ServiceAgreement
    public typealias PersistenceEntity = ServiceAgreementEntity

    public init() {}

    public func mapToDomain(_ entity: ServiceAgreementEntity) -> ServiceAgreement {
        ServiceAgreement(
            id: entity.id,
            clientId: entity.client?.id ?? UUID(),
            effectiveFrom: entity.effectiveFrom,
            effectiveTo: entity.effectiveTo,
            pricingDisclosureAcceptedAt: entity.pricingDisclosureAcceptedAt,
            cancellationPolicyType: entity.cancellationPolicyType,
            allowsProviderTravel: entity.allowsProviderTravel,
            allowsTelehealth: entity.allowsTelehealth,
            allowsNonFaceToFace: entity.allowsNonFaceToFace,
            participantSignatoryName: entity.participantSignatoryName,
            participantSignatoryRole: entity.participantSignatoryRole,
            signedAt: entity.signedAt,
            signatureMethod: entity.signatureMethod,
            notes: entity.notes,
            isArchived: entity.isArchived
        )
    }

    public func mapToEntity(_ domain: ServiceAgreement) -> ServiceAgreementEntity {
        let entity = ServiceAgreementEntity(id: domain.id)
        updateEntityProperties(entity, from: domain)
        return entity
    }

    public func updateEntity(_ entity: inout ServiceAgreementEntity, from domain: ServiceAgreement) {
        updateEntityProperties(entity, from: domain)
    }

    private func updateEntityProperties(_ entity: ServiceAgreementEntity, from domain: ServiceAgreement) {
        entity.effectiveFrom = domain.effectiveFrom
        entity.effectiveTo = domain.effectiveTo
        entity.pricingDisclosureAcceptedAt = domain.pricingDisclosureAcceptedAt
        entity.cancellationPolicyType = domain.cancellationPolicyType
        entity.allowsProviderTravel = domain.allowsProviderTravel
        entity.allowsTelehealth = domain.allowsTelehealth
        entity.allowsNonFaceToFace = domain.allowsNonFaceToFace
        entity.participantSignatoryName = domain.participantSignatoryName
        entity.participantSignatoryRole = domain.participantSignatoryRole
        entity.signedAt = domain.signedAt
        entity.signatureMethod = domain.signatureMethod
        entity.notes = domain.notes
        entity.isArchived = domain.isArchived
    }
}
