import Foundation
@preconcurrency import EventKit
import SwiftData
import Core

extension EventKitSyncService {
    // --- Recurring Instance Merge Utilities ---
    func extractLocalExceptions(snapshot: SessionSnapshot, modelContext: ModelContext) async -> [Date: String] {
        return await MainActor.run {
            let masterID = snapshot.id.uuidString
            let descriptor = FetchDescriptor<Session>(predicate: #Predicate<Session> {
                $0.isDetached == true && $0.derivedFromEKEventID == masterID
            })
            let detached = (try? modelContext.fetch(descriptor)) ?? []
            var result: [Date: String] = [:]
            for instance in detached {
                if let date = instance.occurrenceDate {
                    result[date] = instance.id.uuidString
                }
            }
            return result
        }
    }

    func extractRemoteExceptions(remoteEvent: EKEvent?) async -> [Date: EKEvent] {
        guard let event = remoteEvent else { return [:] }
        var result: [Date: EKEvent] = [:]
        if let recurrenceRules = event.recurrenceRules, !recurrenceRules.isEmpty {
            let calendar = Calendar.current
            let start = calendar.date(byAdding: .year, value: -1, to: Date())!
            let end = calendar.date(byAdding: .year, value: 1, to: Date())!
            let events = await fetchEventsAsync(start: start, end: end, calendars: [event.calendar])
            for occ in events {
                let belongsToSeries = (
                    (occ.calendarItemExternalIdentifier ?? "") == (event.calendarItemExternalIdentifier ?? "")
                ) || (
                    (occ.eventIdentifier ?? "") == (event.eventIdentifier ?? "")
                )
                guard belongsToSeries else { continue }

                guard let eventId = occ.eventIdentifier,
                      let liveEvent = eventStore.event(withIdentifier: eventId) else {
                    continue
                }

                if let occurrenceDate = occ.occurrenceDate {
                    result[occurrenceDate] = liveEvent
                    continue
                }

                if (occ.eventIdentifier ?? "") != (event.eventIdentifier ?? "") {
                    if let startDate = occ.startDate {
                        result[startDate] = liveEvent
                    }
                }
            }
        }
        return result
    }

    func processNextInstanceConflict() {
        guard pendingConflict == nil, !pendingInstanceConflicts.isEmpty else { return }
        guard let modelContext = instanceConflictResolutionContext else { return }
        let (date, masterSessionIDStr, remoteEvent, localDetachedID, remote) = pendingInstanceConflicts.removeFirst()
        if pendingInstanceConflicts.isEmpty {
            instanceConflictResolutionContext = nil
        }

        let resolver = EntityResolutionService(context: modelContext)
        guard let masterUUID = UUID(uuidString: masterSessionIDStr),
              let masterSession = try? resolver.resolveSession(id: masterUUID) else { return }

        let captureDate = date
        let captureRemote = remote
        pendingConflict = ConflictPrompt(
            sessionID: masterSession.id,
            remoteEvent: remoteEvent,
            isRecurring: true,
            completion: { [weak self] choice, ctx in
                guard let self else { return }
                let res = EntityResolutionService(context: ctx)
                guard let master = try? res.resolveSession(id: masterUUID) else { return }
                var localRef: Session?
                if let localIDStr = localDetachedID, let localUUID = UUID(uuidString: localIDStr) {
                    localRef = try? res.resolveSession(id: localUUID)
                }
                self.applyInstanceMergeChoice(
                    snapshot: master.snapshot(),
                    date: captureDate,
                    choice: choice,
                    local: localRef,
                    remote: captureRemote,
                    modelContext: ctx
                )
                self.processNextInstanceConflict()
            }
        )
    }

    func mergeExceptions(
        masterSnapshot: SessionSnapshot,
        local: [Date: String],
        remote: [Date: EKEvent],
        policy: CalendarPreferences.ConflictResolutionPolicy,
        modelContext: ModelContext
    ) -> [Date: (Session?, EKEvent?)] {
        var merged: [Date: (Session?, EKEvent?)] = [:]
        let allDates = EventKitSyncPolicy.orderedOccurrenceDates(Array(Set(local.keys).union(remote.keys)))
        for date in allDates {
            let localSessionID = local[date]
            let remoteInstance = remote[date]

            var localSession: Session?
            if let sessionID = localSessionID, let sessionUUID = UUID(uuidString: sessionID) {
                let sessionDescriptor = FetchDescriptor<Session>(predicate: #Predicate<Session> { $0.id == sessionUUID })
                localSession = try? modelContext.fetch(sessionDescriptor).first
            }

            if localSession != nil && remoteInstance == nil {
                merged[date] = (localSession, nil)
            } else if localSession == nil && remoteInstance != nil {
                merged[date] = (nil, remoteInstance)
            } else if let l = localSession, let r = remoteInstance {
                switch policy {
                case .preferApp, .localWins:
                    merged[date] = (l, nil)
                case .preferCalendar, .remoteWins:
                    merged[date] = (nil, r)
                case .prompt:
                    if instanceConflictResolutionContext == nil {
                        instanceConflictResolutionContext = modelContext
                    }
                    pendingInstanceConflicts.append((date, masterSnapshot.id.uuidString, r, l.id.uuidString, r))
                }
            }
        }
        return merged
    }

    func applyMergedExceptions(
        snapshot: SessionSnapshot,
        merged: [Date: (Session?, EKEvent?)],
        modelContext: ModelContext
    ) {
        Task { @MainActor in
            for (date, (localInstance, remoteInstance)) in merged {
                if localInstance != nil && remoteInstance != nil && conflictResolutionPolicy == .prompt {
                    continue
                }
                if let local = localInstance, remoteInstance == nil {
                    let localSnapshot = SessionSnapshot(local)
                    let remoteEvent = await self.findRemoteEvent(for: localSnapshot)
                    let calendarIdentifier = self.selectedCalendar?.calendarIdentifier
                    let isExisting = remoteEvent != nil
                    let remoteEventId = remoteEvent?.eventIdentifier
                    let eventTitle = local.title
                    let ekEventFallback = EKEvent(eventStore: self.eventStore)
                    if !isExisting {
                        ekEventFallback.calendar = self.selectedCalendar
                    }
                    let ruleManager = self.recurrenceRuleManager

                    Task {
                        do {
                            let savedId = try await Task.detached(priority: .userInitiated) {
                                let bgStore = EKEventStore()
                                let bgCalendar = calendarIdentifier.flatMap { bgStore.calendar(withIdentifier: $0) }

                                let bgEvent: EKEvent
                                if let eventId = remoteEventId, let existing = bgStore.event(withIdentifier: eventId) {
                                    bgEvent = existing
                                    _ = bgEvent.refresh()
                                } else {
                                    bgEvent = EKEvent(eventStore: bgStore)
                                    bgEvent.calendar = bgCalendar
                                }

                                EventKitSessionWriter.mapSessionToEvent(
                                    localSnapshot,
                                    event: bgEvent,
                                    preserveExistingMetadata: isExisting,
                                    recurrenceRuleManager: ruleManager
                                )
                                bgEvent.recurrenceRules = nil

                                try bgStore.save(bgEvent, span: .thisEvent, commit: true)
                                return bgEvent.eventIdentifier ?? ""
                            }.value

                            let resolvedEvent = self.eventStore.event(withIdentifier: savedId) ?? (remoteEvent ?? ekEventFallback)
                            await self.applyRemoteEventToSession(
                                remoteEvent: resolvedEvent,
                                session: local,
                                includeCoreFields: false
                            )
                            print("[SyncService] Pushed detached instance to calendar: \(eventTitle) @ \(date)")
                        } catch {
                            print("[SyncService] Error pushing detached instance: \(error.localizedDescription)")
                        }
                    }
                } else if let remote = remoteInstance, localInstance == nil {
                    let descriptor = FetchDescriptor<Session>(
                        predicate: #Predicate<Session> {
                            $0.isDetached == true && $0.occurrenceDate == date
                        }
                    )
                    let existing = (try? modelContext.fetch(descriptor))?.first { ($0.derivedFromEKEventID ?? "") == snapshot.id.uuidString }

                    let detached: Session
                    if let existing = existing {
                        detached = existing
                    } else {
                        let sessionFactory = SessionFactory(context: modelContext)
                        detached = sessionFactory.createDetachedInstance(from: snapshot, at: date) { _ in }
                    }

                    await self.applyRemoteEventToSession(
                        remoteEvent: remote,
                        session: detached,
                        includeCoreFields: true
                    )
                    detached.status = snapshot.status
                    detached.recurrenceRuleData = nil
                    detached.ekRecurrenceRuleDescription = nil
                    print("[SyncService] Created detached instance from remote: \(detached.title) @ \(date)")
                }
            }
        }
    }

    func applyInstanceMergeChoice(
        snapshot: SessionSnapshot,
        date: Date,
        choice: ConflictResolutionChoice,
        local: Session?,
        remote: EKEvent?,
        modelContext: ModelContext
    ) {
        Task { @MainActor in
            switch choice {
            case .preferApp:
                if let local = local {
                    let localSnapshot = local.snapshot()
                    let remoteEvent = await self.findRemoteEvent(for: localSnapshot)
                    let calendarIdentifier = self.selectedCalendar?.calendarIdentifier
                    let isExisting = remoteEvent != nil
                    let remoteEventId = remoteEvent?.eventIdentifier
                    let eventTitle = local.title
                    let ekEventFallback = EKEvent(eventStore: self.eventStore)
                    if !isExisting {
                        ekEventFallback.calendar = self.selectedCalendar
                    }
                    let ruleManager = self.recurrenceRuleManager

                    Task {
                        do {
                            let savedId = try await Task.detached(priority: .userInitiated) {
                                let bgStore = EKEventStore()
                                let bgCalendar = calendarIdentifier.flatMap { bgStore.calendar(withIdentifier: $0) }

                                let bgEvent: EKEvent
                                if let eventId = remoteEventId, let existing = bgStore.event(withIdentifier: eventId) {
                                    bgEvent = existing
                                    _ = bgEvent.refresh()
                                } else {
                                    bgEvent = EKEvent(eventStore: bgStore)
                                    bgEvent.calendar = bgCalendar
                                }

                                EventKitSessionWriter.mapSessionToEvent(
                                    localSnapshot,
                                    event: bgEvent,
                                    preserveExistingMetadata: isExisting,
                                    recurrenceRuleManager: ruleManager
                                )
                                bgEvent.recurrenceRules = nil

                                try bgStore.save(bgEvent, span: .thisEvent, commit: true)
                                return bgEvent.eventIdentifier ?? ""
                            }.value

                            let resolvedEvent = self.eventStore.event(withIdentifier: savedId) ?? (remoteEvent ?? ekEventFallback)
                            await self.applyRemoteEventToSession(
                                remoteEvent: resolvedEvent,
                                session: local,
                                includeCoreFields: false
                            )
                            print("[SyncService] Pushed detached instance to calendar (user preferApp): \(eventTitle) @ \(date)")
                        } catch {
                            print("[SyncService] Error pushing detached instance (user preferApp): \(error.localizedDescription)")
                        }
                    }
                }
            case .preferCalendar:
                if let remote = remote {
                    let descriptor = FetchDescriptor<Session>(
                        predicate: #Predicate<Session> {
                            $0.isDetached == true && $0.occurrenceDate == date
                        }
                    )
                    let existing = (try? modelContext.fetch(descriptor))?.first { ($0.derivedFromEKEventID ?? "") == snapshot.id.uuidString }

                    let detached: Session
                    if let existing = existing {
                        detached = existing
                    } else {
                        let sessionFactory = SessionFactory(context: modelContext)
                        detached = sessionFactory.createDetachedInstance(from: snapshot, at: date) { _ in }
                    }

                    await self.applyRemoteEventToSession(
                        remoteEvent: remote,
                        session: detached,
                        includeCoreFields: true
                    )
                    detached.status = snapshot.status

                    detached.recurrenceRuleData = nil
                    detached.ekRecurrenceRuleDescription = nil
                    print("[SyncService] Pulled detached instance from calendar (user preferCalendar): \(detached.title) @ \(date)")
                }
            case .skip:
                break
            }
        }
    }
}
