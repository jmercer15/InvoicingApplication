import EventKit
import Foundation

/// Date-range segmentation and bulk-fetch dedupe for EventKit reads (pure helpers used by ``EventKitSyncService``).
enum EventKitSyncFetchPlanning {
    nonisolated static func normalizedDateRange(start: Date, end: Date) -> (Date, Date)? {
        if start == end { return nil }
        return start < end ? (start, end) : (end, start)
    }

    /// Segments wide ranges so EventKit queries stay within practical limits.
    nonisolated static func buildSegments(
        start: Date,
        end: Date,
        maxWindowYears: Int,
        calendar: Calendar
    ) -> [DateInterval] {
        guard let (normalizedStart, normalizedEnd) = normalizedDateRange(start: start, end: end) else {
            return []
        }

        var segments: [DateInterval] = []
        var cursor = normalizedStart

        while cursor < normalizedEnd {
            let nextBoundary = calendar.date(
                byAdding: .year,
                value: maxWindowYears,
                to: cursor
            ) ?? normalizedEnd
            let segmentEnd = min(nextBoundary, normalizedEnd)
            segments.append(DateInterval(start: cursor, end: segmentEnd))
            cursor = segmentEnd
        }

        return segments
    }

    /// Deduplicate overlapping window fetches; safe to run on a background thread with a dedicated `EKEventStore`.
    nonisolated static func deduplicateAndSort(events: [EKEvent]) -> [EKEvent] {
        var uniqueEvents: [String: EKEvent] = [:]
        uniqueEvents.reserveCapacity(events.count)

        for event in events {
            let baseKey = event.eventIdentifier
                ?? event.calendarItemExternalIdentifier
                ?? event.calendarItemIdentifier
            let startAnchor = event.startDate.timeIntervalSinceReferenceDate
            let endAnchor = event.endDate.timeIntervalSinceReferenceDate
            let occurrenceAnchor = (event.occurrenceDate ?? event.startDate).timeIntervalSinceReferenceDate
            let dedupeKey = "\(baseKey)|\(occurrenceAnchor)|\(startAnchor)|\(endAnchor)"
            uniqueEvents[dedupeKey] = event
        }

        return uniqueEvents.values.sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
            if lhs.endDate != rhs.endDate { return lhs.endDate < rhs.endDate }
            return (lhs.title ?? "") < (rhs.title ?? "")
        }
    }
}
