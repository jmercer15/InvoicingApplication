import Foundation
import Core

/// Maps between `InvoiceItem` domain model and `InvoiceItemEntity` persistence model.
public struct InvoiceItemMapper: ModelMapper {
    public typealias DomainModel = InvoiceItem
    public typealias PersistenceEntity = InvoiceItemEntity
    
    public init() {}
    
    public func mapToDomain(_ entity: InvoiceItemEntity) -> InvoiceItem {
        InvoiceItem(
            id: entity.id,
            invoiceId: entity.invoice?.id ?? UUID(),
            sessionId: entity.session?.id,
            clientServiceId: entity.clientService?.id,
            itemDescription: entity.itemDescription,
            quantity: entity.quantity,
            rate: entity.rate,
            position: entity.position,
            serviceDate: entity.serviceDate,
            ndisItemNumber: entity.ndisItemNumber,
            claimType: entity.claimType?.rawValue,
            unit: entity.unit,
            gstCode: entity.gstCode,
            taxRate: entity.taxRate,
            ndisSupportCategory: entity.ndisSupportCategory,
            ndisRegistrationGroup: entity.ndisRegistrationGroup,
            ndisOutcomeDomain: entity.ndisOutcomeDomain,
            ndisSupportPurpose: entity.ndisSupportPurpose,
            isComplexBehaviour: entity.isComplexBehaviour,
            isHighIntensity: entity.isHighIntensity,
            geographicLoading: entity.geographicLoading,
            timeModifier: entity.timeModifier,
            groupModifier: entity.groupModifier,
            finalRateLimit: entity.finalRateLimit
        )
    }
    
    public func mapToEntity(_ domain: InvoiceItem) -> InvoiceItemEntity {
        let entity = InvoiceItemEntity(id: domain.id, itemDescription: domain.itemDescription)
        updateEntityProperties(entity, from: domain)
        return entity
    }
    
    public func updateEntity(_ entity: inout InvoiceItemEntity, from domain: InvoiceItem) {
        updateEntityProperties(entity, from: domain)
    }
    
    private func updateEntityProperties(_ entity: InvoiceItemEntity, from domain: InvoiceItem) {
        entity.itemDescription = domain.itemDescription
        entity.quantity = domain.quantity
        entity.rate = domain.rate
        entity.unit = domain.unit
        entity.serviceDate = domain.serviceDate
        entity.position = domain.position
        entity.taxRate = domain.taxRate
        entity.gstCode = domain.gstCode
        entity.ndisItemNumber = domain.ndisItemNumber
        entity.claimType = domain.claimType.flatMap { NDISClaimType(rawValue: $0) }
        entity.ndisSupportCategory = domain.ndisSupportCategory
        entity.ndisRegistrationGroup = domain.ndisRegistrationGroup
        entity.ndisOutcomeDomain = domain.ndisOutcomeDomain
        entity.ndisSupportPurpose = domain.ndisSupportPurpose
        entity.isComplexBehaviour = domain.isComplexBehaviour
        entity.isHighIntensity = domain.isHighIntensity
        entity.geographicLoading = domain.geographicLoading
        entity.timeModifier = domain.timeModifier
        entity.groupModifier = domain.groupModifier
        entity.finalRateLimit = domain.finalRateLimit
        // Note: Relationships handled separately
    }
}
