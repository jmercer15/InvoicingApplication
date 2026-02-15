import Foundation
import Core

/// Maps between the `Address` domain model and `AddressEntity` persistence model.
public struct AddressMapper: ModelMapper {
    public typealias DomainModel = Address
    public typealias PersistenceEntity = AddressEntity
    
    public init() {}
    
    public func mapToDomain(_ entity: AddressEntity) -> Address {
        Address(
            id: entity.id,
            unitNumber: entity.unitNumber,
            streetNumber: entity.streetNumber,
            streetName: entity.streetName,
            suburb: entity.suburb,
            city: entity.city,
            state: entity.state,
            postcode: entity.postcode,
            country: entity.country,
            poBox: entity.poBox,
            latitude: entity.latitude,
            longitude: entity.longitude
        )
    }
    
    public func mapToEntity(_ domain: Address) -> AddressEntity {
        let entity = AddressEntity()
        entity.id = domain.id
        updateEntityProperties(entity, from: domain)
        return entity
    }
    
    public func updateEntity(_ entity: inout AddressEntity, from domain: Address) {
        updateEntityProperties(entity, from: domain)
    }
    
    private func updateEntityProperties(_ entity: AddressEntity, from domain: Address) {
        entity.unitNumber = domain.unitNumber
        entity.streetNumber = domain.streetNumber
        entity.streetName = domain.streetName
        entity.suburb = domain.suburb
        entity.city = domain.city
        entity.state = domain.state
        entity.postcode = domain.postcode
        entity.country = domain.country
        entity.poBox = domain.poBox
        entity.latitude = domain.latitude
        entity.longitude = domain.longitude
    }
}
