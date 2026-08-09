import Foundation
import Core
import PersistenceModels
import SwiftData
import EventKit
import SwiftUI
import Data

struct DisplayItemsRefreshFingerprint: Hashable, Sendable {
    let viewStart: TimeInterval
    let viewEnd: TimeInterval
    let sessionSignature: String
    let visibleCalendarsSignature: String
    let eventStoreChangeGeneration: UInt64
    let storeRevision: Int

    init(
        viewRange: (start: Date, end: Date),
        sessions: [Session],
        visibleCalendarIdentifiers: Set<String>,
        eventStoreChangeGeneration: UInt64,
        storeRevision: Int
    ) {
        self.init(
            input: DisplayItemsRefreshFingerprintInput(
                viewStart: viewRange.start.timeIntervalSinceReferenceDate,
                viewEnd: viewRange.end.timeIntervalSinceReferenceDate,
                sessionSnapshots: sessions.map { $0.snapshot() },
                visibleCalendarIdentifiers: visibleCalendarIdentifiers,
                eventStoreChangeGeneration: eventStoreChangeGeneration,
                storeRevision: storeRevision
            )
        )
    }

    init(input: DisplayItemsRefreshFingerprintInput) {
        viewStart = input.viewStart
        viewEnd = input.viewEnd
        sessionSignature = Self.makeSessionSignature(from: input.sessionSnapshots)
        visibleCalendarsSignature = input.visibleCalendarIdentifiers.sorted().joined(separator: "|")
        eventStoreChangeGeneration = input.eventStoreChangeGeneration
        storeRevision = input.storeRevision
    }

    static func makeSessionSignature(from snapshots: [SessionSnapshot]) -> String {
        snapshots
            .map { snapshot in
                "\(snapshot.id.uuidString)|\(snapshot.startTime?.timeIntervalSinceReferenceDate ?? -1)|\(snapshot.endTime?.timeIntervalSinceReferenceDate ?? -1)|\(snapshot.lastModifiedDate?.timeIntervalSinceReferenceDate ?? -1)|\(snapshot.recurrenceRuleData?.count ?? 0)"
            }
            .sorted()
            .joined(separator: ";")
    }
}

struct DisplayItemsRefreshFingerprintInput: Sendable {
    let viewStart: TimeInterval
    let viewEnd: TimeInterval
    let sessionSnapshots: [SessionSnapshot]
    let visibleCalendarIdentifiers: Set<String>
    let eventStoreChangeGeneration: UInt64
    let storeRevision: Int
}

extension CalendarViewModel {

    // MARK: - Event Fetching and Processing

    /// Updates displayable items.
    func updateDisplayableItems() {
        let (viewStartDate, viewEndDate) = currentViewDateRange

        displayItemsUpdateTask?.cancel()
        displayItemsUpdateGeneration &+= 1
        let generation = displayItemsUpdateGeneration
        displayItemsUpdateTask = Task { @MainActor in
            guard await Task.waitUnlessCancelled(for: .milliseconds(32)) else { return }
            guard !Task.isCancelled, self.displayItemsUpdateGeneration == generation else { return }

            self.display.isLoading = true
            defer {
                if self.displayItemsUpdateGeneration == generation {
                    self.display.isLoading = false
                }
            }

            let statusFilter = self.filterStatuses
            let hasFilter = !statusFilter.isEmpty
            let searchTextFilter = self.searchText.lowercased()
            let clientIds = self.selectedClientFilterIDs
            let showCancelled = self.showCancelledSessions

            let fetchedSessions: [Session]
            do {
                let sessionIDs = try await workflow.fetchProjectedSessionIDs(
                    range: (viewStartDate, viewEndDate),
                    selectedClientFilterIDs: clientIds,
                    showCancelledSessions: showCancelled,
                    allowedStatuses: statusFilter,
                    hasStatusFilter: hasFilter,
                    normalizedSearchText: searchTextFilter
                )
                let descriptor = FetchDescriptor<Session>(
                    predicate: #Predicate { sessionIDs.contains($0.persistentModelID) }
                )
                fetchedSessions = try modelContext.fetch(descriptor)
            } catch {
                reportOperationFailure("Refresh calendar sessions", error: error)
                return
            }

            let sessionSnapshots = fetchedSessions.map { $0.snapshot() }
            let fingerprintInput = DisplayItemsRefreshFingerprintInput(
                viewStart: viewStartDate.timeIntervalSinceReferenceDate,
                viewEnd: viewEndDate.timeIntervalSinceReferenceDate,
                sessionSnapshots: sessionSnapshots,
                visibleCalendarIdentifiers: visibleCalendarIdentifiers,
                eventStoreChangeGeneration: eventStoreChangeGeneration,
                storeRevision: dataRevision
            )
            let fingerprint = await Task(priority: .utility) {
                DisplayItemsRefreshFingerprint(input: fingerprintInput)
            }.value

            if fingerprint == self.lastDisplayItemsRefreshFingerprint {
                return
            }
            self.lastDisplayItemsRefreshFingerprint = fingerprint

            let (_, fetchedEvents) = await dataManager.fetchCalendarData(
                from: viewStartDate,
                to: viewEndDate,
                sessions: fetchedSessions
            )

            do { try Task.checkCancellation() } catch { return }
            guard self.displayItemsUpdateGeneration == generation else { return }

            let calendar = Calendar.current
            let normalizeOccurrenceAnchor: (Date, Bool) -> Date = { date, isAllDay in
                if isAllDay {
                    return calendar.startOfDay(for: date)
                }
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                return calendar.date(from: comps) ?? date
            }

            var recurringSnapshots: [SessionSnapshot] = []
            var nonRecurringSnapshots: [SessionSnapshot] = []
            var detachedOverridesByMaster: [UUID: Set<Date>] = [:]

            for session in fetchedSessions {
                let snapshot = session.snapshot()
                if session.recurrenceRuleData != nil {
                    recurringSnapshots.append(snapshot)
                } else {
                    nonRecurringSnapshots.append(snapshot)
                }

                guard session.isDetached,
                      let masterIDRaw = session.derivedFromEKEventID,
                      let masterID = UUID(uuidString: masterIDRaw),
                      let anchor = session.occurrenceDate ?? session.startTime else {
                    continue
                }

                let normalizedAnchor = normalizeOccurrenceAnchor(anchor, session.isAllDay)
                var values = detachedOverridesByMaster[masterID] ?? []
                values.insert(normalizedAnchor)
                detachedOverridesByMaster[masterID] = values
            }

            let buildInput = CalendarDisplayBuildInput(
                viewStart: viewStartDate,
                viewEnd: viewEndDate,
                sessionSnapshots: fetchedSessions.map { $0.snapshot() },
                recurringSnapshots: recurringSnapshots,
                nonRecurringSnapshots: nonRecurringSnapshots,
                detachedOverridesByMaster: detachedOverridesByMaster,
                eventSnapshots: fetchedEvents.map(EventKitEventSnapshot.from(event:)),
                visibleCalendarIdentifiers: visibleCalendarIdentifiers,
                weekDays: currentWeekDays,
                recurrenceRuleManager: recurrenceRuleManager
            )

            let buildOutput = await Task(priority: .userInitiated) {
                CalendarDisplaySnapshotBuilder.build(buildInput)
            }.value

            do { try Task.checkCancellation() } catch { return }
            guard self.displayItemsUpdateGeneration == generation else { return }

            let sessionsByID = Dictionary(uniqueKeysWithValues: fetchedSessions.map { ($0.id, $0) })
            var eventsByID: [String: EKEvent] = [:]
            for event in fetchedEvents {
                if let id = event.eventIdentifier {
                    eventsByID[id] = event
                }
                if let external = event.calendarItemExternalIdentifier {
                    eventsByID[external] = event
                }
            }

            display.filteredSessions = fetchedSessions
            for session in fetchedSessions {
                display.sessionRegistry[session.id] = session
            }

            var localClientNames: [UUID: String] = [:]
            var localServiceNames: [UUID: String] = [:]
            for session in fetchedSessions {
                if let clientId = session.clientId, let fullName = session.client?.fullName, !fullName.isEmpty {
                    localClientNames[clientId] = fullName
                }
                if let serviceId = session.clientServiceId {
                    if let serviceName = session.clientService?.serviceName, !serviceName.isEmpty {
                        localServiceNames[serviceId] = serviceName
                    } else if let assignedServiceName = session.assignedServiceName, !assignedServiceName.isEmpty {
                        localServiceNames[serviceId] = assignedServiceName
                    }
                }
            }
            display.clientNamesCache = localClientNames
            display.serviceNamesCache = localServiceNames

            display.allDayItems = buildOutput.allDayRecipes.compactMap {
                materializeRecipe($0, sessionsByID: sessionsByID, eventsByID: eventsByID)
            }
            display.timedItems = buildOutput.timedRecipes.compactMap {
                materializeRecipe($0, sessionsByID: sessionsByID, eventsByID: eventsByID)
            }
            display.timedItemsByDay = buildOutput.timedRecipesByDay.mapValues { recipes in
                recipes.compactMap { materializeRecipe($0, sessionsByID: sessionsByID, eventsByID: eventsByID) }
            }
            display.allDayItemsByDay = buildOutput.allDayRecipesByDay.mapValues { recipes in
                recipes.compactMap { materializeRecipe($0, sessionsByID: sessionsByID, eventsByID: eventsByID) }
            }
            display.combinedItemsByDay = buildOutput.combinedRecipesByDay.mapValues { recipes in
                recipes.compactMap { materializeRecipe($0, sessionsByID: sessionsByID, eventsByID: eventsByID) }
            }
            display.relativePlacementsByDay = buildOutput.relativePlacementsByDay
            display.allDayPositionedItems = buildOutput.allDaySpanLayouts.compactMap { layout in
                guard let item = materializeRecipe(layout.recipe, sessionsByID: sessionsByID, eventsByID: eventsByID) else {
                    return nil
                }
                return AllDayPositionedItem(
                    id: layout.key,
                    item: item,
                    startDayIndex: layout.startDayIndex,
                    endDayIndex: layout.endDayIndex,
                    rowIndex: layout.rowIndex
                )
            }
            display.allDayStripHeight = buildOutput.allDayStripHeight

            updateAvailableFilters()
        }
    }

    private func materializeRecipe(
        _ recipe: CalendarDisplayItemRecipe,
        sessionsByID: [UUID: Session],
        eventsByID: [String: EKEvent]
    ) -> DisplayableCalendarItem? {
        switch recipe {
        case .session(let sessionID):
            guard let session = sessionsByID[sessionID] else { return nil }
            return .session(session)
        case .recurringSessionInstance(
            let templateID,
            let instanceStart,
            let instanceEnd,
            let instanceIsAllDay,
            let originalStart,
            let originalEnd
        ):
            guard let template = sessionsByID[templateID] else { return nil }
            return .recurringSessionInstance(
                template: template,
                instanceStartDate: instanceStart,
                instanceEndDate: instanceEnd,
                instanceIsAllDay: instanceIsAllDay,
                originalStartDate: originalStart,
                originalEndDate: originalEnd
            )
        case .event(let eventIdentifier, _):
            guard let event = eventsByID[eventIdentifier] else { return nil }
            return .event(event)
        case .eventSegment(
            let eventIdentifier,
            let segmentStart,
            let segmentEnd,
            let segmentIsAllDay,
            let originalStart,
            let originalEnd
        ):
            guard let event = eventsByID[eventIdentifier] else { return nil }
            return .eventSegment(
                originalEvent: event,
                segmentStartDate: segmentStart,
                segmentEndDate: segmentEnd,
                segmentIsAllDay: segmentIsAllDay,
                originalStartDate: originalStart,
                originalEndDate: originalEnd
            )
        }
    }
}
