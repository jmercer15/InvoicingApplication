import Foundation
@preconcurrency import EventKit
import SwiftData
import Core

extension EventKitSyncService {

    // MARK: - Outbound Sync (App → Calendar)

    /// Synchronise a Session snapshot with EventKit, respecting sync direction and
    /// conflict-resolution policy.
    public func sync(snapshot: SessionSnapshot, modelContext: ModelContext, span: EKSpan = .thisEvent) {
        syncStatus = .syncing
        syncProgress = 0.0

        guard syncEnabled else {
            error = NSError(domain: "EventKitSyncService", code: 101,
                            userInfo: [NSLocalizedDescriptionKey: "Sync is disabled or session context is missing."])
            syncStatus = .error
            return
        }
        if syncDirection == .calendarToApp {
            error = NSError(domain: "EventKitSyncService", code: 102,
                            userInfo: [NSLocalizedDescriptionKey: "Sync direction is set to 'Calendar to App'. Local changes will not be pushed."])
            syncStatus = .error
            return
        }
        guard canPerformReadWriteEventOperations() else {
            error = NSError(domain: "EventKitSyncService", code: 110,
                            userInfo: [NSLocalizedDescriptionKey: "Full Calendar access is required for two-way calendar sync."])
            syncStatus = .error
            return
        }
        guard let calendar = selectedCalendar else {
            error = NSError(domain: "EventKitSyncService", code: 103,
                            userInfo: [NSLocalizedDescriptionKey: "No calendar selected. Please choose a writable calendar in Settings."])
            syncStatus = .error
            return
        }
        guard calendar.allowsContentModifications else {
            error = NSError(domain: "EventKitSyncService", code: 104,
                            userInfo: [NSLocalizedDescriptionKey: "The selected calendar is read-only. Please choose a different calendar."])
            syncStatus = .error
            return
        }

        Task { @MainActor [self] in
            let remoteEvent = await self.findRemoteEvent(for: snapshot)
            let localLastModified = snapshot.lastModifiedDate ?? Date.distantPast
            let remoteLastModified = remoteEvent?.lastModifiedDate ?? Date.distantPast
            let lastSyncTag = self.decodeSyncTag(snapshot.lastSyncTag) ?? Date.distantPast
            let localChanged = localLastModified > lastSyncTag
            let remoteChanged = remoteLastModified > lastSyncTag
            let reconcileDecision = EventKitSyncPolicy.reconcileDecision(
                syncDirection: self.syncDirection,
                conflictResolutionPolicy: self.conflictResolutionPolicy,
                localChanged: localChanged,
                remoteFreshness: remoteChanged ? .changed : .unchanged
            )
            let isRecurring = snapshot.recurrenceRuleData != nil || (remoteEvent?.recurrenceRules?.isEmpty == false)

            if self.syncDirection == .bidirectional {
                switch reconcileDecision {
                case .pull:
                    if let remote = remoteEvent {
                        _ = await self.updateSessionFromRemote(snapshot: snapshot, remoteEvent: remote, modelContext: modelContext)
                    }
                    return
                case .skip:
                    return
                case .prompt where localChanged && remoteChanged && isRecurring:
                    let localExceptions = await self.extractLocalExceptions(snapshot: snapshot, modelContext: modelContext)
                    let remoteExceptions = await self.extractRemoteExceptions(remoteEvent: remoteEvent)
                    let mergedExceptions = self.mergeExceptions(
                        masterSnapshot: snapshot,
                        local: localExceptions,
                        remote: remoteExceptions,
                        policy: self.conflictResolutionPolicy,
                        modelContext: modelContext
                    )
                    self.applyMergedExceptions(snapshot: snapshot, merged: mergedExceptions, modelContext: modelContext)
                    self.processNextInstanceConflict()
                    switch self.conflictResolutionPolicy {
                    case .preferApp, .localWins:
                        break
                    case .preferCalendar, .remoteWins:
                        if let remote = remoteEvent {
                            _ = await self.updateSessionFromRemote(snapshot: snapshot, remoteEvent: remote, modelContext: modelContext)
                        }
                        return
                    case .prompt:
                        break
                    }
                case .prompt where localChanged && remoteChanged && isRecurring && self.autoResolveRecurringConflicts:
                    switch self.conflictResolutionPolicy {
                    case .preferApp, .localWins:
                        break
                    case .preferCalendar, .remoteWins:
                        if let remote = remoteEvent {
                            _ = await self.updateSessionFromRemote(snapshot: snapshot, remoteEvent: remote, modelContext: modelContext)
                        }
                        return
                    case .prompt:
                        break
                    }
                case .prompt:
                    self.pendingConflict = ConflictPrompt(
                        sessionID: snapshot.id,
                        remoteEvent: remoteEvent,
                        isRecurring: isRecurring,
                        completion: { [weak self] choice, modelContext in
                            self?.resolveConflict(choice, modelContext: modelContext)
                        }
                    )
                    return
                case .push:
                    break
                }
            }

            var ekEvent: EKEvent
            let isExistingEvent: Bool
            if let event = remoteEvent {
                ekEvent = event
                isExistingEvent = true
                _ = ekEvent.refresh()
                if let remoteModDate = ekEvent.lastModifiedDate,
                   remoteModDate > lastSyncTag,
                   !localChanged {
                    let msg = "Conflict detected for '\(snapshot.title)'. Remote event is newer. Aborting push."
                    print("[SyncService] \(msg)")
                    self.error = NSError(domain: "EventKitSyncService", code: 105,
                                        userInfo: [NSLocalizedDescriptionKey: msg])
                    self.syncStatus = .error
                    return
                }
            } else {
                ekEvent = EKEvent(eventStore: self.eventStore)
                ekEvent.calendar = calendar
                isExistingEvent = false
            }

            let previousIdentifier = snapshot.eventIdentifier
            let calendarIdentifier = calendar.calendarIdentifier
            let isExisting = isExistingEvent
            let remoteEventId = remoteEvent?.eventIdentifier
            let eventTitle = snapshot.title
            let ruleManager = self.recurrenceRuleManager

            Task {
                do {
                    let savedId = try await Task.detached(priority: .userInitiated) {
                        let bgStore = EKEventStore()
                        guard let bgCalendar = bgStore.calendar(withIdentifier: calendarIdentifier) else {
                            throw NSError(domain: "EventKitSyncService", code: 107, userInfo: [NSLocalizedDescriptionKey: "Calendar not found in background store"])
                        }

                        let bgEvent: EKEvent
                        if let eventId = remoteEventId, let existing = bgStore.event(withIdentifier: eventId) {
                            bgEvent = existing
                            _ = bgEvent.refresh()
                        } else {
                            bgEvent = EKEvent(eventStore: bgStore)
                            bgEvent.calendar = bgCalendar
                        }

                        EventKitSessionWriter.mapSessionToEvent(
                            snapshot,
                            event: bgEvent,
                            preserveExistingMetadata: isExisting,
                            recurrenceRuleManager: ruleManager
                        )

                        try bgStore.save(bgEvent, span: span, commit: true)
                        return bgEvent.eventIdentifier ?? ""
                    }.value

                    let resolvedEvent = self.eventStore.event(withIdentifier: savedId) ?? ekEvent
                    let mainResolvedEvent = await self.resolvePersistedEventIdentity(
                        savedEvent: resolvedEvent,
                        snapshot: snapshot,
                        span: span,
                        previousIdentifier: previousIdentifier
                    )
                    let resolver = EntityResolutionService(context: modelContext)
                    if let sessionModel = try? resolver.resolveSession(id: snapshot.id) {
                        await self.applyRemoteEventToSession(
                            remoteEvent: mainResolvedEvent,
                            session: sessionModel,
                            includeCoreFields: false
                        )
                        if previousIdentifier != sessionModel.eventIdentifier {
                            print("[SyncService] Event identifier rebased after save span \(span): \(previousIdentifier) -> \(sessionModel.eventIdentifier)")
                        }
                    }
                    print("[SyncService] Successfully synced session: \(eventTitle)")
                    self.syncStatus = .idle
                    self.lastSyncDate = Date()
                    self.syncProgress = 1.0
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        if self.syncStatus == .idle { self.syncStatus = .idle }
                    }
                } catch {
                    let msg = "Failed to save event to calendar: \(error.localizedDescription)"
                    print("[SyncService] \(msg)")
                    self.error = NSError(domain: "EventKitSyncService", code: 106,
                                         userInfo: [NSLocalizedDescriptionKey: msg])
                    self.syncStatus = .error
                }
            }
        }
    }

    // MARK: - Delete

    public func delete(syncIdentifier: String, span: EKSpan = .thisEvent) {
        guard syncEnabled else {
            error = NSError(domain: "EventKitSyncService", code: 107,
                            userInfo: [NSLocalizedDescriptionKey: "Sync is disabled. Cannot delete event from calendar."])
            return
        }
        guard canPerformReadWriteEventOperations() else {
            error = NSError(domain: "EventKitSyncService", code: 110,
                            userInfo: [NSLocalizedDescriptionKey: "Full Calendar access is required for two-way calendar sync."])
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let bgStore = EKEventStore()
            guard let event = bgStore.event(withIdentifier: syncIdentifier) else {
                let msg = "Event not found in calendar. It may have already been deleted."
                Task { @MainActor in
                    self.error = NSError(domain: "EventKitSyncService", code: 108,
                                         userInfo: [NSLocalizedDescriptionKey: msg])
                }
                return
            }
            do {
                try bgStore.remove(event, span: span, commit: true)
                print("[SyncService] Successfully deleted event from calendar.")
                Task { @MainActor in
                    self.error = nil
                }
            } catch {
                let msg = "Error deleting event: \(error.localizedDescription)"
                print("[SyncService] \(msg)")
                Task { @MainActor in
                    self.error = NSError(domain: "EventKitSyncService", code: 109,
                                         userInfo: [NSLocalizedDescriptionKey: msg])
                }
            }
        }
    }
}
