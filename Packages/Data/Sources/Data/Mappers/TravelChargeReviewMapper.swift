import Foundation
import Core

/// Maps between the `TravelChargeReviewItem` domain model and `TravelChargeReviewItemEntity` persistence model.
public struct TravelChargeReviewMapper: ModelMapper {
    public typealias DomainModel = Core.TravelChargeReviewItem
    public typealias PersistenceEntity = TravelChargeReviewItemEntity
    
    public init() {}
    
    public func mapToDomain(_ entity: TravelChargeReviewItemEntity) -> Core.TravelChargeReviewItem {
        return Core.TravelChargeReviewItem(
            id: entity.id,
            sessionId: entity.session?.id,
            sessionTitle: entity.session?.title,
            clientName: entity.session?.client?.fullName,
            reason: entity.reason,
            timestamp: entity.timestamp,
            status: entity.status,
            overrideReason: entity.overrideReason,
            overrideType: entity.overrideType,
            resolutionNotes: entity.resolutionNotes,
            violationDetails: entity.violationDetails,
            suggestedActions: entity.suggestedActions,
            overrideOptions: entity.overrideOptions
        )
    }
    
    public func mapToEntity(_ domain: TravelChargeReviewItem) -> TravelChargeReviewItemEntity {
        let entity = TravelChargeReviewItemEntity(id: domain.id)
        updateEntityProperties(entity, from: domain)
        return entity
    }
    
    public func updateEntity(_ entity: inout TravelChargeReviewItemEntity, from domain: TravelChargeReviewItem) {
        updateEntityProperties(entity, from: domain)
    }
    
    private func updateEntityProperties(_ entity: TravelChargeReviewItemEntity, from domain: TravelChargeReviewItem) {
        entity.reason = domain.reason
        entity.timestamp = domain.timestamp
        entity.status = domain.status
        entity.overrideReason = domain.overrideReason
        entity.overrideType = domain.overrideType
        entity.resolutionNotes = domain.resolutionNotes
        entity.violationDetails = domain.violationDetails
        entity.suggestedActions = domain.suggestedActions
        entity.overrideOptions = domain.overrideOptions
        
        // Note: Session relationship is handled separately via repository
    }
}
