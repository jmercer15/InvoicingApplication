import Foundation
import MapKit
import CoreLocation

@MainActor
public enum MapKitAddressResolver {
    public static func reverseGeocode(
        location: CLLocation,
        preferredLocale: Locale? = nil
    ) async throws -> [MKMapItem] {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            throw NSError(
                domain: "MapKitAddressResolver",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create reverse geocoding request."]
            )
        }
        request.preferredLocale = preferredLocale
        return try await request.mapItems
    }

    public static func reverseGeocode(
        coordinate: CLLocationCoordinate2D,
        preferredLocale: Locale? = nil
    ) async throws -> [MKMapItem] {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return try await reverseGeocode(location: location, preferredLocale: preferredLocale)
    }

    public static func reverseGeocodeFirst(
        coordinate: CLLocationCoordinate2D,
        preferredLocale: Locale? = nil
    ) async throws -> MKMapItem? {
        try await reverseGeocode(coordinate: coordinate, preferredLocale: preferredLocale).first
    }

    public static func forwardSearch(query: String) async throws -> MKMapItem? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        let search = MKLocalSearch(request: request)
        return try await search.start().mapItems.first
    }

    public static func parseAddress(from mapItem: MKMapItem) -> EventKitLocationParser.ParsedLocation {
        let fullAddress = normalizeText(mapItem.address?.fullAddress)
        let shortAddress = normalizeText(mapItem.address?.shortAddress)

        let representations = mapItem.addressRepresentations
        let representedAddress = normalizeText(
            representations?.fullAddress(includingRegion: true, singleLine: true)
        )
        let cityName = normalizeText(representations?.cityName)
        let cityWithContext = normalizeText(representations?.cityWithContext(.automatic))
        let regionName = normalizeText(representations?.regionName)
        let regionCode = normalizeText(representations?.region?.identifier)

        let bestLocationText = firstNonEmpty(
            fullAddress,
            representedAddress,
            cityWithContext,
            cityName,
            normalizeText(mapItem.name)
        )

        let coordinate = mapItem.location.coordinate
        let parsed = EventKitLocationParser.parse(
            locationText: bestLocationText,
            coordinate: coordinate,
            structuredLocationText: shortAddress
        )

        let resolvedCity = firstNonEmpty(cityName, parsed.city) ?? ""
        let resolvedSuburb = firstNonEmpty(parsed.suburb, resolvedCity) ?? ""
        let resolvedCountry = firstNonEmpty(parsed.country, regionName, regionCode) ?? ""

        let resolvedFullAddress = firstNonEmpty(
            fullAddress,
            representedAddress,
            parsed.fullAddressText,
            cityWithContext,
            normalizeText(mapItem.name)
        ) ?? ""

        let resolvedPreferredLocation = firstNonEmpty(
            resolvedFullAddress,
            shortAddress,
            parsed.preferredLocation,
            cityWithContext
        )

        return EventKitLocationParser.ParsedLocation(
            preferredLocation: resolvedPreferredLocation,
            fullAddressText: resolvedFullAddress,
            unitNumber: parsed.unitNumber,
            streetNumber: parsed.streetNumber,
            streetName: parsed.streetName,
            suburb: resolvedSuburb,
            city: resolvedCity,
            state: parsed.state,
            postcode: parsed.postcode,
            country: resolvedCountry,
            poBox: parsed.poBox,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    public static func parseAddress(
        from coordinate: CLLocationCoordinate2D,
        preferredLocale: Locale? = nil
    ) async throws -> EventKitLocationParser.ParsedLocation? {
        guard let mapItem = try await reverseGeocodeFirst(
            coordinate: coordinate,
            preferredLocale: preferredLocale
        ) else {
            return nil
        }

        return parseAddress(from: mapItem)
    }

    private static func normalizeText(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let normalized = raw
            .replacingOccurrences(of: "\n", with: ", ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values.first(where: {
            guard let value = $0 else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) ?? nil
    }
}
