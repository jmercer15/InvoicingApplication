import PersistenceModels
import Foundation
import SwiftData

/// Backfills durable EventKit sync metadata from legacy Session fields.
public enum BackfillEventKitSyncMetadata_v1 {
    public static let version = "1.0.0"

    public static func execute(modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<Session>()
        let sessions = try modelContext.fetch(descriptor)
        var rewrites = 0

        for session in sessions {
            var changed = false

            if session.eventKitAliasSetData == nil {
                var aliasSet = EventKitAliasSet()
                aliasSet.merge(
                    eventIdentifier: session.eventIdentifier,
                    externalIdentifier: session.eventExternalIdentifier,
                    calendarIdentifier: session.calendarIdentifier,
                    sourceIdentifier: session.calendarSourceIdentifier,
                    occurrenceDate: session.occurrenceDate,
                    token: session.eventKitSyncToken,
                    isAllDay: session.isAllDay
                )
                session.eventKitAliasSetData = aliasSet.encode()
                changed = true
            }

            if session.lastObservedRemoteModifiedDate == nil {
                session.lastObservedRemoteModifiedDate = session.lastModifiedDate
                changed = true
            }

            if session.isEventKitLinkStale {
                session.isEventKitLinkStale = false
                changed = true
            }

            if changed {
                rewrites += 1
            }
        }

        if rewrites > 0 {
            try modelContext.save()
        }
    }

    public static func rollback(modelContext _: ModelContext) throws {}
}
