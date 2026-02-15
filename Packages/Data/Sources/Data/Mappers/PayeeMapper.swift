import Foundation
import Core

/// Maps between the `Payee` domain model and `PayeeEntity` persistence model.
public struct PayeeMapper: ModelMapper {
    public typealias DomainModel = Payee
    public typealias PersistenceEntity = PayeeEntity
    
    private let addressMapper = AddressMapper()
    
    public init() {}
    
    public func mapToDomain(_ entity: PayeeEntity) -> Payee {
        Payee(
            id: entity.id,
            fullName: entity.fullName,
            email: entity.email,
            phone: entity.phone,
            address: entity.address.map { addressMapper.mapToDomain($0) },
            status: entity.status,
            relationToClient: entity.relationToClient
        )
    }
    
    public func mapToEntity(_ domain: Payee) -> PayeeEntity {
        let entity = PayeeEntity(id: domain.id, fullName: domain.fullName)
        updateEntityProperties(entity, from: domain)
        return entity
    }
    
    public func updateEntity(_ entity: inout PayeeEntity, from domain: Payee) {
        updateEntityProperties(entity, from: domain)
    }
    
    private func updateEntityProperties(_ entity: PayeeEntity, from domain: Payee) {
        entity.fullName = domain.fullName
        entity.email = domain.email
        entity.phone = domain.phone
        entity.status = domain.status
        entity.relationToClient = domain.relationToClient
        // Note: Address relationship handled separately via repository
    }
}
