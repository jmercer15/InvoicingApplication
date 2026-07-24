import Foundation
import Core
import SwiftData
import EventKit
import SwiftUI

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
        viewStart = viewRange.start.timeIntervalSinceReferenceDate
        viewEnd = viewRange.end.timeIntervalSinceReferenceDate
        sessionSignature = sessions
            .map { session in
                "\(session.id.uuidString)|\(session.startTime?.timeIntervalSinceReferenceDate ?? -1)|\(session.endTime?.timeIntervalSinceReferenceDate ?? -1)|\(session.lastModifiedDate?.timeIntervalSinceReferenceDate ?? -1)|\(session.recurrenceRuleData?.count ?? 0)"
            }
            .sorted()
            .joined(separator: ";")
        visibleCalendarsSignature = visibleCalendarIdentifiers.sorted().joined(separator: "|")
        self.eventStoreChangeGeneration = eventStoreChangeGeneration
        self.storeRevision = storeRevision
    }
}

extension CalendarViewModel {
    
    // MARK: - Event Fetching and Processing

    func splitMultiDayItem(_ item: DisplayableCalendarItem, into allDay: inout [DisplayableCalendarItem], and timed: inout [DisplayableCalendarItem]) {
        guard let startDate = item.startDate, let endDate = item.endDate else {
            if item.isAllDay { allDay.append(item) } else { timed.append(item) }
            return
        }

        let calendar = Calendar.current
        
        // If an event ends exactly at midnight, treat it as ending on the last second of the previous day.
        // This prevents creating a zero-length segment for the new day.
        let effectiveEndDate = (calendar.startOfDay(for: endDate) == endDate)
            ? calendar.date(byAdding: .second, value: -1, to: endDate)!
            : endDate
        
        // If the item is no longer multi-day after this adjustment, just add it and finish.
        if calendar.isDate(startDate, inSameDayAs: effectiveEndDate) {
            if item.isAllDay { allDay.append(item) } else { timed.append(item) }
            return
        }

        var currentDate = calendar.startOfDay(for: startDate)
        let finalDayStart = calendar.startOfDay(for: effectiveEndDate)

        while currentDate <= finalDayStart {
            let isFirstDay = calendar.isDate(currentDate, inSameDayAs: startDate)
            let isLastDay = calendar.isDate(currentDate, inSameDayAs: effectiveEndDate)

            let instanceStartDate: Date
            let instanceEndDate: Date
            let instanceIsAllDay: Bool

            if isFirstDay {
                instanceStartDate = startDate
                instanceEndDate = isLastDay ? effectiveEndDate : calendar.endOfDay(for: currentDate)
                instanceIsAllDay = item.isAllDay
            } else if isLastDay {
                instanceStartDate = calendar.startOfDay(for: currentDate)
                instanceEndDate = effectiveEndDate
                instanceIsAllDay = item.isAllDay
            } else { // Middle day
                instanceStartDate = calendar.startOfDay(for: currentDate)
                instanceEndDate = calendar.endOfDay(for: currentDate)
                instanceIsAllDay = true // Any full day segment of a multi-day event is considered "all-day" for display
            }

            let newItem = self.createSegment(for: item, startDate: instanceStartDate, endDate: instanceEndDate, isAllDay: instanceIsAllDay)
            
            if newItem.isAllDay {
                allDay.append(newItem)
            } else {
                timed.append(newItem)
            }

            // Move to the next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
    }

    // Helper to create item segments to avoid duplicating logic in splitMultiDayItem
    func createSegment(for originalItem: DisplayableCalendarItem, startDate: Date, endDate: Date, isAllDay: Bool) -> DisplayableCalendarItem {
        switch originalItem {
        case .session(let session):
            return .recurringSessionInstance(
                template: session,
                instanceStartDate: startDate,
                instanceEndDate: endDate,
                instanceIsAllDay: isAllDay,
                originalStartDate: session.startTime,
                originalEndDate: session.endTime
            )
        case .event(let event):
            return .eventSegment(
                originalEvent: event,
                segmentStartDate: startDate,
                segmentEndDate: endDate,
                segmentIsAllDay: isAllDay,
                originalStartDate: event.startDate,
                originalEndDate: event.endDate
            )
        case .recurringSessionInstance(let template, let instStart, let instEnd, _, let origStart, let origEnd):
            return .recurringSessionInstance(
                template: template,
                instanceStartDate: startDate,
                instanceEndDate: endDate,
                instanceIsAllDay: isAllDay,
                originalStartDate: origStart ?? instStart,
                originalEndDate: origEnd ?? instEnd
            )
        case .eventSegment(let originalEvent, _, _, _, let origStart, let origEnd):
            return .eventSegment(
                originalEvent: originalEvent,
                segmentStartDate: startDate,
                segmentEndDate: endDate,
                segmentIsAllDay: isAllDay,
                originalStartDate: origStart ?? originalEvent.startDate,
                originalEndDate: origEnd ?? originalEvent.endDate
            )
        }
    }

    /// Updates displayable items.
    func updateDisplayableItems() {
        let (viewStartDate, viewEndDate) = currentViewDateRange
        
        // Wait, we need to execute the fetch asynchronously so we don't block the main thread.
        displayItemsUpdateTask?.cancel()
        displayItemsUpdateGeneration &+= 1
        let generation = displayItemsUpdateGeneration
        displayItemsUpdateTask = Task { @MainActor in
            // Coalesce rapid refresh requests (query churn, EventKit, context merges).
            try? await Task.sleep(for: .milliseconds(32))
            guard !Task.isCancelled, self.displayItemsUpdateGeneration == generation else { return }

            self.isLoading = true
            defer {
                if self.displayItemsUpdateGeneration == generation {
                    self.isLoading = false
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
                fetchedSessions = (try? modelContext.fetch(descriptor)) ?? []
            } catch {
                fetchedSessions = []
            }
            
            let fingerprint = DisplayItemsRefreshFingerprint(
                viewRange: (viewStartDate, viewEndDate),
                sessions: fetchedSessions,
                visibleCalendarIdentifiers: visibleCalendarIdentifiers,
                eventStoreChangeGeneration: eventStoreChangeGeneration,
                storeRevision: dataRevision
            )
            
            if fingerprint == self.lastDisplayItemsRefreshFingerprint {
                return
            }
            self.lastDisplayItemsRefreshFingerprint = fingerprint


            let (_, fetchedEvents) = await dataManager.fetchCalendarData(from: viewStartDate, to: viewEndDate, sessions: fetchedSessions)

            do { try Task.checkCancellation() } catch { return }
            guard self.displayItemsUpdateGeneration == generation else { return }

        var localAllDayItems: [DisplayableCalendarItem] = []
        var localTimedItems: [DisplayableCalendarItem] = []
        let calendar = Calendar.current
        let normalizeOccurrenceAnchor: (Date, Bool) -> Date = { date, isAllDay in
            if isAllDay {
                return calendar.startOfDay(for: date)
            }
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            return calendar.date(from: comps) ?? date
        }

        // One pass to partition session groups and collect detached overrides.
        var recurringSessions: [Session] = []
        var nonRecurringSessions: [Session] = []
        var detachedOverridesByMaster: [UUID: Set<Date>] = [:]
        for session in fetchedSessions {
            if session.recurrenceRuleData != nil {
                recurringSessions.append(session)
            } else {
                nonRecurringSessions.append(session)
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

        // Expand recurring sessions using RecurrenceService
        let expandedSessionData = Core.RecurrenceService(recurrenceRuleManager: recurrenceRuleManager).expandRecurringSessions(
            recurringSessions,
                    rangeStart: viewStartDate,
                    rangeEnd: viewEndDate
                )
        
        // Process expanded recurring sessions
        for sessionData in expandedSessionData {
            // Use domain model from SessionRecurrenceData
            let masterSession = sessionData.masterSession
            let overriddenAnchors = detachedOverridesByMaster[masterSession.id] ?? []
            for instance in sessionData.instances {
                    let instanceAnchor = normalizeOccurrenceAnchor(instance.instanceStart, masterSession.isAllDay)
                    if overriddenAnchors.contains(instanceAnchor) {
                        continue
                    }
                    let item = DisplayableCalendarItem.recurringSessionInstance(
                        template: masterSession,
                        instanceStartDate: instance.instanceStart,
                        instanceEndDate: instance.instanceEnd,
                        instanceIsAllDay: masterSession.isAllDay,
                        originalStartDate: instance.instanceStart,
                        originalEndDate: instance.instanceEnd
                    )
                splitMultiDayItem(item, into: &localAllDayItems, and: &localTimedItems)
                    }
        }
        
        // Process non-recurring sessions AND master sessions that fall within the view range
        for session in nonRecurringSessions {
                let item = DisplayableCalendarItem.session(session)
                splitMultiDayItem(item, into: &localAllDayItems, and: &localTimedItems)
        }
        
        

        // Add the filtered EKEvents to display items
        for event in fetchedEvents {
            // Filter events based on visible calendars
            let shouldShowEvent = visibleCalendarIdentifiers.contains(event.calendar.calendarIdentifier)
            
            if shouldShowEvent {
                let item = DisplayableCalendarItem.event(event)
                splitMultiDayItem(item, into: &localAllDayItems, and: &localTimedItems)
            }
        }

            // Session filtering is computed in the @Query-backed projection in CalendarView.
            // Keep this as the current working set for operations that refresh without passing
            // an explicit projection payload.
            self.filteredSessions = fetchedSessions
            for session in fetchedSessions {
                self.sessionRegistry[session.id] = session
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
            self.clientNamesCache = localClientNames
            self.serviceNamesCache = localServiceNames

            guard self.displayItemsUpdateGeneration == generation else { return }
            self.allDayItems = localAllDayItems.sorted { $0.startDate ?? .distantPast < $1.startDate ?? .distantPast }
            self.timedItems = localTimedItems.sorted { $0.startDate ?? .distantPast < $1.startDate ?? .distantPast }
            self.groupItemsByDay()
            self.updateAllDayLayout()
            updateAvailableFilters()
        }
    }

    func groupItemsByDay() {
        let calendar = Calendar.current
        var timedGrouped: [DateComponents: [DisplayableCalendarItem]] = [:]
        var allDayGrouped: [DateComponents: [DisplayableCalendarItem]] = [:]
        
        for item in timedItems {
            if let date = item.startDate {
                let comps = calendar.dateComponents([.year, .month, .day], from: date)
                timedGrouped[comps, default: []].append(item)
            }
        }
        
        for item in allDayItems {
            if let date = item.startDate {
                let comps = calendar.dateComponents([.year, .month, .day], from: date)
                allDayGrouped[comps, default: []].append(item)
            }
        }
        
        self.timedItemsByDay = timedGrouped
        self.allDayItemsByDay = allDayGrouped

        // Precalculate relative placements for timed items
        var relativePlacements: [DateComponents: [String: CalendarItemOverlapGeometry.RelativePlacement]] = [:]
        for (comps, items) in timedGrouped {
            relativePlacements[comps] = CalendarItemOverlapGeometry.calculateRelativePlacements(for: items)
        }
        self.relativePlacementsByDay = relativePlacements

        var combined: [DateComponents: [DisplayableCalendarItem]] = [:]
        let dayKeys = Set(timedGrouped.keys).union(allDayGrouped.keys)
        for comps in dayKeys {
            let merged = (timedGrouped[comps] ?? []) + (allDayGrouped[comps] ?? [])
            combined[comps] = merged.sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
        }
        self.combinedItemsByDay = combined
    }

    func updateAllDayLayout() {
        let layout = AllDayLayoutEngine()
        let positioned = layout.calculateAllDayLayout(for: allDayItems, weekDays: currentWeekDays)
        
        let maxRowIndex = positioned.map { $0.rowIndex }.max() ?? -1
        let rowCount = maxRowIndex + 1
        
        let height: CGFloat
        if rowCount == 0 {
            height = 0
        } else {
            let rowHeight: CGFloat = 24
            let spacing = layout.itemSpacing
            var totalHeight = CGFloat(rowCount) * rowHeight + CGFloat(rowCount - 1) * spacing
            totalHeight += 2 * layout.columnVerticalPadding
            height = totalHeight + 4
        }
        
        self.allDayPositionedItems = positioned
        self.allDayStripHeight = height
    }
}
