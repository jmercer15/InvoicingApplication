import Foundation
import Core

/// Maps between the `ClientService` domain model and `ClientServiceEntity` persistence model.
public struct ClientServiceMapper: ModelMapper {
    public typealias DomainModel = ClientService
    public typealias PersistenceEntity = ClientServiceEntity
    
    public init() {}
    
    public func mapToDomain(_ entity: ClientServiceEntity) -> ClientService {
        ClientService(
            id: entity.id,
            clientId: entity.client?.id ?? UUID(),
            serviceName: entity.serviceName,
            rate: entity.rate,
            unit: entity.unit,
            status: entity.status,
            isActive: entity.isActive,
            startDate: entity.startDate,
            endDate: entity.endDate,
            ndisItemId: entity.ndisItem?.id,
            ndisCode: entity.ndisCode
        )
    }
    
    public func mapToEntity(_ domain: ClientService) -> ClientServiceEntity {
        let entity = ClientServiceEntity(
            id: domain.id,
            serviceName: domain.serviceName,
            unit: domain.unit,
            rate: domain.rate
        )
        updateEntityProperties(entity, from: domain)
        return entity
    }
    
    public func updateEntity(_ entity: inout ClientServiceEntity, from domain: ClientService) {
        updateEntityProperties(entity, from: domain)
    }
    
    private func updateEntityProperties(_ entity: ClientServiceEntity, from domain: ClientService) {
        entity.serviceName = domain.serviceName
        entity.rate = domain.rate
        entity.unit = domain.unit
        entity.status = domain.status
        entity.isActive = domain.isActive
        entity.startDate = domain.startDate
        entity.endDate = domain.endDate
        entity.ndisCode = domain.ndisCode
        // Note: Client and NDISItem relationships handled separately via repository
    }
}
