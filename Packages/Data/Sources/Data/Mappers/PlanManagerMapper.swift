import Foundation
import Core

/// Maps between the `PlanManager` domain model and `PlanManagerEntity` persistence model.
public struct PlanManagerMapper: ModelMapper {
    public typealias DomainModel = PlanManager
    public typealias PersistenceEntity = PlanManagerEntity
    
    private let addressMapper = AddressMapper()
    
    public init() {}
    
    public func mapToDomain(_ entity: PlanManagerEntity) -> PlanManager {
        PlanManager(
            id: entity.id,
            name: entity.name ?? "",
            email: entity.email,
            phone: entity.phone,
            address: entity.address.map { addressMapper.mapToDomain($0) },
            abn: entity.abn
        )
    }
    
    public func mapToEntity(_ domain: PlanManager) -> PlanManagerEntity {
        let entity = PlanManagerEntity(id: domain.id, abn: domain.abn)
        updateEntityProperties(entity, from: domain)
        return entity
    }
    
    public func updateEntity(_ entity: inout PlanManagerEntity, from domain: PlanManager) {
        updateEntityProperties(entity, from: domain)
    }
    
    private func updateEntityProperties(_ entity: PlanManagerEntity, from domain: PlanManager) {
        entity.name = domain.name
        entity.email = domain.email
        entity.phone = domain.phone
        // Note: Address relationship handled separately via repository
    }
}
