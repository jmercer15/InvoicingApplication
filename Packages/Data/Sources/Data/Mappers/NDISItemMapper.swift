import Foundation
import Core

/// Maps between the `NDISItem` domain model and `NDISItemEntity` persistence model.
public struct NDISItemMapper: ModelMapper {
    public typealias DomainModel = NDISItem
    public typealias PersistenceEntity = NDISItemEntity
    
    public init() {}
    
    public func mapToDomain(_ entity: NDISItemEntity) -> NDISItem {
        let regionalPrices = entity.regionalPrices.map { priceEntity in
            RegionalPriceSnapshot(
                regionIdentifier: priceEntity.regionIdentifier ?? "",
                amount: priceEntity.amount
            )
        }
        
        return NDISItem(
            id: entity.id,
            itemNumber: entity.itemNumber,
            name: entity.name,
            description: entity.itemDescription,
            category: entity.category,
            unit: entity.unit,
            price: regionalPrices.first?.amount,
            isCurrent: entity.isCurrent,
            effectiveStartDate: entity.effectiveStartDate,
            effectiveEndDate: entity.effectiveEndDate,
            nonFaceToFaceProvision: entity.nonFaceToFaceProvision,
            providerTravel: entity.providerTravel,
            allowsNonFaceToFace: entity.nonFaceToFaceProvision,
            ndiaRequestedReports: entity.ndiaRequestedReports,
            irregularSILSupports: entity.irregularSILSupports,
            shortNoticeCancellations: entity.shortNoticeCancellations,
            legacyTransitionDate: nil,
            quoteRequired: entity.quoteRequired,
            status: entity.status,
            regionalPrices: regionalPrices,
            features: entity.features,
            registrationGroup: entity.registrationGroup,
            categoryNamePACE: entity.categoryNamePACE,
            categoryNumberPACE: entity.categoryNumberPACE,
            categoryNumber: entity.categoryNumber,
            registrationGroupNumber: entity.registrationGroupNumber,
            type: entity.type
        )
    }
    
    public func mapToEntity(_ domain: NDISItem) -> NDISItemEntity {
        let versionId = "\(domain.itemNumber)_\(domain.effectiveStartDate?.timeIntervalSince1970 ?? 0)"
        let entity = NDISItemEntity(
            id: domain.id,
            itemNumber: domain.itemNumber,
            name: domain.name,
            versionIdentifier: versionId
        )
        updateEntityProperties(entity, from: domain)
        return entity
    }
    
    public func updateEntity(_ entity: inout NDISItemEntity, from domain: NDISItem) {
        updateEntityProperties(entity, from: domain)
    }
    
    private func updateEntityProperties(_ entity: NDISItemEntity, from domain: NDISItem) {
        entity.name = domain.name
        entity.itemDescription = domain.description
        entity.category = domain.category
        entity.unit = domain.unit
        entity.isCurrent = domain.isCurrent
        entity.effectiveStartDate = domain.effectiveStartDate
        entity.effectiveEndDate = domain.effectiveEndDate
        entity.nonFaceToFaceProvision = domain.nonFaceToFaceProvision
        entity.providerTravel = domain.providerTravel
        entity.ndiaRequestedReports = domain.ndiaRequestedReports
        entity.irregularSILSupports = domain.irregularSILSupports
        entity.shortNoticeCancellations = domain.shortNoticeCancellations
        entity.quoteRequired = domain.quoteRequired
        entity.status = domain.status
        entity.features = domain.features
        entity.registrationGroup = domain.registrationGroup
        entity.categoryNamePACE = domain.categoryNamePACE
        entity.categoryNumberPACE = domain.categoryNumberPACE
        entity.categoryNumber = domain.categoryNumber
        entity.registrationGroupNumber = domain.registrationGroupNumber
        entity.type = domain.type
        // Note: RegionalPrices relationship handled separately
    }
}
