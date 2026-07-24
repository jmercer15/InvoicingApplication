// swiftlint:disable type_body_length function_body_length
import CoreLocation
import EventKit
import Foundation

/// Centralized parser for EventKit location payloads.
/// EventKit only gives raw text (`location`/`structuredLocation.title`) and optional coordinates,
/// so this parser performs best-effort extraction into granular address fields.
public enum EventKitLocationParser {
    public struct ParsedLocation: Sendable {
        public let preferredLocation: String?
        public let fullAddressText: String
        public let unitNumber: String
        public let streetNumber: String
        public let streetName: String
        public let suburb: String
        public let city: String
        public let state: String
        public let postcode: String
        public let country: String
        public let poBox: String
        public let latitude: Double
        public let longitude: Double

        public init(
            preferredLocation: String?,
            fullAddressText: String,
            unitNumber: String,
            streetNumber: String,
            streetName: String,
            suburb: String,
            city: String,
            state: String,
            postcode: String,
            country: String,
            poBox: String,
            latitude: Double,
            longitude: Double
        ) {
            self.preferredLocation = preferredLocation
            self.fullAddressText = fullAddressText
            self.unitNumber = unitNumber
            self.streetNumber = streetNumber
            self.streetName = streetName
            self.suburb = suburb
            self.city = city
            self.state = state
            self.postcode = postcode
            self.country = country
            self.poBox = poBox
            self.latitude = latitude
            self.longitude = longitude
        }

        public var hasCoordinates: Bool {
            latitude != 0 || longitude != 0
        }

        public var hasGranularAddressData: Bool {
            !unitNumber.isEmpty ||
                !streetNumber.isEmpty ||
                !streetName.isEmpty ||
                !suburb.isEmpty ||
                !city.isEmpty ||
                !state.isEmpty ||
                !postcode.isEmpty ||
                !country.isEmpty ||
                !poBox.isEmpty
        }

        public var hasAnyAddressData: Bool {
            hasGranularAddressData || hasCoordinates || !fullAddressText.isEmpty
        }
    }

    public static func parse(event: EKEvent) -> ParsedLocation {
        parse(
            locationText: event.location,
            coordinate: event.structuredLocation?.geoLocation?.coordinate,
            structuredLocationText: event.structuredLocation?.title
        )
    }

    public static func parse(snapshot: EventKitEventSnapshot) -> ParsedLocation {
        let coordinate = snapshot.latitude != 0 || snapshot.longitude != 0
            ? CLLocationCoordinate2D(latitude: snapshot.latitude, longitude: snapshot.longitude)
            : nil
        return parse(
            locationText: snapshot.location,
            coordinate: coordinate,
            structuredLocationText: snapshot.structuredLocationTitle
        )
    }

    public static func parse(
        locationText: String?,
        coordinate: CLLocationCoordinate2D? = nil,
        structuredLocationText: String? = nil
    ) -> ParsedLocation {
        let normalizedLocation = normalizeText(locationText)
        let normalizedStructuredTitle = normalizeText(structuredLocationText)

        var candidates = [String]()
        if let normalizedLocation, !normalizedLocation.isEmpty {
            candidates.append(normalizedLocation)
        }
        if let normalizedStructuredTitle,
           !normalizedStructuredTitle.isEmpty,
           !candidates.contains(normalizedStructuredTitle) {
            candidates.append(normalizedStructuredTitle)
        }

        let preferredLocation = candidates.first ?? {
            guard let coordinate else { return nil }
            return String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
        }()

        var merged = AddressComponents.empty
        var best = AddressComponents.empty
        var bestScore = -1

        for candidate in candidates {
            let parsed = parseAddressComponents(from: candidate)
            merged.fillMissing(from: parsed)

            let score = parsed.score(for: candidate)
            if score > bestScore {
                bestScore = score
                best = parsed
            }
        }

        var components = best
        components.fillMissing(from: merged)

        var latitude = coordinate?.latitude ?? 0
        var longitude = coordinate?.longitude ?? 0

        if latitude == 0 && longitude == 0,
           let fallbackText = preferredLocation,
           let parsedCoordinate = parseCoordinatePair(from: fallbackText) {
            latitude = parsedCoordinate.latitude
            longitude = parsedCoordinate.longitude
        }

        let fullAddressText = bestNonEmpty(
            components.rebuildAddressString(),
            preferredLocation,
            normalizedLocation,
            normalizedStructuredTitle
        ) ?? ""

        let locality = bestNonEmpty(components.city, components.suburb) ?? ""
        let resolvedSuburb = components.suburb.isEmpty ? locality : components.suburb
        let resolvedCity = components.city.isEmpty ? locality : components.city

        return ParsedLocation(
            preferredLocation: preferredLocation,
            fullAddressText: fullAddressText,
            unitNumber: components.unitNumber,
            streetNumber: components.streetNumber,
            streetName: components.streetName,
            suburb: resolvedSuburb,
            city: resolvedCity,
            state: components.state,
            postcode: components.postcode,
            country: components.country,
            poBox: components.poBox,
            latitude: latitude,
            longitude: longitude
        )
    }

    public static func preferredLocation(from event: EKEvent) -> String? {
        parse(event: event).preferredLocation
    }

    public static func preferredLocation(from snapshot: EventKitEventSnapshot) -> String? {
        parse(snapshot: snapshot).preferredLocation
    }

    struct AddressComponents {
        var unitNumber: String = ""
        var streetNumber: String = ""
        var streetName: String = ""
        var suburb: String = ""
        var city: String = ""
        var state: String = ""
        var postcode: String = ""
        var country: String = ""
        var poBox: String = ""

        static let empty = AddressComponents()

        var nonEmptyCount: Int {
            [unitNumber, streetNumber, streetName, suburb, city, state, postcode, country, poBox]
                .filter { !$0.isEmpty }
                .count
        }

        mutating func fillMissing(from other: AddressComponents) {
            if unitNumber.isEmpty { unitNumber = other.unitNumber }
            if streetNumber.isEmpty { streetNumber = other.streetNumber }
            if streetName.isEmpty { streetName = other.streetName }
            if suburb.isEmpty { suburb = other.suburb }
            if city.isEmpty { city = other.city }
            if state.isEmpty { state = other.state }
            if postcode.isEmpty { postcode = other.postcode }
            if country.isEmpty { country = other.country }
            if poBox.isEmpty { poBox = other.poBox }
        }

        func score(for sourceText: String) -> Int {
            var score = nonEmptyCount * 10
            if sourceText.contains(",") {
                score += 1
            }
            if sourceText.range(of: #"\d"#, options: .regularExpression) != nil {
                score += 1
            }
            return score
        }

        func rebuildAddressString() -> String? {
            var parts = [String]()

            if !poBox.isEmpty {
                parts.append("PO Box \(poBox)")
            } else {
                var streetLine = ""
                if !unitNumber.isEmpty, !streetNumber.isEmpty {
                    streetLine = "\(unitNumber)/\(streetNumber)"
                } else if !streetNumber.isEmpty {
                    streetLine = streetNumber
                }

                if !streetName.isEmpty {
                    streetLine = streetLine.isEmpty ? streetName : "\(streetLine) \(streetName)"
                }

                if !streetLine.isEmpty {
                    parts.append(streetLine)
                }
            }

            let locality = bestNonEmpty(city, suburb)
            if let locality, !locality.isEmpty {
                parts.append(locality)
            }
            if !state.isEmpty {
                parts.append(state)
            }
            if !postcode.isEmpty {
                parts.append(postcode)
            }
            if !country.isEmpty {
                parts.append(country)
            }

            let address = parts.joined(separator: ", ")
            return address.isEmpty ? nil : address
        }
    }
}
