import Foundation
@preconcurrency import EventKit
import Core

extension EventKitSyncService {

    // MARK: - Calendar Selection Helper

    /// Returns the calendars that should be used for a monitored fetch,
    /// or `nil` when all calendars should be included.
    func monitoredCalendarsForFetch() -> [EKCalendar]? {
        let identifiers = monitoredCalendarIdentifiers
        guard !identifiers.isEmpty else { return nil }
        let calendars = identifiers.compactMap { eventStore.calendar(withIdentifier: $0) }
        return calendars.isEmpty ? nil : calendars
    }

    // MARK: - Off-Main-Thread Bulk Fetch

    nonisolated static func serializeAlarms(_ alarms: [EKAlarm]?) -> Data? {
        guard let alarms, !alarms.isEmpty else { return nil }
        struct SerializedAlarm: Codable {
            let relativeOffset: TimeInterval?
            let absoluteDate: Date?
            let proximityRaw: Int?
            let structuredTitle: String?
            let latitude: Double?
            let longitude: Double?
        }
        let payload = alarms.map { alarm in
            let coordinate = alarm.structuredLocation?.geoLocation?.coordinate
            return SerializedAlarm(
                relativeOffset: alarm.absoluteDate == nil ? alarm.relativeOffset : nil,
                absoluteDate:   alarm.absoluteDate,
                proximityRaw:   alarm.proximity.rawValue,
                structuredTitle: alarm.structuredLocation?.title,
                latitude:  coordinate?.latitude,
                longitude: coordinate?.longitude
            )
        }
        return try? JSONEncoder().encode(payload)
    }

    /// Large calendar reads must not block the main actor.
    /// `EKEventStore` is thread-confined; we spin up a dedicated background queue
    /// with its own store instance and resume via a checked continuation.
    /// Pass an empty `calendarIDs` array to query all calendars.
    nonisolated static func fetchEventsOffMainThread(
        start: Date,
        end: Date,
        calendarIDs: [String],
        maxSegmentYears: Int
    ) async -> [EventKitEventSnapshot] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let store = EKEventStore()
                let segments = EventKitSyncFetchPlanning.buildSegments(
                    start: start,
                    end: end,
                    maxWindowYears: maxSegmentYears,
                    calendar: Calendar.current
                )
                guard !segments.isEmpty else {
                    continuation.resume(returning: [])
                    return
                }

                let calendars: [EKCalendar]? = {
                    guard !calendarIDs.isEmpty else { return nil }
                    let cals = calendarIDs.compactMap { store.calendar(withIdentifier: $0) }
                    return cals.isEmpty ? nil : cals
                }()

                var allEvents: [EventKitEventSnapshot] = []
                allEvents.reserveCapacity(segments.count * 64)

                for segment in segments {
                    let predicate = store.predicateForEvents(
                        withStart: segment.start,
                        end: segment.end,
                        calendars: calendars
                    )
                    let ekEvents = store.events(matching: predicate)
                    let mapped = ekEvents.map { event in
                        let alarmsData = serializeAlarms(event.alarms)
                        let recurrenceRuleData = event.recurrenceRules?.first.flatMap { RecurrenceRuleManager.shared.serialize($0) }
                        let recurrenceRuleDescription = event.recurrenceRules?.map(\.description).joined(separator: "\n")
                        let coordinate = event.structuredLocation?.geoLocation?.coordinate
                        let googleColorId = GoogleCalendarColors.getGoogleEventColorId(event)
 
                        return EventKitEventSnapshot(
                            eventIdentifier: event.eventIdentifier,
                            calendarItemExternalIdentifier: event.calendarItemExternalIdentifier,
                            title: event.title,
                            startDate: event.startDate,
                            endDate: event.endDate,
                            isAllDay: event.isAllDay,
                            location: event.location,
                            structuredLocationTitle: event.structuredLocation?.title,
                            notes: event.notes,
                            occurrenceDate: event.occurrenceDate,
                            calendarIdentifier: event.calendar.calendarIdentifier,
                            calendarSourceIdentifier: event.calendar.source?.sourceIdentifier,
                            lastModifiedDate: event.lastModifiedDate,
                            creationDate: event.creationDate,
                            availabilityRawValue: event.availability.rawValue,
                            statusRawValue: event.status.rawValue,
                            organizerName: event.organizer?.name,
                            organizerURLString: event.organizer?.url.absoluteString,
                            timeZoneIdentifier: event.timeZone?.identifier,
                            urlString: event.url?.absoluteString,
                            attendeesCount: event.attendees?.count ?? 0,
                            googleColorId: googleColorId,
                            alarmsData: alarmsData,
                            recurrenceRuleData: recurrenceRuleData,
                            recurrenceRuleDescription: recurrenceRuleDescription,
                            latitude: coordinate?.latitude ?? 0,
                            longitude: coordinate?.longitude ?? 0
                        )
                    }
                    allEvents.append(contentsOf: mapped)
                }
 
                // Deduplicate and sort snapshots (similar to EventKitSyncFetchPlanning but for snapshots)
                let sorted = allEvents.sorted { lhs, rhs in
                    let lStart = lhs.startDate ?? Date.distantPast
                    let rStart = rhs.startDate ?? Date.distantPast
                    if lStart != rStart {
                        return lStart < rStart
                    }
                    return (lhs.eventIdentifier ?? "") < (rhs.eventIdentifier ?? "")
                }
 
                continuation.resume(returning: sorted)
            }
        }
    }
 
    // MARK: - Main-Actor Fetch (UI range)
 
    /// Fetches events using the main-actor `eventStore` for the UI display range.
    /// Suitable for small, view-bound date windows where `EKEvent` instances must
    /// remain alive on the main actor.
    public func fetchEvents(start: Date, end: Date) async -> [EKEvent] {
        guard canPerformReadWriteEventOperations() else { return [] }
        let calendars = monitoredCalendarsForFetch()
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = eventStore.events(matching: predicate)
        return EventKitSyncFetchPlanning.deduplicateAndSort(events: events)
    }
 
    // MARK: - Async Bulk Fetch (off-main-thread)
 
    /// Fetches events off the main thread for a given date range and optional calendar set.
    func fetchEventsAsync(start: Date, end: Date, calendars: [EKCalendar]?) async -> [EventKitEventSnapshot] {
        guard canPerformReadWriteEventOperations() else { return [] }
        let calendarIDs: [String] = {
            guard let calendars, !calendars.isEmpty else { return [] }
            return calendars.map(\.calendarIdentifier)
        }()
        return await Self.fetchEventsOffMainThread(
            start: start,
            end: end,
            calendarIDs: calendarIDs,
            maxSegmentYears: maxEventFetchWindowYears
        )
    }
}
 
extension EventKitEventSnapshot {
    public static func from(event: EKEvent) -> EventKitEventSnapshot {
        let alarmsData = EventKitSyncService.serializeAlarms(event.alarms)
        let recurrenceRuleData = event.recurrenceRules?.first.flatMap { RecurrenceRuleManager.shared.serialize($0) }
        let recurrenceRuleDescription = event.recurrenceRules?.map(\.description).joined(separator: "\n")
        let coordinate = event.structuredLocation?.geoLocation?.coordinate
        let googleColorId = GoogleCalendarColors.getGoogleEventColorId(event)
 
        return EventKitEventSnapshot(
            eventIdentifier: event.eventIdentifier,
            calendarItemExternalIdentifier: event.calendarItemExternalIdentifier,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            location: event.location,
            structuredLocationTitle: event.structuredLocation?.title,
            notes: event.notes,
            occurrenceDate: event.occurrenceDate,
            calendarIdentifier: event.calendar.calendarIdentifier,
            calendarSourceIdentifier: event.calendar.source?.sourceIdentifier,
            lastModifiedDate: event.lastModifiedDate,
            creationDate: event.creationDate,
            availabilityRawValue: event.availability.rawValue,
            statusRawValue: event.status.rawValue,
            organizerName: event.organizer?.name,
            organizerURLString: event.organizer?.url.absoluteString,
            timeZoneIdentifier: event.timeZone?.identifier,
            urlString: event.url?.absoluteString,
            attendeesCount: event.attendees?.count ?? 0,
            googleColorId: googleColorId,
            alarmsData: alarmsData,
            recurrenceRuleData: recurrenceRuleData,
            recurrenceRuleDescription: recurrenceRuleDescription,
            latitude: coordinate?.latitude ?? 0,
            longitude: coordinate?.longitude ?? 0
        )
    }
}
