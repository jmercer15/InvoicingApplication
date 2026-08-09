@testable import Data
import Core
import Foundation
import Testing
import PersistenceModels
@Suite struct EventKitSyncRemoteImportTests {
    @Test func UnmatchedRemoteDoesNotAutoCreateLocalMaster() {
        let shouldImport = EventKitSyncPolicy.shouldImportRemoteEvent(
            skipAutoCreate: false,
            eventKey: "remote-1",
            matchedRemoteKeys: [],
            remoteIdentityKeys: ["event:event-1", "external:ext-1"],
            localIdentityKeys: ["event:event-2"]
        )

        #expect(!(shouldImport))
    }

    @Test func DetachedExceptionDoesNotAutoCreateDuringReconciliation() {
        let baseDate = Date(timeIntervalSinceReferenceDate: 200_000)
        let nextDate = baseDate.addingTimeInterval(86_400)

        let baseOccurrence = EventKitAliasSet.recurrenceOccurrenceKey(
            externalIdentifier: "ext-series",
            calendarIdentifier: "cal-primary",
            occurrenceDate: baseDate,
            isAllDay: false
        )!
        let detachedOccurrence = EventKitAliasSet.recurrenceOccurrenceKey(
            externalIdentifier: "ext-series",
            calendarIdentifier: "cal-primary",
            occurrenceDate: nextDate,
            isAllDay: false
        )!

        let localIdentityKeys: Set<String> = [
            "external:ext-series",
            "occurrence:\(baseOccurrence)"
        ]

        let unmatchedDetachedKeys: Set<String> = [
            "external:ext-series",
            "occurrence:\(detachedOccurrence)"
        ]
        let shouldImportDetached = EventKitSyncPolicy.shouldImportRemoteEvent(
            skipAutoCreate: false,
            eventKey: "remote-detached",
            matchedRemoteKeys: [],
            remoteIdentityKeys: unmatchedDetachedKeys,
            localIdentityKeys: localIdentityKeys
        )
        #expect(!(shouldImportDetached))

        let alreadyImportedDetachedKeys: Set<String> = [
            "external:ext-series",
            "occurrence:\(baseOccurrence)"
        ]
        let shouldImportDuplicateDetached = EventKitSyncPolicy.shouldImportRemoteEvent(
            skipAutoCreate: false,
            eventKey: "remote-duplicate",
            matchedRemoteKeys: [],
            remoteIdentityKeys: alreadyImportedDetachedKeys,
            localIdentityKeys: localIdentityKeys
        )
        #expect(!(shouldImportDuplicateDetached))
    }
}
