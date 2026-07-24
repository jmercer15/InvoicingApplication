import EventKit
import Foundation
import Core

/// Stable identity keys for correlating local session snapshots with EventKit references.
enum EventKitSyncIdentityKeys {
    nonisolated static func identityStrings(
        eventIdentifier: String?,
        externalIdentifier: String?
    ) -> [String] {
        var keys: [String] = []
        if let identifier = eventIdentifier, !identifier.isEmpty {
            keys.append("event:\(identifier)")
        }
        if let externalIdentifier = externalIdentifier, !externalIdentifier.isEmpty {
            keys.append("external:\(externalIdentifier)")
        }
        return keys
    }

    nonisolated static func identityKeys(for event: EKEvent) -> [String] {
        identityStrings(
            eventIdentifier: event.eventIdentifier,
            externalIdentifier: event.calendarItemExternalIdentifier
        )
    }

    nonisolated static func identityKeys(for snapshot: SessionSnapshot) -> [String] {
        identityStrings(
            eventIdentifier: snapshot.eventIdentifier.isEmpty ? nil : snapshot.eventIdentifier,
            externalIdentifier: snapshot.eventExternalIdentifier
        )
    }

    nonisolated static func identityKeys(for snapshot: EventKitEventSnapshot) -> [String] {
        identityStrings(
            eventIdentifier: snapshot.eventIdentifier,
            externalIdentifier: snapshot.calendarItemExternalIdentifier
        )
    }
}
