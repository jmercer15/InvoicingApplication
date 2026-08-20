import os
import Foundation
import SwiftData
import Core
import PersistenceModels

extension EventKitSyncService {

    // MARK: - Public Aliases

    /// Process external EventKit changes using the given context (alias).
    public func processExternalChanges(context: ModelContext) async {
        await handleExternalChangesWithContext(context)
    }

    /// Process external EventKit changes using the given context (alias).
    public func processExternalChanges(modelContext: ModelContext) async {
        await handleExternalChangesWithContext(modelContext)
    }

    // MARK: - Pull Pipeline

    /// Fetches the current remote event set, diffs against the stored snapshot,
    /// and applies any changes to matched local sessions.
    /// Does **not** auto-create new sessions for unmatched remote events.
    public func handleExternalChangesWithContext(_ modelContext: ModelContext) async {
        Logger.calendar.info("[SyncService] Processing external changes with background actor")
        guard accessGranted, syncEnabled else {
            Logger.calendar.info("[SyncService] Skipping external changes - access not granted or sync disabled")
            return
        }

        guard canPerformReadWriteEventOperations() else {
            Logger.calendar.info("[SyncService] Skipping external changes fetch — cannot read calendar")
            return
        }

        self.isSyncing = true
        self.syncStatus = .syncing
        defer {
            self.isSyncing = false
            if self.syncStatus == .syncing {
                self.syncStatus = .idle
            }
        }

        let actor = EventKitSyncActor(modelContainer: modelContext.container)
        do {
            let (updatedCount, newSnapshot) = try await actor.handleExternalChanges(
                monitoredCalendarIdentifiers: Array(monitoredCalendarIdentifiers),
                externalChangeSnapshot: externalChangeSnapshot,
                maxEventFetchWindowYears: maxEventFetchWindowYears,
                syncEnabled: syncEnabled,
                accessGranted: accessGranted
            )
            self.externalChangeSnapshot = newSnapshot
            Logger.calendar.info("[SyncService] Updated \(updatedCount) local sessions from remote events in the background.")
        } catch {
            Logger.calendar.warning("[SyncService] Error saving after pull: \(error.localizedDescription)")
            self.error = error
            self.syncStatus = .error
        }
    }
}
