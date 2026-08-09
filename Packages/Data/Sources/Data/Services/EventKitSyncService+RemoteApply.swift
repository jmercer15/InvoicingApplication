import Foundation
import EventKit
import SwiftData
import Core
import PersistenceModels

extension EventKitSyncService {
    func applyRemoteEventToSession(
        remoteEvent: EKEvent,
        session: Session,
        includeCoreFields: Bool
    ) async {
        await sessionWriter.applyRemoteEventToSession(
            remoteEvent: remoteEvent,
            session: session,
            includeCoreFields: includeCoreFields
        )
    }

    func mapSessionToEvent(
        _ snapshot: SessionSnapshot,
        event: EKEvent,
        preserveExistingMetadata: Bool = false
    ) {
        sessionWriter.mapSessionToEvent(snapshot, event: event, preserveExistingMetadata: preserveExistingMetadata)
    }
}
