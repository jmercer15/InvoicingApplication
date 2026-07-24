import Foundation
@preconcurrency import EventKit
import CoreLocation
import Core

extension EventKitSyncService {

    // MARK: - Address Mapping

    func applyParsedAddressToSession(
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

    func resolvedCoordinate(forSnapshot snapshot: SessionSnapshot) -> CLLocationCoordinate2D? {
        guard snapshot.sessionLatitude != 0 || snapshot.sessionLongitude != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: snapshot.sessionLatitude, longitude: snapshot.sessionLongitude)
    }

    // MARK: - Text Helpers

    func normalizeLocationText(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let normalized = rawValue
            .replacingOccurrences(of: "\n", with: ", ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    func firstNonEmptyString(_ values: String?...) -> String? {
        values.first(where: {
            guard let value = $0 else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) ?? nil
    }

    // MARK: - Geocoding

    func reverseGeocodeCacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.6f,%.6f", coordinate.latitude, coordinate.longitude)
    }

    /// Parses the location from an `EKEvent`, enriching with reverse-geocoded data when needed.
    func parsedLocation(for remoteEvent: EKEvent) async -> EventKitLocationParser.ParsedLocation {
        let baseParsedLocation = EventKitLocationParser.parse(event: remoteEvent)
        guard baseParsedLocation.hasCoordinates else { return baseParsedLocation }

        let shouldReverseGeocode = !baseParsedLocation.hasGranularAddressData || baseParsedLocation.fullAddressText.isEmpty
        guard shouldReverseGeocode else { return baseParsedLocation }

        let coordinate = CLLocationCoordinate2D(
            latitude: baseParsedLocation.latitude,
            longitude: baseParsedLocation.longitude
        )
        let preferredLocationOverride = firstNonEmptyString(
            normalizeLocationText(remoteEvent.location),
            normalizeLocationText(remoteEvent.structuredLocation?.title)
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
            print("[EventKitSyncService] Reverse geocode failed for EKEvent \(remoteEvent.eventIdentifier ?? "<unknown>"): \(error.localizedDescription)")
            return baseParsedLocation
        }
    }

    func mergedParsedLocation(
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
}
