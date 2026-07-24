import Foundation
@preconcurrency import EventKit
import Core

@MainActor
struct EventKitRemoteEventResolver {
    let eventStore: EKEventStore
    let canPerformReadWriteEventOperations: @MainActor () -> Bool
    let monitoredCalendarsForFetch: @MainActor () -> [EKCalendar]?
    let fetchEvents: @MainActor (Date, Date, [EKCalendar]?) async -> [EventKitEventSnapshot]

    func findRemoteEvent(for snapshot: SessionSnapshot) async -> EKEvent? {
        guard canPerformReadWriteEventOperations() else { return nil }

        if snapshot.isDetached, let occurrenceAnchor = snapshot.occurrenceDate {
            if let detached = await findDetachedOccurrence(for: snapshot, occurrenceAnchor: occurrenceAnchor) {
                return detached
            }
        }

        if !snapshot.eventIdentifier.isEmpty,
           let event = eventStore.event(withIdentifier: snapshot.eventIdentifier) {
            return event
        }

        guard let externalIdentifier = snapshot.eventExternalIdentifier,
              !externalIdentifier.isEmpty else {
            return nil
        }

        let baseStart = snapshot.startTime ?? Date()
        let baseEnd = snapshot.endTime ?? baseStart.addingTimeInterval(3600)
        let calendar = Calendar.current
        let searchStart = calendar.date(byAdding: .year, value: -2, to: baseStart) ?? baseStart
        let searchEnd = calendar.date(byAdding: .year, value: 2, to: baseEnd) ?? baseEnd

        let matchingEvents = await fetchEvents(searchStart, searchEnd, monitoredCalendarsForFetch())
        if let match = matchingEvents.first(where: { $0.calendarItemExternalIdentifier == externalIdentifier }),
           let eventId = match.eventIdentifier {
            return eventStore.event(withIdentifier: eventId)
        }
        return nil
    }

    func resolvePersistedEventIdentity(
        savedEvent: EKEvent,
        snapshot: SessionSnapshot,
        span: EKSpan,
        previousIdentifier: String
    ) async -> EKEvent {
        if let identifier = savedEvent.eventIdentifier,
           !identifier.isEmpty,
           let reloaded = eventStore.event(withIdentifier: identifier) {
            if span != .futureEvents || identifier != previousIdentifier {
                return reloaded
            }
        }

        guard span == .futureEvents else {
            return savedEvent
        }

        if let splitMaster = await refetchFutureSeriesMaster(
            for: snapshot,
            preferredCalendar: savedEvent.calendar,
            previousIdentifier: previousIdentifier
        ) {
            return splitMaster
        }

        if let identifier = savedEvent.eventIdentifier,
           !identifier.isEmpty,
           let reloaded = eventStore.event(withIdentifier: identifier) {
            return reloaded
        }

        return savedEvent
    }

    func refetchFutureSeriesMaster(
        for snapshot: SessionSnapshot,
        preferredCalendar: EKCalendar?,
        previousIdentifier: String
    ) async -> EKEvent? {
        guard let anchor = snapshot.startTime else { return nil }

        let calendar = Calendar.current
        let windowStart = calendar.date(byAdding: .day, value: -14, to: anchor) ?? anchor
        let windowEnd = calendar.date(byAdding: .day, value: 365, to: anchor) ?? anchor.addingTimeInterval(365 * 24 * 60 * 60)
        let calendars: [EKCalendar]? = preferredCalendar.map { [$0] } ?? monitoredCalendarsForFetch()
        let expectedTitle = snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedExternalIdentifier = snapshot.eventExternalIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedHasRecurrence = snapshot.recurrenceRuleData != nil

        let rawCandidates = await fetchEvents(windowStart, windowEnd, calendars)
        let candidates = rawCandidates.filter { candidate in
            guard let candidateStart = candidate.startDate else { return false }
            guard abs(candidateStart.timeIntervalSince(anchor)) <= 60 else { return false }

            if !expectedTitle.isEmpty {
                let candidateTitle = candidate.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard candidateTitle == expectedTitle else { return false }
            }

            if expectedHasRecurrence {
                guard candidate.recurrenceRuleData != nil else { return false }
            }

            return true
        }

        let bestMatch: EventKitEventSnapshot? = {
            if let expectedExternalIdentifier, !expectedExternalIdentifier.isEmpty {
                if let externalMatch = candidates.first(where: {
                    ($0.calendarItemExternalIdentifier ?? "") == expectedExternalIdentifier &&
                        ($0.eventIdentifier ?? "") != previousIdentifier
                }) {
                    return externalMatch
                }
            }

            if let rebasedIdentifierMatch = candidates.first(where: {
                let identifier = $0.eventIdentifier ?? ""
                return !identifier.isEmpty && identifier != previousIdentifier
            }) {
                return rebasedIdentifierMatch
            }

            return candidates.first
        }()

        if let bestMatch, let eventId = bestMatch.eventIdentifier {
            return eventStore.event(withIdentifier: eventId)
        }
        return nil
    }

    private func findDetachedOccurrence(
        for snapshot: SessionSnapshot,
        occurrenceAnchor: Date
    ) async -> EKEvent? {
        let calendar = Calendar.current
        let searchStart = calendar.date(byAdding: .day, value: -30, to: occurrenceAnchor) ?? occurrenceAnchor
        let searchEnd = calendar.date(byAdding: .day, value: 30, to: occurrenceAnchor) ?? occurrenceAnchor
        let candidateEvents = await fetchEvents(searchStart, searchEnd, monitoredCalendarsForFetch())

        let normalizedTarget = normalizedOccurrenceDate(
            occurrenceAnchor,
            calendar: calendar,
            isAllDay: snapshot.isAllDay
        )

        let bestMatch = candidateEvents.first { candidate in
            guard let candidateAnchor = candidate.occurrenceDate ?? candidate.startDate else {
                return false
            }

            let normalizedCandidate = normalizedOccurrenceDate(
                candidateAnchor,
                calendar: calendar,
                isAllDay: snapshot.isAllDay
            )

            guard normalizedCandidate == normalizedTarget else { return false }

            if let external = snapshot.eventExternalIdentifier, !external.isEmpty {
                return candidate.calendarItemExternalIdentifier == external
            }
            if !snapshot.eventIdentifier.isEmpty {
                return candidate.eventIdentifier == snapshot.eventIdentifier
            }
            return true
        }

        if let bestMatch, let eventId = bestMatch.eventIdentifier {
            return eventStore.event(withIdentifier: eventId)
        }
        return nil
    }

    private func normalizedOccurrenceDate(
        _ date: Date,
        calendar: Calendar,
        isAllDay: Bool
    ) -> Date {
        if isAllDay {
            return calendar.startOfDay(for: date)
        }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }
}
