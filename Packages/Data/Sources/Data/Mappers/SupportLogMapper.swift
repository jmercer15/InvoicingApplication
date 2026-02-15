import Foundation
import Core

public struct SupportLogMapper: ModelMapper {
    public typealias DomainModel = SupportLog
    public typealias PersistenceEntity = SupportLogEntity

    public init() {}

    public func mapToDomain(_ entity: SupportLogEntity) -> SupportLog {
        SupportLog(
            id: entity.id,
            clientId: entity.client?.id ?? UUID(),
            sessionId: entity.session?.id,
            participantName: entity.participantName,
            participantNdisNumber: entity.participantNdisNumber,
            supportItemNumber: entity.supportItemNumber,
            serviceDescription: entity.serviceDescription,
            location: entity.location,
            deliveredFrom: entity.deliveredFrom,
            deliveredTo: entity.deliveredTo,
            quantityHours: entity.quantityHours,
            deliveredBy: entity.deliveredBy,
            attestedBy: entity.attestedBy,
            attestedAt: entity.attestedAt,
            signatureMethod: entity.signatureMethod,
            signedBy: entity.signedBy,
            signedAt: entity.signedAt,
            cancellationReasonCode: entity.cancellationReasonCode,
            notes: entity.notes
        )
    }

    public func mapToEntity(_ domain: SupportLog) -> SupportLogEntity {
        let entity = SupportLogEntity(id: domain.id)
        updateEntityProperties(entity, from: domain)
        return entity
    }

    public func updateEntity(_ entity: inout SupportLogEntity, from domain: SupportLog) {
        updateEntityProperties(entity, from: domain)
    }

    private func updateEntityProperties(_ entity: SupportLogEntity, from domain: SupportLog) {
        entity.participantName = domain.participantName
        entity.participantNdisNumber = domain.participantNdisNumber
        entity.supportItemNumber = domain.supportItemNumber
        entity.serviceDescription = domain.serviceDescription
        entity.location = domain.location
        entity.deliveredFrom = domain.deliveredFrom
        entity.deliveredTo = domain.deliveredTo
        entity.quantityHours = domain.quantityHours
        entity.deliveredBy = domain.deliveredBy
        entity.attestedBy = domain.attestedBy
        entity.attestedAt = domain.attestedAt
        entity.signatureMethod = domain.signatureMethod
        entity.signedBy = domain.signedBy
        entity.signedAt = domain.signedAt
        entity.cancellationReasonCode = domain.cancellationReasonCode
        entity.notes = domain.notes
    }
}
