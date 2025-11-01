import Foundation

/// Domain model for a session
public struct Session: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let startTime: Date?
    public let endTime: Date?
    public let isAllDay: Bool
    public let location: String?
    public let notes: String?
    public let status: String?
    public let isTravel: Bool
    public let clientId: UUID?
    public let clientServiceId: UUID?
    public let addressId: UUID?
    public let groupID: UUID?
    public let groupedPosition: Int32
    
    // EventKit integration properties
    public let eventIdentifier: String
    public let calendarIdentifier: String?
    public let lastModifiedDate: Date?
    public let lastSyncTag: String?
    public let recurrenceRuleData: Data?
    
    // Additional session properties
    public let attendeesCount: Int32
    public let derivedFromEKEventID: String?
    public let googleColorId: String?
    public let sessionLatitude: Double
    public let sessionLongitude: Double
    
    public init(
        id: UUID,
        title: String,
        startTime: Date? = nil,
        endTime: Date? = nil,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        status: String? = nil,
        isTravel: Bool = false,
        clientId: UUID? = nil,
        clientServiceId: UUID? = nil,
        addressId: UUID? = nil,
        groupID: UUID? = nil,
        groupedPosition: Int32 = 0,
        eventIdentifier: String = "",
        calendarIdentifier: String? = nil,
        lastModifiedDate: Date? = nil,
        lastSyncTag: String? = nil,
        recurrenceRuleData: Data? = nil,
        attendeesCount: Int32 = 0,
        derivedFromEKEventID: String? = nil,
        googleColorId: String? = nil,
        sessionLatitude: Double = 0.0,
        sessionLongitude: Double = 0.0
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.status = status
        self.isTravel = isTravel
        self.clientId = clientId
        self.clientServiceId = clientServiceId
        self.addressId = addressId
        self.groupID = groupID
        self.groupedPosition = groupedPosition
        self.eventIdentifier = eventIdentifier
        self.calendarIdentifier = calendarIdentifier
        self.lastModifiedDate = lastModifiedDate
        self.lastSyncTag = lastSyncTag
        self.recurrenceRuleData = recurrenceRuleData
        self.attendeesCount = attendeesCount
        self.derivedFromEKEventID = derivedFromEKEventID
        self.googleColorId = googleColorId
        self.sessionLatitude = sessionLatitude
        self.sessionLongitude = sessionLongitude
    }
    
    /// Duration in hours
    public var durationHours: Double {
        guard let start = startTime, let end = endTime, end > start else { return 0 }
        return end.timeIntervalSince(start) / 3600.0
    }
    
    /// Check if session is in the past
    public var isPast: Bool {
        guard let end = endTime else { return false }
        return end < Date()
    }
    
    /// Check if session is today
    public var isToday: Bool {
        guard let start = startTime else { return false }
        return Calendar.current.isDateInToday(start)
    }
}
