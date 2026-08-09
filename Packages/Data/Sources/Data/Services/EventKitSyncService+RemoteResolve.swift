import Foundation
import EventKit
import Core

extension EventKitSyncService {
    private var remoteEventResolver: EventKitRemoteEventResolver {
        EventKitRemoteEventResolver(
            eventStore: eventStore,
            canPerformReadWriteEventOperations: { self.canPerformReadWriteEventOperations() },
            monitoredCalendarsForFetch: { self.monitoredCalendarsForFetch() },
            fetchEvents: { start, end, calendars in
                await self.fetchEventsAsync(start: start, end: end, calendars: calendars)
            }
        )
    }

    func findRemoteEvent(for snapshot: SessionSnapshot) async -> EKEvent? {
        await remoteEventResolver.findRemoteEvent(for: snapshot)
    }

    func resolvePersistedEventIdentity(
        savedEvent: EKEvent,
        snapshot: SessionSnapshot,
        span: EKSpan,
        previousIdentifier: String
    ) async -> EKEvent {
        await remoteEventResolver.resolvePersistedEventIdentity(
            savedEvent: savedEvent,
            snapshot: snapshot,
            span: span,
            previousIdentifier: previousIdentifier
        )
    }
}
