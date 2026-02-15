import Foundation
import Core

/// Maps between the `Session` domain model (struct) and `SessionEntity` persistence model (SwiftData class).
public struct SessionMapper: ModelMapper {
    public typealias DomainModel = Session
    public typealias PersistenceEntity = SessionEntity
    
    public init() {}
    
    // MARK: - ModelMapper Protocol
    
    public func mapToDomain(_ entity: SessionEntity) -> Session {
        // Prioritize linked TravelChargeEntity if available (use the most recently added one)
        let travelCharge = entity.travelCharges.last
        
        // Convert travel duration from seconds (TravelCharge) to minutes (Session)
        let travelTimeMinutes: Double? = {
            if let duration = travelCharge?.travelDuration {
                return duration / 60.0
            }
            return entity.travelTimeMinutes
        }()
        
        return Session(
            id: entity.id,
            title: entity.title,
            startTime: entity.startTime,
            endTime: entity.endTime,
            isAllDay: entity.isAllDay,
            location: entity.location,
            notes: entity.notes,
            status: entity.status?.rawValue,
            isTravel: entity.isTravel,
            isDetached: entity.isDetached,
            occurrenceDate: entity.occurrenceDate,
            clientId: entity.client?.id,
            clientServiceId: entity.clientService?.id,
            addressId: entity.address?.id,
            groupID: entity.groupID,
            groupedPosition: entity.groupedPosition,
            eventIdentifier: entity.eventIdentifier,
            eventExternalIdentifier: entity.eventExternalIdentifier,
            calendarIdentifier: entity.calendarIdentifier,
            lastModifiedDate: entity.lastModifiedDate,
            lastSyncTag: entity.lastSyncTag,
            recurrenceRuleData: entity.recurrenceRuleData,
            attendeesCount: entity.attendeesCount,
            derivedFromEKEventID: entity.derivedFromEKEventID,
            googleColorId: entity.googleColorId,
            sessionLatitude: entity.sessionLatitude,
            sessionLongitude: entity.sessionLongitude,
            assignedServiceName: entity.clientService?.serviceName,
            assignedRate: entity.clientService?.rate,
            travelDistanceKM: travelCharge?.travelDistance ?? entity.travelDistanceKM,
            travelTimeMinutes: travelTimeMinutes,
            travelTollsAmount: travelCharge?.tollCost ?? entity.travelTollsAmount,
            travelCharges: entity.travelCharges.map { TravelChargeMapper().mapToDomain($0) }
        )
    }
    
    public func mapToEntity(_ domain: Session) -> SessionEntity {
        let entity = SessionEntity(id: domain.id)
        updateEntityProperties(entity, from: domain)
        return entity
    }
    
    public func updateEntity(_ entity: inout SessionEntity, from domain: Session) {
        updateEntityProperties(entity, from: domain)
    }
    
    // MARK: - Private Helpers
    
    private func updateEntityProperties(_ entity: SessionEntity, from domain: Session) {
        entity.title = domain.title
        entity.startTime = domain.startTime
        entity.endTime = domain.endTime
        entity.isAllDay = domain.isAllDay
        entity.location = domain.location
        entity.notes = domain.notes
        entity.status = domain.status.flatMap { SessionStatus(normalized: $0) }
        entity.isTravel = domain.isTravel
        entity.isDetached = domain.isDetached
        entity.occurrenceDate = domain.occurrenceDate
        entity.groupID = domain.groupID
        entity.groupedPosition = domain.groupedPosition
        entity.eventIdentifier = domain.eventIdentifier
        if let eventExternalIdentifier = domain.eventExternalIdentifier {
            entity.eventExternalIdentifier = eventExternalIdentifier
        }
        entity.calendarIdentifier = domain.calendarIdentifier
        entity.lastModifiedDate = domain.lastModifiedDate
        entity.lastSyncTag = domain.lastSyncTag
        entity.recurrenceRuleData = domain.recurrenceRuleData
        entity.attendeesCount = domain.attendeesCount
        entity.derivedFromEKEventID = domain.derivedFromEKEventID
        entity.googleColorId = domain.googleColorId
        entity.sessionLatitude = domain.sessionLatitude
        entity.sessionLongitude = domain.sessionLongitude
        entity.travelDistanceKM = domain.travelDistanceKM
        entity.travelTimeMinutes = domain.travelTimeMinutes
        entity.travelTollsAmount = domain.travelTollsAmount
        
        // Note: Client, ClientService, Address relationships are handled separately
        // as they require fetching/creating related entities via repositories
    }
}
