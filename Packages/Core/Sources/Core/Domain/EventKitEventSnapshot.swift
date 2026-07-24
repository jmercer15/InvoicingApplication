import Foundation

/// A thread-safe, Sendable snapshot representing the state of an EventKit event.
/// Used to pass event details across actor boundaries (e.g. from background fetcher to main actor).
public struct EventKitEventSnapshot: Sendable, Codable, Equatable, Identifiable {
    public var id: String {
        let baseIdentifier = eventIdentifier ?? UUID().uuidString
        let occurrenceAnchor = (occurrenceDate ?? startDate ?? Date()).timeIntervalSinceReferenceDate
        return "\(baseIdentifier)|\(occurrenceAnchor)"
    }

    public let eventIdentifier: String?
    public let calendarItemExternalIdentifier: String?
    public let title: String?
    public let startDate: Date?
    public let endDate: Date?
    public let isAllDay: Bool
    public let location: String?
    public let structuredLocationTitle: String?
    public let notes: String?
    public let occurrenceDate: Date?
    public let calendarIdentifier: String
    public let calendarSourceIdentifier: String?
    public let lastModifiedDate: Date?
    public let creationDate: Date?
    public let availabilityRawValue: Int
    public let statusRawValue: Int
    public let organizerName: String?
    public let organizerURLString: String?
    public let timeZoneIdentifier: String?
    public let urlString: String?
    public let attendeesCount: Int
    public let googleColorId: String?
    public let alarmsData: Data?
    public let recurrenceRuleData: Data?
    public let recurrenceRuleDescription: String?
    public let latitude: Double
    public let longitude: Double

    public init(
        eventIdentifier: String?,
        calendarItemExternalIdentifier: String?,
        title: String?,
        startDate: Date?,
        endDate: Date?,
        isAllDay: Bool,
        location: String?,
        structuredLocationTitle: String?,
        notes: String?,
        occurrenceDate: Date?,
        calendarIdentifier: String,
        calendarSourceIdentifier: String?,
        lastModifiedDate: Date?,
        creationDate: Date?,
        availabilityRawValue: Int,
        statusRawValue: Int,
        organizerName: String?,
        organizerURLString: String?,
        timeZoneIdentifier: String?,
        urlString: String?,
        attendeesCount: Int,
        googleColorId: String?,
        alarmsData: Data?,
        recurrenceRuleData: Data?,
        recurrenceRuleDescription: String?,
        latitude: Double,
        longitude: Double
    ) {
        self.eventIdentifier = eventIdentifier
        self.calendarItemExternalIdentifier = calendarItemExternalIdentifier
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.structuredLocationTitle = structuredLocationTitle
        self.notes = notes
        self.occurrenceDate = occurrenceDate
        self.calendarIdentifier = calendarIdentifier
        self.calendarSourceIdentifier = calendarSourceIdentifier
        self.lastModifiedDate = lastModifiedDate
        self.creationDate = creationDate
        self.availabilityRawValue = availabilityRawValue
        self.statusRawValue = statusRawValue
        self.organizerName = organizerName
        self.organizerURLString = organizerURLString
        self.timeZoneIdentifier = timeZoneIdentifier
        self.urlString = urlString
        self.attendeesCount = attendeesCount
        self.googleColorId = googleColorId
        self.alarmsData = alarmsData
        self.recurrenceRuleData = recurrenceRuleData
        self.recurrenceRuleDescription = recurrenceRuleDescription
        self.latitude = latitude
        self.longitude = longitude
    }
}
