import Foundation
import Core

extension Session {
    /// Convert from SessionEntity to domain model
    init(from entity: SessionEntity) {
        self.init(
            id: entity.id,
            title: entity.title,
            startTime: entity.startTime,
            endTime: entity.endTime,
            isAllDay: entity.isAllDay,
            location: entity.location,
            notes: entity.notes,
            status: entity.status?.rawValue,
            isTravel: entity.isTravel,
            clientId: entity.client?.id,
            clientServiceId: entity.clientService?.id,
            addressId: entity.address?.id,
            groupID: entity.groupID,
            groupedPosition: entity.groupedPosition,
            eventIdentifier: entity.eventIdentifier,
            calendarIdentifier: entity.calendarIdentifier,
            lastModifiedDate: entity.lastModifiedDate,
            lastSyncTag: entity.lastSyncTag,
            recurrenceRuleData: entity.recurrenceRuleData,
            attendeesCount: entity.attendeesCount,
            derivedFromEKEventID: entity.derivedFromEKEventID,
            googleColorId: entity.googleColorId,
            sessionLatitude: entity.sessionLatitude,
            sessionLongitude: entity.sessionLongitude
        )
    }
}

extension SessionEntity {
    /// Update entity from domain model
    func update(from session: Session) {
        self.title = session.title
        self.startTime = session.startTime
        self.endTime = session.endTime
        self.isAllDay = session.isAllDay
        self.location = session.location
        self.notes = session.notes
        self.status = session.status.flatMap { SessionStatus(rawValue: $0) }
        self.isTravel = session.isTravel
        self.groupID = session.groupID
        self.groupedPosition = session.groupedPosition
        self.eventIdentifier = session.eventIdentifier
        self.calendarIdentifier = session.calendarIdentifier
        self.lastModifiedDate = session.lastModifiedDate
        self.lastSyncTag = session.lastSyncTag
        self.recurrenceRuleData = session.recurrenceRuleData
        self.attendeesCount = session.attendeesCount
        self.derivedFromEKEventID = session.derivedFromEKEventID
        self.googleColorId = session.googleColorId
        self.sessionLatitude = session.sessionLatitude
        self.sessionLongitude = session.sessionLongitude
    }
}
