import Foundation

public struct EventKitAliasCandidate: Equatable, Sendable {
    public let eventIdentifier: String?
    public let externalIdentifier: String?
    public let calendarIdentifier: String?
    public let sourceIdentifier: String?
    public let token: String?
    public let occurrenceDate: Date?
    public let startDate: Date?

    public init(
        eventIdentifier: String? = nil,
        externalIdentifier: String? = nil,
        calendarIdentifier: String? = nil,
        sourceIdentifier: String? = nil,
        token: String? = nil,
        occurrenceDate: Date? = nil,
        startDate: Date? = nil
    ) {
        self.eventIdentifier = eventIdentifier
        self.externalIdentifier = externalIdentifier
        self.calendarIdentifier = calendarIdentifier
        self.sourceIdentifier = sourceIdentifier
        self.token = token
        self.occurrenceDate = occurrenceDate
        self.startDate = startDate
    }
}

public struct EventKitAliasSet: Codable, Equatable, Sendable {
    public var eventIdentifiers: [String]
    public var externalIdentifiers: [String]
    public var calendarIdentifiers: [String]
    public var sourceIdentifiers: [String]
    public var occurrenceAnchors: [Date]
    public var token: String?

    public init(
        eventIdentifiers: [String] = [],
        externalIdentifiers: [String] = [],
        calendarIdentifiers: [String] = [],
        sourceIdentifiers: [String] = [],
        occurrenceAnchors: [Date] = [],
        token: String? = nil
    ) {
        self.eventIdentifiers = eventIdentifiers
        self.externalIdentifiers = externalIdentifiers
        self.calendarIdentifiers = calendarIdentifiers
        self.sourceIdentifiers = sourceIdentifiers
        self.occurrenceAnchors = occurrenceAnchors
        self.token = token
    }

    public static func decode(from data: Data?) -> EventKitAliasSet? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(EventKitAliasSet.self, from: data)
    }

    public func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }

    public mutating func merge(
        eventIdentifier: String?,
        externalIdentifier: String?,
        calendarIdentifier: String?,
        sourceIdentifier: String?,
        occurrenceDate: Date?,
        token: String?,
        isAllDay: Bool = false,
        calendar: Calendar = .current
    ) {
        if let eventIdentifier = Self.normalizedIdentifier(eventIdentifier) {
            appendUnique(value: eventIdentifier, to: &eventIdentifiers)
        }
        if let externalIdentifier = Self.normalizedIdentifier(externalIdentifier) {
            appendUnique(value: externalIdentifier, to: &externalIdentifiers)
        }
        if let calendarIdentifier = Self.normalizedIdentifier(calendarIdentifier) {
            appendUnique(value: calendarIdentifier, to: &calendarIdentifiers)
        }
        if let sourceIdentifier = Self.normalizedIdentifier(sourceIdentifier) {
            appendUnique(value: sourceIdentifier, to: &sourceIdentifiers)
        }
        if let occurrenceDate {
            appendUnique(
                value: Self.normalizedOccurrence(occurrenceDate, isAllDay: isAllDay, calendar: calendar),
                to: &occurrenceAnchors
            )
        }
        if let token = Self.normalizedIdentifier(token) {
            self.token = token
        }
    }

    public func containsOccurrenceAnchor(
        _ date: Date?,
        isAllDay: Bool,
        calendar: Calendar = .current
    ) -> Bool {
        guard let date else { return false }
        let normalized = Self.normalizedOccurrence(date, isAllDay: isAllDay, calendar: calendar)
        return occurrenceAnchors.contains(normalized)
    }

    public func disambiguationScore(
        for candidate: EventKitAliasCandidate,
        isAllDay: Bool,
        calendar: Calendar = .current
    ) -> Int {
        var score = 0

        if let eventIdentifier = Self.normalizedIdentifier(candidate.eventIdentifier),
           eventIdentifiers.contains(eventIdentifier) {
            score += 100
        }
        if let externalIdentifier = Self.normalizedIdentifier(candidate.externalIdentifier),
           externalIdentifiers.contains(externalIdentifier) {
            score += 60
        }
        if let calendarIdentifier = Self.normalizedIdentifier(candidate.calendarIdentifier),
           calendarIdentifiers.contains(calendarIdentifier) {
            score += 30
        }
        if let sourceIdentifier = Self.normalizedIdentifier(candidate.sourceIdentifier),
           sourceIdentifiers.contains(sourceIdentifier) {
            score += 20
        }
        if let token = Self.normalizedIdentifier(candidate.token),
           let aliasToken = Self.normalizedIdentifier(self.token),
           token == aliasToken {
            score += 80
        }

        if containsOccurrenceAnchor(candidate.occurrenceDate ?? candidate.startDate, isAllDay: isAllDay, calendar: calendar) {
            score += 50
        }

        return score
    }

    public func bestCandidateIndex(
        in candidates: [EventKitAliasCandidate],
        isAllDay: Bool,
        calendar: Calendar = .current
    ) -> Int? {
        var bestIndex: Int?
        var bestScore = Int.min

        for (index, candidate) in candidates.enumerated() {
            let score = disambiguationScore(for: candidate, isAllDay: isAllDay, calendar: calendar)
            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        guard bestScore > 0 else { return nil }
        return bestIndex
    }

    public func recurrenceOccurrenceKeys(
        isAllDay: Bool,
        calendar: Calendar = .current
    ) -> [String] {
        guard !externalIdentifiers.isEmpty,
              !calendarIdentifiers.isEmpty,
              !occurrenceAnchors.isEmpty else {
            return []
        }

        var keys: [String] = []
        var seen = Set<String>()
        keys.reserveCapacity(externalIdentifiers.count * calendarIdentifiers.count * occurrenceAnchors.count)

        for externalIdentifier in externalIdentifiers {
            for calendarIdentifier in calendarIdentifiers {
                for occurrenceAnchor in occurrenceAnchors {
                    guard let key = Self.recurrenceOccurrenceKey(
                        externalIdentifier: externalIdentifier,
                        calendarIdentifier: calendarIdentifier,
                        occurrenceDate: occurrenceAnchor,
                        isAllDay: isAllDay,
                        calendar: calendar
                    ) else {
                        continue
                    }
                    guard !seen.contains(key) else { continue }
                    seen.insert(key)
                    keys.append(key)
                }
            }
        }

        return keys
    }

    public static func recurrenceOccurrenceKey(
        externalIdentifier: String?,
        calendarIdentifier: String?,
        occurrenceDate: Date?,
        isAllDay: Bool,
        calendar: Calendar = .current
    ) -> String? {
        guard let externalIdentifier = normalizedIdentifier(externalIdentifier),
              let calendarIdentifier = normalizedIdentifier(calendarIdentifier),
              let occurrenceDate else {
            return nil
        }

        let normalizedDate = normalizedOccurrence(occurrenceDate, isAllDay: isAllDay, calendar: calendar)
        return "\(externalIdentifier)|\(calendarIdentifier)|\(normalizedDate.timeIntervalSinceReferenceDate)"
    }

    private static func normalizedOccurrence(_ date: Date, isAllDay: Bool, calendar: Calendar) -> Date {
        if isAllDay {
            return calendar.startOfDay(for: date)
        }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }

    private static func normalizedIdentifier(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func appendUnique<T: Equatable>(value: T, to values: inout [T]) {
        guard !values.contains(value) else { return }
        values.append(value)
    }
}
