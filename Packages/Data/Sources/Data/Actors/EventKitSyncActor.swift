import Core
import CoreLocation
import Foundation
import SwiftData

/// Background actor for managing EventKit sync database operations and geocoding.
public actor EventKitSyncActor: ModelActor {
    nonisolated public let modelContainer: ModelContainer
    nonisolated public let modelExecutor: any ModelExecutor

    private var reverseGeocodeCache: [String: EventKitLocationParser.ParsedLocation] = [:]

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    // MARK: - Synchronisation Pull Pipeline

    /// Background pull processing logic.
    public func handleExternalChanges(
        monitoredCalendarIdentifiers: [String],
        externalChangeSnapshot: [String: Date],
        maxEventFetchWindowYears: Int,
        syncEnabled: Bool,
        accessGranted: Bool
    ) async throws -> (updatedCount: Int, newSnapshot: [String: Date]) {
        guard accessGranted, syncEnabled else {
            return (0, externalChangeSnapshot)
        }

        let calendar = Calendar.current
        let start = calendar.date(byAdding: .year, value: -1, to: Date())!
        let end   = calendar.date(byAdding: .year, value:  1, to: Date())!

        let remoteEvents = await EventKitSyncService.fetchEventsOffMainThread(
            start: start,
            end: end,
            calendarIDs: monitoredCalendarIdentifiers,
            maxSegmentYears: maxEventFetchWindowYears
        )

        // --- Index remote events ---
        var remoteEventsById       = [String: EventKitEventSnapshot]()
        var remoteEventsByExternalId = [String: EventKitEventSnapshot]()
        var newSnapshot: [String: Date] = [:]

        for event in remoteEvents {
            if let id = event.eventIdentifier, remoteEventsById[id] == nil {
                remoteEventsById[id] = event
            }
            if let externalId = event.calendarItemExternalIdentifier,
               !externalId.isEmpty,
               remoteEventsByExternalId[externalId] == nil {
                remoteEventsByExternalId[externalId] = event
            }
            let lastModified = event.lastModifiedDate ?? event.startDate ?? Date.distantPast
            for key in EventKitSyncIdentityKeys.identityKeys(for: event) {
                let existing = newSnapshot[key]
                if existing == nil || (existing ?? .distantPast) < lastModified {
                    newSnapshot[key] = lastModified
                }
            }
        }

        let changedKeys = Set(newSnapshot.keys.filter { externalChangeSnapshot[$0] != newSnapshot[$0] })
        let deletedKeys = Set(externalChangeSnapshot.keys).subtracting(newSnapshot.keys)

        // --- Fetch local sessions ---
        let resolver = EntityResolutionService(context: modelContext)
        let localSessions = try resolver.resolveSessionsWithEventIdentifier(start: start, end: end)

        // --- 1. Update matched local sessions from changed remote events ---
        var updatedCount = 0
        for localSession in localSessions {
            let remoteEvent: EventKitEventSnapshot? = {
                if !localSession.eventIdentifier.isEmpty,
                   let match = remoteEventsById[localSession.eventIdentifier] { return match }
                if let ext = localSession.eventExternalIdentifier, !ext.isEmpty,
                   let match = remoteEventsByExternalId[ext] { return match }
                return nil
            }()

            guard let remoteEvent else { continue }

            let localKeys = Set(EventKitSyncIdentityKeys.identityKeys(for: localSession.snapshot()))
            let shouldProcess = !changedKeys.isDisjoint(with: localKeys) || !deletedKeys.isDisjoint(with: localKeys)
            guard shouldProcess else { continue }

            let localLastModified  = localSession.lastModifiedDate ?? Date.distantPast
            let remoteLastModified = remoteEvent.lastModifiedDate  ?? Date.distantPast
            let lastSyncTag        = decodeSyncTag(localSession.lastSyncTag) ?? Date.distantPast
            let localChanged       = localLastModified  > lastSyncTag
            let remoteChanged      = remoteLastModified > lastSyncTag

            if remoteChanged && (!localChanged || remoteLastModified > localLastModified) {
                _ = try await self.updateSessionFromRemote(
                    snapshot: localSession.snapshot(),
                    remoteEvent: remoteEvent
                )
                updatedCount += 1
            }
        }

        // --- 2. Track stale links for sessions with no remote match ---
        var missingRemoteCount = 0
        for localSession in localSessions {
            let hasRemoteMatch =
                (!localSession.eventIdentifier.isEmpty && remoteEventsById[localSession.eventIdentifier] != nil) ||
                ((localSession.eventExternalIdentifier?.isEmpty == false) &&
                 remoteEventsByExternalId[localSession.eventExternalIdentifier ?? ""] != nil)

            if !hasRemoteMatch {
                let outcome = EventKitSyncPolicy.staleMissOutcome(
                    currentMisses: Int(localSession.eventKitConsecutiveWindowMisses),
                    hasWindowMatch: false,
                    hasResolvedMatch: false
                )
                localSession.eventKitConsecutiveWindowMisses = Int32(outcome.nextMisses)
                localSession.isEventKitLinkStale = outcome.shouldMarkStale
                missingRemoteCount += 1
            } else if EventKitSyncPolicy.didReattach(hasWindowMatch: false, hasResolvedMatch: hasRemoteMatch) &&
                        (localSession.eventKitConsecutiveWindowMisses != 0 || localSession.isEventKitLinkStale) {
                let outcome = EventKitSyncPolicy.staleMissOutcome(
                    currentMisses: Int(localSession.eventKitConsecutiveWindowMisses),
                    hasWindowMatch: true,
                    hasResolvedMatch: true
                )
                localSession.eventKitConsecutiveWindowMisses = Int32(outcome.nextMisses)
                localSession.isEventKitLinkStale = outcome.shouldMarkStale
            }
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }

        return (updatedCount, newSnapshot)
    }

    // MARK: - Remote Event Update

    public func updateSessionFromRemote(
        snapshot: SessionSnapshot,
        remoteEvent: EventKitEventSnapshot
    ) async throws -> SessionSnapshot {
        let resolver = EntityResolutionService(context: modelContext)
        guard let sessionModel = try? resolver.resolveSession(id: snapshot.id) else { return snapshot }
        await applyRemoteEventSnapshotToSession(remoteEvent: remoteEvent, session: sessionModel, includeCoreFields: true)
        if modelContext.hasChanges {
            try modelContext.save()
        }
        return SessionSnapshot(sessionModel)
    }

    // MARK: - Mapping Logic

    private func applyRemoteEventSnapshotToSession(
        remoteEvent: EventKitEventSnapshot,
        session: Session,
        includeCoreFields: Bool
    ) async {
        let resolvedLocation = await parsedLocation(for: remoteEvent)

        if includeCoreFields {
            let trimmedTitle = remoteEvent.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            session.title = (trimmedTitle?.isEmpty == false) ? (trimmedTitle ?? "Untitled") : "Untitled"
            session.startTime = remoteEvent.startDate
            session.endTime = remoteEvent.endDate
            session.isAllDay = remoteEvent.isAllDay
            session.location = firstNonEmptyString(
                normalizeLocationText(remoteEvent.location),
                normalizeLocationText(remoteEvent.structuredLocationTitle),
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
        session.calendarIdentifier = remoteEvent.calendarIdentifier
        session.calendarSourceIdentifier = remoteEvent.calendarSourceIdentifier
        session.lastModifiedDate = remoteEvent.lastModifiedDate
        session.lastSyncTag = encodeSyncTag(remoteEvent.lastModifiedDate ?? Date())
        session.ekCreationDate = remoteEvent.creationDate
        session.ekEventAvailabilityRaw = Int16(remoteEvent.availabilityRawValue)
        session.ekEventStatusRaw = Int16(remoteEvent.statusRawValue)
        session.organizerName = remoteEvent.organizerName
        session.organizerURL = remoteEvent.organizerURLString
        session.timeZone = remoteEvent.timeZoneIdentifier
        session.url = remoteEvent.urlString
        session.attendeesCount = Int32(remoteEvent.attendeesCount)
        session.googleColorId = remoteEvent.googleColorId

        session.hasEKAlarms = remoteEvent.alarmsData != nil
        session.alarmsData = remoteEvent.alarmsData

        if let ruleData = remoteEvent.recurrenceRuleData {
            session.recurrenceRuleData = ruleData
            session.ekRecurrenceRuleDescription = remoteEvent.recurrenceRuleDescription
        } else {
            session.recurrenceRuleData = nil
            session.ekRecurrenceRuleDescription = nil
        }

        if resolvedLocation.hasCoordinates {
            session.sessionLatitude = resolvedLocation.latitude
            session.sessionLongitude = resolvedLocation.longitude
        } else if includeCoreFields {
            session.sessionLatitude = 0
            session.sessionLongitude = 0
        }

        if includeCoreFields {
            applyParsedAddressToSession(resolvedLocation, session: session)
        }
    }

    // MARK: - Address Geocoding & Parsing Helpers

    private func reverseGeocodeCacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.6f,%.6f", coordinate.latitude, coordinate.longitude)
    }

    private func parsedLocation(for remoteEvent: EventKitEventSnapshot) async -> EventKitLocationParser.ParsedLocation {
        let baseParsedLocation = EventKitLocationParser.parse(snapshot: remoteEvent)
        guard baseParsedLocation.hasCoordinates else { return baseParsedLocation }

        let shouldReverseGeocode = !baseParsedLocation.hasGranularAddressData || baseParsedLocation.fullAddressText.isEmpty
        guard shouldReverseGeocode else { return baseParsedLocation }

        let coordinate = CLLocationCoordinate2D(
            latitude: baseParsedLocation.latitude,
            longitude: baseParsedLocation.longitude
        )
        let preferredLocationOverride = firstNonEmptyString(
            normalizeLocationText(remoteEvent.location),
            normalizeLocationText(remoteEvent.structuredLocationTitle)
        )
        let cacheKey = reverseGeocodeCacheKey(for: coordinate)
        if let cached = reverseGeocodeCache[cacheKey] {
            return mergedParsedLocation(
                primary: baseParsedLocation,
                fallback: cached,
                preferredLocationOverride: preferredLocationOverride
            )
        }

        do {
            guard let reverseGeocoded = try await MapKitAddressResolver.parseAddress(from: coordinate) else {
                return baseParsedLocation
            }
            reverseGeocodeCache[cacheKey] = reverseGeocoded
            return mergedParsedLocation(
                primary: baseParsedLocation,
                fallback: reverseGeocoded,
                preferredLocationOverride: preferredLocationOverride
            )
        } catch {
            print("[EventKitSyncActor] Reverse geocode failed for snapshot \(remoteEvent.eventIdentifier ?? "<unknown>"): \(error.localizedDescription)")
            return baseParsedLocation
        }
    }

    private func mergedParsedLocation(
        primary: EventKitLocationParser.ParsedLocation,
        fallback: EventKitLocationParser.ParsedLocation,
        preferredLocationOverride: String?
    ) -> EventKitLocationParser.ParsedLocation {
        let shouldPreferFallbackAddress = !primary.hasGranularAddressData && !fallback.fullAddressText.isEmpty
        let resolvedPreferredLocation = firstNonEmptyString(
            preferredLocationOverride,
            primary.preferredLocation,
            fallback.preferredLocation
        )
        let resolvedFullAddress = shouldPreferFallbackAddress
            ? fallback.fullAddressText
            : (firstNonEmptyString(primary.fullAddressText, fallback.fullAddressText, resolvedPreferredLocation) ?? "")
        let resolvedSuburb    = firstNonEmptyString(primary.suburb, fallback.suburb, primary.city, fallback.city) ?? ""
        let resolvedCity      = firstNonEmptyString(primary.city, fallback.city, resolvedSuburb) ?? ""
        let resolvedLatitude  = primary.hasCoordinates ? primary.latitude  : fallback.latitude
        let resolvedLongitude = primary.hasCoordinates ? primary.longitude : fallback.longitude

        return EventKitLocationParser.ParsedLocation(
            preferredLocation: resolvedPreferredLocation,
            fullAddressText:   resolvedFullAddress,
            unitNumber:   firstNonEmptyString(primary.unitNumber,   fallback.unitNumber)   ?? "",
            streetNumber: firstNonEmptyString(primary.streetNumber, fallback.streetNumber) ?? "",
            streetName:   firstNonEmptyString(primary.streetName,   fallback.streetName)   ?? "",
            suburb:       resolvedSuburb,
            city:         resolvedCity,
            state:        firstNonEmptyString(primary.state,    fallback.state)    ?? "",
            postcode:     firstNonEmptyString(primary.postcode, fallback.postcode) ?? "",
            country:      firstNonEmptyString(primary.country,  fallback.country)  ?? "",
            poBox:        firstNonEmptyString(primary.poBox,    fallback.poBox)    ?? "",
            latitude:     resolvedLatitude,
            longitude:    resolvedLongitude
        )
    }

    private func applyParsedAddressToSession(
        _ parsedLocation: EventKitLocationParser.ParsedLocation,
        session: Session
    ) {
        guard parsedLocation.hasAnyAddressData else {
            session.address = nil
            return
        }

        let addressModel: Address
        if let existingAddress = session.address {
            addressModel = existingAddress
        } else {
            let createdAddress = Address()
            createdAddress.id = session.id
            if createdAddress.modelContext == nil {
                session.modelContext?.insert(createdAddress)
            }
            session.address = createdAddress
            addressModel = createdAddress
        }

        addressModel.id              = session.id
        addressModel.unitNumber      = parsedLocation.unitNumber
        addressModel.streetNumber    = parsedLocation.streetNumber
        addressModel.streetName      = parsedLocation.streetName
        addressModel.suburb          = parsedLocation.suburb
        addressModel.city            = parsedLocation.city
        addressModel.state           = parsedLocation.state
        addressModel.postcode        = parsedLocation.postcode
        addressModel.country         = parsedLocation.country
        addressModel.poBox           = parsedLocation.poBox
        addressModel.fullAddressText = parsedLocation.fullAddressText

        if parsedLocation.hasCoordinates {
            addressModel.latitude  = parsedLocation.latitude
            addressModel.longitude = parsedLocation.longitude
        } else {
            addressModel.latitude  = 0
            addressModel.longitude = 0
        }
    }

    private func normalizeLocationText(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let normalized = rawValue
            .replacingOccurrences(of: "\n", with: ", ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func firstNonEmptyString(_ values: String?...) -> String? {
        values.first(where: {
            guard let value = $0 else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) ?? nil
    }

    // MARK: - Date formatting for watermarks

    private let syncTagWriteFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let syncTagReadFormatters: [ISO8601DateFormatter] = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let internetDateTime = ISO8601DateFormatter()
        internetDateTime.formatOptions = [.withInternetDateTime]

        return [withFractional, internetDateTime]
    }()

    private let legacySyncTagFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()

    private func encodeSyncTag(_ date: Date?) -> String? {
        guard let date else { return nil }
        return self.syncTagWriteFormatter.string(from: date)
    }

    private func decodeSyncTag(_ rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.isEmpty else { return nil }

        for formatter in self.syncTagReadFormatters {
            if let parsed = formatter.date(from: rawValue) {
                return parsed
            }
        }

        return self.legacySyncTagFormatter.date(from: rawValue)
    }
}
