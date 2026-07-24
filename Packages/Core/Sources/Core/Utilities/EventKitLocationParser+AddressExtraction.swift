// swiftlint:disable type_body_length function_body_length
import CoreLocation
import EventKit
import Foundation

extension EventKitLocationParser {
    static func parseAddressComponents(from rawText: String) -> AddressComponents {
        var components = AddressComponents.empty
        let normalized = normalizeInlineWhitespace(rawText)
        guard !normalized.isEmpty else { return components }

        // 1) PO Box detection
        if let poBox = firstCapturedGroup(
            in: normalized,
            pattern: #"(?i)\b(?:P(?:OST)?\.?\s*O(?:FFICE)?\.?\s*BOX|PO\s*BOX)\s*([A-Z0-9\-]+)\b"#
        ) {
            components.poBox = poBox
        }

        var working = normalized
        working = replacingMatches(
            in: working,
            pattern: #"(?i)\b(?:P(?:OST)?\.?\s*O(?:FFICE)?\.?\s*BOX|PO\s*BOX)\s*[A-Z0-9\-]+\b"#,
            with: ""
        )
        working = normalizeInlineWhitespace(working)

        // 2) Country
        if let country = extractCountry(from: working) {
            components.country = country
        }

        // 3) State + postcode
        if let (state, postcode) = extractStateAndPostcode(from: working) {
            components.state = state
            components.postcode = postcode
        } else {
            if let postcode = firstCapturedGroup(
                in: working,
                pattern: #"\b(\d{4,6}(?:-\d{4})?)\b"#
            ) {
                components.postcode = postcode
            }
            if let state = extractStandaloneState(from: working) {
                components.state = state
            }
        }

        // 4) Split by comma and inspect major segments
        let segments = working
            .split(separator: ",")
            .map { normalizeInlineWhitespace(String($0)) }
            .filter { !$0.isEmpty }

        let streetSegment = segments.first ?? working
        parseStreetSegment(streetSegment, into: &components)

        // 5) Locality extraction from trailing segments or state/postcode segment
        let localityFromSegments = extractLocality(from: segments, state: components.state, postcode: components.postcode, country: components.country)
        let fallbackLocality = localityFromSegments ?? extractLocalityFromInlineText(
            working,
            streetSegment: streetSegment,
            state: components.state,
            postcode: components.postcode,
            country: components.country
        )

        if let fallbackLocality, !fallbackLocality.isEmpty {
            components.city = fallbackLocality
            components.suburb = fallbackLocality
        }

        return components
    }

    static func parseStreetSegment(_ segment: String, into components: inout AddressComponents) {
        let trimmed = normalizeInlineWhitespace(segment)
        guard !trimmed.isEmpty else { return }

        // Pattern: "Unit 2/123 Main St" or "Apt 5 123 Main St"
        if let match = capturedGroups(
            in: trimmed,
            pattern: #"(?i)^(?:unit|apt|apartment|suite|ste|level|lot|shop|room|rm|floor|fl)\s*#?\s*([A-Z0-9\-]+)\s*(?:/|\s+)?(\d+[A-Z]?(?:-\d+[A-Z]?)?)?\s*(.*)$"#
        ) {
            components.unitNumber = match[safe: 0] ?? ""
            let parsedStreetNumber = (match[safe: 1] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !parsedStreetNumber.isEmpty {
                components.streetNumber = parsedStreetNumber
            }

            let parsedStreetName = cleanStreetName(match[safe: 2] ?? "")
            if !parsedStreetName.isEmpty {
                components.streetName = parsedStreetName
            }
            return
        }

        // Pattern: "2/123 Main St"
        if let match = capturedGroups(
            in: trimmed,
            pattern: #"^([A-Z0-9\-]+)\s*/\s*(\d+[A-Z]?(?:-\d+[A-Z]?)?)\s+(.+)$"#
        ) {
            components.unitNumber = match[safe: 0] ?? ""
            components.streetNumber = match[safe: 1] ?? ""
            components.streetName = cleanStreetName(match[safe: 2] ?? "")
            return
        }

        // Pattern: "123 Main St"
        if let match = capturedGroups(
            in: trimmed,
            pattern: #"^(\d+[A-Z]?(?:-\d+[A-Z]?)?)\s+(.+)$"#
        ) {
            components.streetNumber = match[safe: 0] ?? ""
            components.streetName = cleanStreetName(match[safe: 1] ?? "")
            return
        }

        // If the segment looks street-like without a number, keep it as street name.
        if likelyStreetName(trimmed) {
            components.streetName = cleanStreetName(trimmed)
        }
    }

    static func extractCountry(from text: String) -> String? {
        let lowercased = text.lowercased()
        for country in knownCountries {
            if lowercased.contains(country.lowercased()) {
                return country
            }
        }

        let segments = text
            .split(separator: ",")
            .map { normalizeInlineWhitespace(String($0)) }
            .filter { !$0.isEmpty }

        if let last = segments.last,
           last.range(of: #"^[A-Za-z\s]{3,}$"#, options: .regularExpression) != nil,
           extractStandaloneState(from: last) == nil,
           firstCapturedGroup(in: last, pattern: #"\b\d{4,6}(?:-\d{4})?\b"#) == nil {
            return last
        }

        return nil
    }

    static func extractStateAndPostcode(from text: String) -> (String, String)? {
        if let match = capturedGroups(
            in: text,
            pattern: #"\b(ACT|NSW|NT|QLD|SA|TAS|VIC|WA)\s*(\d{4})\b"#,
            options: [.caseInsensitive]
        ) {
            return ((match[safe: 0] ?? "").uppercased(), match[safe: 1] ?? "")
        }

        if let match = capturedGroups(
            in: text,
            // swiftlint:disable:next line_length
            pattern: #"\b(AL|AK|AZ|AR|CA|CO|CT|DE|FL|GA|HI|ID|IL|IN|IA|KS|KY|LA|ME|MD|MA|MI|MN|MS|MO|MT|NE|NV|NH|NJ|NM|NY|NC|ND|OH|OK|OR|PA|RI|SC|SD|TN|TX|UT|VT|VA|WA|WV|WI|WY|DC)\s+(\d{5}(?:-\d{4})?)\b"#,
            options: [.caseInsensitive]
        ) {
            return ((match[safe: 0] ?? "").uppercased(), match[safe: 1] ?? "")
        }

        return nil
    }

    static func extractStandaloneState(from text: String) -> String? {
        let normalized = " \(text.uppercased()) "

        for state in australianStateCodes where normalized.contains(" \(state) ") {
            return state
        }

        for state in usStateCodes where normalized.contains(" \(state) ") {
            return state
        }

        return nil
    }

    static func extractLocality(from segments: [String], state: String, postcode: String, country: String) -> String? {
        guard !segments.isEmpty else { return nil }

        let cleanedSegments = segments
            .map {
                cleanLocalitySegment($0, state: state, postcode: postcode, country: country)
            }
            .filter { !$0.isEmpty }

        if cleanedSegments.count >= 2 {
            // The first cleaned segment is usually street, the next is locality.
            return cleanedSegments[1]
        }

        if cleanedSegments.count == 1 {
            let first = cleanedSegments[0]
            if first != cleanLocalitySegment(segments[0], state: state, postcode: postcode, country: country) {
                return first
            }
        }

        return nil
    }

    static func extractLocalityFromInlineText(
        _ text: String,
        streetSegment: String,
        state: String,
        postcode: String,
        country: String
    ) -> String? {
        var candidate = text
        candidate = candidate.replacingOccurrences(of: streetSegment, with: "")
        candidate = cleanLocalitySegment(candidate, state: state, postcode: postcode, country: country)

        if candidate.isEmpty {
            return nil
        }

        // Keep only the first plausible locality token block.
        if let firstToken = candidate
            .split(separator: ",")
            .map({ normalizeInlineWhitespace(String($0)) })
            .first(where: { !$0.isEmpty }) {
            return firstToken
        }

        return candidate
    }

    static func cleanLocalitySegment(_ segment: String, state: String, postcode: String, country: String) -> String {
        var cleaned = segment

        if !state.isEmpty {
            let statePattern = "\\b\(NSRegularExpression.escapedPattern(for: state))\\b"
            cleaned = replacingMatches(in: cleaned, pattern: statePattern, options: [.caseInsensitive])
        }
        if !postcode.isEmpty {
            let postcodePattern = "\\b\(NSRegularExpression.escapedPattern(for: postcode))\\b"
            cleaned = replacingMatches(in: cleaned, pattern: postcodePattern)
        }
        if !country.isEmpty {
            let countryPattern = "\\b\(NSRegularExpression.escapedPattern(for: country))\\b"
            cleaned = replacingMatches(in: cleaned, pattern: countryPattern, options: [.caseInsensitive])
        }

        cleaned = replacingMatches(in: cleaned, pattern: #"\b\d{4,6}(?:-\d{4})?\b"#)
        cleaned = replacingMatches(in: cleaned, pattern: #"\b(ACT|NSW|NT|QLD|SA|TAS|VIC|WA)\b"#, options: [.caseInsensitive])
        cleaned = replacingMatches(
            in: cleaned,
            pattern: #"\b(AL|AK|AZ|AR|CA|CO|CT|DE|FL|GA|HI|ID|IL|IN|IA|KS|KY|LA|ME|MD|MA|MI|MN|MS|MO|MT|NE|NV|NH|NJ|NM|NY|NC|ND|OH|OK|OR|PA|RI|SC|SD|TN|TX|UT|VT|VA|WA|WV|WI|WY|DC)\b"#,
            options: [.caseInsensitive]
        )

        cleaned = cleaned
            .replacingOccurrences(of: ",", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalizeInlineWhitespace(cleaned)
    }

    static func parseCoordinatePair(from text: String) -> CLLocationCoordinate2D? {
        guard let match = capturedGroups(
            in: text,
            pattern: #"(-?\d{1,2}(?:\.\d+)?)[,\s]+(-?\d{1,3}(?:\.\d+)?)"#
        ) else {
            return nil
        }

        guard let latitude = Double(match[safe: 0] ?? ""),
              let longitude = Double(match[safe: 1] ?? ""),
              abs(latitude) <= 90,
              abs(longitude) <= 180
        else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func likelyStreetName(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        return streetKeywords.contains { lowercased.contains($0) }
    }

    static func cleanStreetName(_ raw: String) -> String {
        normalizeInlineWhitespace(raw)
            .trimmingCharacters(in: CharacterSet(charactersIn: ","))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizeText(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let normalized = normalizeInlineWhitespace(
            raw
                .replacingOccurrences(of: "\n", with: ", ")
                .replacingOccurrences(of: "\t", with: " ")
        )
        return normalized.isEmpty ? nil : normalized
    }

    static func normalizeInlineWhitespace(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func bestNonEmpty(_ values: String?...) -> String? {
        // swiftlint:disable:next redundant_nil_coalescing - flattens String?? to String? for [String?]
        values.first(where: {
            guard let value = $0 else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) ?? nil
    }

    static func firstCapturedGroup(
        in text: String,
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> String? {
        capturedGroups(in: text, pattern: pattern, options: options)?[safe: 0]
    }

    static func capturedGroups(
        in text: String,
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }

        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }

        var groups = [String]()
        for index in 1 ..< match.numberOfRanges {
            let groupRange = match.range(at: index)
            guard groupRange.location != NSNotFound,
                  let swiftRange = Range(groupRange, in: text)
            else {
                groups.append("")
                continue
            }
            groups.append(String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return groups
    }

    static func replacingMatches(
        in text: String,
        pattern: String,
        with replacement: String = "",
        options: NSRegularExpression.Options = []
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return text
        }

        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }

    static let knownCountries: [String] = [
        "Australia",
        "New Zealand",
        "United States",
        "United States of America",
        "USA",
        "United Kingdom",
        "UK",
        "Canada",
        "Ireland"
    ]

    static let australianStateCodes: Set<String> = [
        "ACT", "NSW", "NT", "QLD", "SA", "TAS", "VIC", "WA"
    ]

    static let usStateCodes: Set<String> = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY",
        "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND",
        "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC"
    ]

    static let streetKeywords: [String] = [
        " street", " st", " avenue", " ave", " road", " rd", " drive", " dr", " lane", " ln", " boulevard", " blvd", " court", " ct", " place", " pl", " terrace", " tce", " highway", " hwy", " way"
    ]
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
