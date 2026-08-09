import Core
import PersistenceModels
import CoreLocation
import EventKit
import Foundation
import SwiftData

/// Applies EventKit changes to SwiftData `Session` models and maps local snapshots back to `EKEvent`s.
@MainActor
struct EventKitSessionWriter {
    let recurrenceRuleManager: RecurrenceRuleManager
    let parsedLocation: @MainActor (EKEvent) async -> EventKitLocationParser.ParsedLocation
    let encodeSyncTag: (Date?) -> String?
    let serializeAlarms: ([EKAlarm]?) -> Data?
    let normalizeLocationText: (String?) -> String?
    let firstNonEmptyString: (String?, String?, String?) -> String?
    let applyParsedAddressToSession: (EventKitLocationParser.ParsedLocation, Session) -> Void
    let resolvedCoordinate: (SessionSnapshot) -> CLLocationCoordinate2D?

    func applyRemoteEventToSession(
        remoteEvent: EKEvent,
        session: Session,
        includeCoreFields: Bool
    ) async {
        let resolvedLocation = await parsedLocation(remoteEvent)

        if includeCoreFields {
            let trimmedTitle = remoteEvent.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            session.title = (trimmedTitle?.isEmpty == false) ? (trimmedTitle ?? "Untitled") : "Untitled"
            session.startTime = remoteEvent.startDate
            session.endTime = remoteEvent.endDate
            session.isAllDay = remoteEvent.isAllDay
            session.location = firstNonEmptyString(
                normalizeLocationText(remoteEvent.location),
                normalizeLocationText(remoteEvent.structuredLocation?.title),
                resolvedLocation.preferredLocation
            )
            session.notes = remoteEvent.notes
            session.occurrenceDate = remoteEvent.occurrenceDate
        }

        // Preserve temporal anchor identity for recurring instances/exceptions.
        if let occurrenceDate = remoteEvent.occurrenceDate {
            session.occurrenceDate = occurrenceDate
        } else if includeCoreFields {
            session.occurrenceDate = nil
        }

        session.eventIdentifier = remoteEvent.eventIdentifier ?? ""
        session.eventExternalIdentifier = remoteEvent.calendarItemExternalIdentifier
        session.calendarIdentifier = remoteEvent.calendar.calendarIdentifier
        session.calendarSourceIdentifier = remoteEvent.calendar.source?.sourceIdentifier
        if includeCoreFields {
            session.lastModifiedDate = remoteEvent.lastModifiedDate
        }
        session.lastSyncTag = encodeSyncTag(remoteEvent.lastModifiedDate ?? Date())
        session.ekCreationDate = remoteEvent.creationDate
        session.ekEventAvailabilityRaw = Int16(remoteEvent.availability.rawValue)
        session.ekEventStatusRaw = Int16(remoteEvent.status.rawValue)
        session.organizerName = remoteEvent.organizer?.name
        session.organizerURL = remoteEvent.organizer?.url.absoluteString
        session.timeZone = remoteEvent.timeZone?.identifier
        session.url = remoteEvent.url?.absoluteString
        session.attendeesCount = Int32(remoteEvent.attendees?.count ?? 0)
        session.googleColorId = GoogleCalendarColors.getGoogleEventColorId(remoteEvent)

        session.hasEKAlarms = !(remoteEvent.alarms?.isEmpty ?? true)
        session.alarmsData = serializeAlarms(remoteEvent.alarms)

        if includeCoreFields {
            if let rules = remoteEvent.recurrenceRules, let firstRule = rules.first {
                session.recurrenceRuleData = recurrenceRuleManager.serialize(firstRule)
                session.ekRecurrenceRuleDescription = rules.map(\.description).joined(separator: "\n")
            } else {
                session.recurrenceRuleData = nil
                session.ekRecurrenceRuleDescription = nil
            }
        }

        if includeCoreFields {
            if resolvedLocation.hasCoordinates {
                session.sessionLatitude = resolvedLocation.latitude
                session.sessionLongitude = resolvedLocation.longitude
            } else {
                session.sessionLatitude = 0
                session.sessionLongitude = 0
            }
            applyParsedAddressToSession(resolvedLocation, session)
        }
    }

    nonisolated static func mapSessionToEvent(
        _ snapshot: SessionSnapshot,
        event: EKEvent,
        preserveExistingMetadata: Bool,
        recurrenceRuleManager: RecurrenceRuleManager
    ) {
        event.title = snapshot.title
        event.startDate = snapshot.startTime
        event.endDate = snapshot.endTime
        event.isAllDay = snapshot.isAllDay
        event.location = snapshot.location

        // Only store the session's notes, not any app-specific or internal data
        event.notes = snapshot.notes

        if let timeZoneIdentifier = snapshot.timeZone,
           !timeZoneIdentifier.isEmpty,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            event.timeZone = timeZone
        } else if !preserveExistingMetadata {
            event.timeZone = nil
        }

        if let rawURL = snapshot.url?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawURL.isEmpty,
           let parsedURL = URL(string: rawURL) {
            event.url = parsedURL
        } else if !preserveExistingMetadata {
            event.url = nil
        }

        // Map recurrence
        if let ruleData = snapshot.recurrenceRuleData,
           let rule = recurrenceRuleManager.deserialize(ruleData) {
            event.recurrenceRules = [rule]
        } else {
            event.recurrenceRules = nil
        }

        if snapshot.sessionLatitude != 0 || snapshot.sessionLongitude != 0 {
            let coordinate = CLLocationCoordinate2D(latitude: snapshot.sessionLatitude, longitude: snapshot.sessionLongitude)
            let structuredTitle = snapshot.location ?? snapshot.title
            let structuredLocation = EKStructuredLocation(title: structuredTitle)
            structuredLocation.geoLocation = CLLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            event.structuredLocation = structuredLocation
            if event.location == nil {
                event.location = structuredTitle
            }
        } else if !preserveExistingMetadata {
            event.structuredLocation = nil
        }
    }

    func mapSessionToEvent(
        _ snapshot: SessionSnapshot,
        event: EKEvent,
        preserveExistingMetadata: Bool
    ) {
        Self.mapSessionToEvent(
            snapshot,
            event: event,
            preserveExistingMetadata: preserveExistingMetadata,
            recurrenceRuleManager: recurrenceRuleManager
        )
    }
}

