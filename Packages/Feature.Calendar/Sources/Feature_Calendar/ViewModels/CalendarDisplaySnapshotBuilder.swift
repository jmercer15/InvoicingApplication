import Foundation
import Core

// MARK: - Sendable item recipes (background pipeline)

enum CalendarDisplayItemRecipe: Sendable, Hashable, Identifiable {
    case session(UUID)
    case recurringSessionInstance(
        templateID: UUID,
        instanceStart: Date,
        instanceEnd: Date,
        instanceIsAllDay: Bool,
        originalStart: Date?,
        originalEnd: Date?
    )
    case event(eventIdentifier: String, occurrenceAnchor: TimeInterval)
    case eventSegment(
        eventIdentifier: String,
        segmentStart: Date,
        segmentEnd: Date,
        segmentIsAllDay: Bool,
        originalStart: Date?,
        originalEnd: Date?
    )

    var id: String {
        switch self {
        case .session(let sessionID):
            return sessionID.uuidString
        case .recurringSessionInstance(let templateID, let instanceStart, _, _, _, _):
            return "\(templateID.uuidString)_\(instanceStart.timeIntervalSinceReferenceDate)"
        case .event(let eventIdentifier, let occurrenceAnchor):
            return "\(eventIdentifier)_\(occurrenceAnchor)"
        case .eventSegment(let eventIdentifier, let segmentStart, _, _, _, _):
            return "\(eventIdentifier)_\(segmentStart.timeIntervalSinceReferenceDate)"
        }
    }

    var startDate: Date? {
        switch self {
        case .session:
            return nil
        case .recurringSessionInstance(_, let instanceStart, _, _, _, _):
            return instanceStart
        case .event(_, let occurrenceAnchor):
            return Date(timeIntervalSinceReferenceDate: occurrenceAnchor)
        case .eventSegment(_, let segmentStart, _, _, _, _):
            return segmentStart
        }
    }

    var endDate: Date? {
        switch self {
        case .session:
            return nil
        case .recurringSessionInstance(_, _, let instanceEnd, _, _, _):
            return instanceEnd
        case .event:
            return nil
        case .eventSegment(_, _, let segmentEnd, _, _, _):
            return segmentEnd
        }
    }

    var isAllDay: Bool {
        switch self {
        case .session:
            return false
        case .recurringSessionInstance(_, _, _, let instanceIsAllDay, _, _):
            return instanceIsAllDay
        case .event:
            return false
        case .eventSegment(_, _, _, let segmentIsAllDay, _, _):
            return segmentIsAllDay
        }
    }

    var isSession: Bool {
        switch self {
        case .session, .recurringSessionInstance:
            return true
        case .event, .eventSegment:
            return false
        }
    }
}

struct CalendarDisplayBuildInput: Sendable {
    let viewStart: Date
    let viewEnd: Date
    let sessionSnapshots: [SessionSnapshot]
    let recurringSnapshots: [SessionSnapshot]
    let nonRecurringSnapshots: [SessionSnapshot]
    let detachedOverridesByMaster: [UUID: Set<Date>]
    let eventSnapshots: [EventKitEventSnapshot]
    let visibleCalendarIdentifiers: Set<String>
    let weekDays: [Date]
    let recurrenceRuleManager: RecurrenceRuleManager
}

struct CalendarDisplayBuildOutput: Sendable {
    let allDayRecipes: [CalendarDisplayItemRecipe]
    let timedRecipes: [CalendarDisplayItemRecipe]
    let timedRecipesByDay: [DateComponents: [CalendarDisplayItemRecipe]]
    let allDayRecipesByDay: [DateComponents: [CalendarDisplayItemRecipe]]
    let combinedRecipesByDay: [DateComponents: [CalendarDisplayItemRecipe]]
    let relativePlacementsByDay: [DateComponents: [String: CalendarItemOverlapGeometry.RelativePlacement]]
    let allDaySpanLayouts: [AllDaySpanLayout]
    let allDayStripHeight: CGFloat
}

struct AllDaySpanLayout: Sendable {
    let key: String
    let recipe: CalendarDisplayItemRecipe
    let startDayIndex: Int
    let endDayIndex: Int
    let rowIndex: Int
}

enum CalendarDisplaySnapshotBuilder {
    nonisolated static func build(_ input: CalendarDisplayBuildInput) -> CalendarDisplayBuildOutput {
        let calendar = Calendar.current
        let normalizeOccurrenceAnchor: (Date, Bool) -> Date = { date, isAllDay in
            if isAllDay {
                return calendar.startOfDay(for: date)
            }
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            return calendar.date(from: comps) ?? date
        }

        var localAllDay: [CalendarDisplayItemRecipe] = []
        var localTimed: [CalendarDisplayItemRecipe] = []
        localAllDay.reserveCapacity(input.sessionSnapshots.count + input.eventSnapshots.count)
        localTimed.reserveCapacity(input.sessionSnapshots.count + input.eventSnapshots.count)

        let recurrenceService = RecurrenceService(recurrenceRuleManager: input.recurrenceRuleManager)
        let expanded = recurrenceService.expandRecurringSnapshots(
            input.recurringSnapshots,
            rangeStart: input.viewStart,
            rangeEnd: input.viewEnd
        )

        for sessionData in expanded {
            let master = sessionData.masterSnapshot
            let overriddenAnchors = input.detachedOverridesByMaster[master.id] ?? []
            for instance in sessionData.instances {
                let instanceAnchor = normalizeOccurrenceAnchor(instance.instanceStart, master.isAllDay)
                if overriddenAnchors.contains(instanceAnchor) {
                    continue
                }
                let recipe = CalendarDisplayItemRecipe.recurringSessionInstance(
                    templateID: master.id,
                    instanceStart: instance.instanceStart,
                    instanceEnd: instance.instanceEnd,
                    instanceIsAllDay: master.isAllDay,
                    originalStart: instance.instanceStart,
                    originalEnd: instance.instanceEnd
                )
                splitMultiDayRecipe(
                    recipe,
                    masterIsAllDay: master.isAllDay,
                    into: &localAllDay,
                    and: &localTimed
                )
            }
        }

        for snapshot in input.nonRecurringSnapshots {
            splitMultiDayRecipe(
                .session(snapshot.id),
                masterIsAllDay: snapshot.isAllDay,
                sessionSnapshot: snapshot,
                into: &localAllDay,
                and: &localTimed
            )
        }

        for event in input.eventSnapshots {
            guard input.visibleCalendarIdentifiers.contains(event.calendarIdentifier) else { continue }
            let eventID = event.eventIdentifier ?? event.calendarItemExternalIdentifier ?? event.id
            let start = event.startDate ?? Date()
            let end = event.endDate ?? start
            let recipe = CalendarDisplayItemRecipe.eventSegment(
                eventIdentifier: eventID,
                segmentStart: start,
                segmentEnd: end,
                segmentIsAllDay: event.isAllDay,
                originalStart: event.startDate,
                originalEnd: event.endDate
            )
            splitMultiDayRecipe(
                recipe,
                masterIsAllDay: event.isAllDay,
                eventSnapshot: event,
                into: &localAllDay,
                and: &localTimed
            )
        }

        let sortedAllDay = localAllDay.sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }
        let sortedTimed = localTimed.sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }

        let grouped = groupRecipesByDay(allDay: sortedAllDay, timed: sortedTimed, calendar: calendar)
        let placements = calculateRelativePlacements(for: sortedTimed)
        let (spanLayouts, stripHeight) = calculateAllDayLayout(
            for: sortedAllDay,
            weekDays: input.weekDays,
            calendar: calendar
        )

        return CalendarDisplayBuildOutput(
            allDayRecipes: sortedAllDay,
            timedRecipes: sortedTimed,
            timedRecipesByDay: grouped.timedByDay,
            allDayRecipesByDay: grouped.allDayByDay,
            combinedRecipesByDay: grouped.combinedByDay,
            relativePlacementsByDay: placements,
            allDaySpanLayouts: spanLayouts,
            allDayStripHeight: stripHeight
        )
    }

    nonisolated private static func splitMultiDayRecipe(
        _ recipe: CalendarDisplayItemRecipe,
        masterIsAllDay: Bool,
        sessionSnapshot: SessionSnapshot? = nil,
        eventSnapshot: EventKitEventSnapshot? = nil,
        into allDay: inout [CalendarDisplayItemRecipe],
        and timed: inout [CalendarDisplayItemRecipe]
    ) {
        let startDate = recipe.startDate ?? sessionSnapshot?.startTime ?? eventSnapshot?.startDate
        let endDate = recipe.endDate ?? sessionSnapshot?.endTime ?? eventSnapshot?.endDate
        let isAllDay = recipe.isAllDay || sessionSnapshot?.isAllDay == true || eventSnapshot?.isAllDay == true || masterIsAllDay

        guard let startDate, let endDate else {
            if isAllDay { allDay.append(recipe) } else { timed.append(recipe) }
            return
        }

        let calendar = Calendar.current
        let effectiveEndDate = (calendar.startOfDay(for: endDate) == endDate)
            ? calendar.date(byAdding: .second, value: -1, to: endDate)!
            : endDate

        if calendar.isDate(startDate, inSameDayAs: effectiveEndDate) {
            if isAllDay { allDay.append(recipe) } else { timed.append(recipe) }
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
                instanceIsAllDay = isAllDay
            } else if isLastDay {
                instanceStartDate = calendar.startOfDay(for: currentDate)
                instanceEndDate = effectiveEndDate
                instanceIsAllDay = isAllDay
            } else {
                instanceStartDate = calendar.startOfDay(for: currentDate)
                instanceEndDate = calendar.endOfDay(for: currentDate)
                instanceIsAllDay = true
            }

            let segment = segmentRecipe(
                for: recipe,
                eventSnapshot: eventSnapshot,
                startDate: instanceStartDate,
                endDate: instanceEndDate,
                isAllDay: instanceIsAllDay
            )

            if segment.isAllDay {
                allDay.append(segment)
            } else {
                timed.append(segment)
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
    }

    nonisolated private static func segmentRecipe(
        for original: CalendarDisplayItemRecipe,
        eventSnapshot: EventKitEventSnapshot?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool
    ) -> CalendarDisplayItemRecipe {
        switch original {
        case .session(let id):
            return .session(id)
        case .recurringSessionInstance(let templateID, _, _, _, let originalStart, let originalEnd):
            return .recurringSessionInstance(
                templateID: templateID,
                instanceStart: startDate,
                instanceEnd: endDate,
                instanceIsAllDay: isAllDay,
                originalStart: originalStart ?? startDate,
                originalEnd: originalEnd ?? endDate
            )
        case .event(let eventIdentifier, _):
            return .event(
                eventIdentifier: eventIdentifier,
                occurrenceAnchor: startDate.timeIntervalSinceReferenceDate
            )
        case .eventSegment(let eventIdentifier, _, _, _, let originalStart, let originalEnd):
            return .eventSegment(
                eventIdentifier: eventIdentifier,
                segmentStart: startDate,
                segmentEnd: endDate,
                segmentIsAllDay: isAllDay,
                originalStart: originalStart ?? eventSnapshot?.startDate,
                originalEnd: originalEnd ?? eventSnapshot?.endDate
            )
        }
    }

    nonisolated private static func groupRecipesByDay(
        allDay: [CalendarDisplayItemRecipe],
        timed: [CalendarDisplayItemRecipe],
        calendar: Calendar
    ) -> (timedByDay: [DateComponents: [CalendarDisplayItemRecipe]], allDayByDay: [DateComponents: [CalendarDisplayItemRecipe]], combinedByDay: [DateComponents: [CalendarDisplayItemRecipe]]) {
        var timedGrouped: [DateComponents: [CalendarDisplayItemRecipe]] = [:]
        var allDayGrouped: [DateComponents: [CalendarDisplayItemRecipe]] = [:]

        for recipe in timed {
            if let date = recipe.startDate {
                let comps = calendar.dateComponents([.year, .month, .day], from: date)
                timedGrouped[comps, default: []].append(recipe)
            }
        }

        for recipe in allDay {
            if let date = recipe.startDate {
                let comps = calendar.dateComponents([.year, .month, .day], from: date)
                allDayGrouped[comps, default: []].append(recipe)
            }
        }

        var combined: [DateComponents: [CalendarDisplayItemRecipe]] = [:]
        let dayKeys = Set(timedGrouped.keys).union(allDayGrouped.keys)
        for comps in dayKeys {
            let merged = (timedGrouped[comps] ?? []) + (allDayGrouped[comps] ?? [])
            combined[comps] = merged.sorted {
                ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
            }
        }

        return (timedGrouped, allDayGrouped, combined)
    }

    nonisolated private static func calculateRelativePlacements(
        for recipes: [CalendarDisplayItemRecipe]
    ) -> [DateComponents: [String: CalendarItemOverlapGeometry.RelativePlacement]] {
        let calendar = Calendar.current
        var timedGrouped: [DateComponents: [CalendarDisplayItemRecipe]] = [:]
        for recipe in recipes {
            guard let date = recipe.startDate else { continue }
            let comps = calendar.dateComponents([.year, .month, .day], from: date)
            timedGrouped[comps, default: []].append(recipe)
        }

        var relativePlacements: [DateComponents: [String: CalendarItemOverlapGeometry.RelativePlacement]] = [:]
        for (comps, dayRecipes) in timedGrouped {
            relativePlacements[comps] = CalendarItemOverlapGeometry.calculateRelativePlacements(
                for: dayRecipes.map { CalendarItemTiming(recipe: $0) }
            )
        }
        return relativePlacements
    }

    nonisolated private static func calculateAllDayLayout(
        for recipes: [CalendarDisplayItemRecipe],
        weekDays: [Date],
        calendar: Calendar
    ) -> ([AllDaySpanLayout], CGFloat) {
        guard !recipes.isEmpty, !weekDays.isEmpty else { return ([], 0) }

        var groupedSegments: [String: [CalendarDisplayItemRecipe]] = [:]
        for recipe in recipes {
            let key = allDayGroupingKey(for: recipe, calendar: calendar)
            groupedSegments[key, default: []].append(recipe)
        }

        struct TempSpan {
            let key: String
            let recipe: CalendarDisplayItemRecipe
            let startDayIndex: Int
            let endDayIndex: Int
            let spanLength: Int
        }

        var spans: [TempSpan] = []
        for (key, segments) in groupedSegments {
            var minIndex = Int.max
            var maxIndex = Int.min

            for segment in segments {
                guard let segmentDate = segment.startDate else { continue }
                for (dayIndex, day) in weekDays.enumerated() {
                    if calendar.isDate(segmentDate, inSameDayAs: day) {
                        minIndex = min(minIndex, dayIndex)
                        maxIndex = max(maxIndex, dayIndex)
                    }
                }
            }

            if minIndex <= maxIndex, let representative = segments.first {
                spans.append(TempSpan(
                    key: key,
                    recipe: representative,
                    startDayIndex: minIndex,
                    endDayIndex: maxIndex,
                    spanLength: maxIndex - minIndex + 1
                ))
            }
        }

        let sortedSpans = spans.sorted {
            if $0.spanLength != $1.spanLength {
                return $0.spanLength > $1.spanLength
            }
            return $0.startDayIndex < $1.startDayIndex
        }

        var rows: [[TempSpan]] = []
        var layouts: [AllDaySpanLayout] = []

        for span in sortedSpans {
            var placed = false
            for (rowIndex, rowSpans) in rows.enumerated() {
                let overlaps = rowSpans.contains { other in
                    span.startDayIndex <= other.endDayIndex && other.startDayIndex <= span.endDayIndex
                }
                if !overlaps {
                    rows[rowIndex].append(span)
                    layouts.append(AllDaySpanLayout(
                        key: span.key,
                        recipe: span.recipe,
                        startDayIndex: span.startDayIndex,
                        endDayIndex: span.endDayIndex,
                        rowIndex: rowIndex
                    ))
                    placed = true
                    break
                }
            }

            if !placed {
                rows.append([span])
                layouts.append(AllDaySpanLayout(
                    key: span.key,
                    recipe: span.recipe,
                    startDayIndex: span.startDayIndex,
                    endDayIndex: span.endDayIndex,
                    rowIndex: rows.count - 1
                ))
            }
        }

        let maxRowIndex = layouts.map(\.rowIndex).max() ?? -1
        let rowCount = maxRowIndex + 1
        let height: CGFloat
        if rowCount == 0 {
            height = 0
        } else {
            let rowHeight: CGFloat = 24
            let spacing: CGFloat = 4
            var totalHeight = CGFloat(rowCount) * rowHeight + CGFloat(rowCount - 1) * spacing
            totalHeight += 2 * 8
            height = totalHeight + 4
        }

        return (layouts, height)
    }

    nonisolated private static func allDayGroupingKey(for recipe: CalendarDisplayItemRecipe, calendar: Calendar) -> String {
        switch recipe {
        case .session(let sessionID):
            return "session_\(sessionID.uuidString)"
        case .recurringSessionInstance(let templateID, let startDate, _, _, _, _):
            let occurrenceDate = calendar.startOfDay(for: startDate)
            return "recurring_\(templateID.uuidString)_\(occurrenceDate.timeIntervalSinceReferenceDate)"
        case .event(let eventIdentifier, let occurrenceAnchor):
            return "event_\(eventIdentifier)_\(occurrenceAnchor)"
        case .eventSegment(let eventIdentifier, let segmentStart, _, _, _, _):
            return "event_\(eventIdentifier)_\(calendar.startOfDay(for: segmentStart).timeIntervalSinceReferenceDate)"
        }
    }
}

// MARK: - Timing adapter for overlap geometry

struct CalendarItemTiming: Sendable {
    let recipe: CalendarDisplayItemRecipe

    var id: String { recipe.id }

    var startHour: CGFloat {
        guard let startTime = recipe.startDate else { return 0 }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: startTime)
        let minute = calendar.component(.minute, from: startTime)
        return CGFloat(hour) + CGFloat(minute) / 60.0
    }

    var durationHours: CGFloat {
        guard let startTime = recipe.startDate, let endTime = recipe.endDate, endTime > startTime else {
            return recipe.isSession ? 0.5 : 0.25
        }
        let calendar = Calendar(identifier: .gregorian)
        let comps = calendar.dateComponents([.hour, .minute, .second], from: startTime, to: endTime)
        let hours = CGFloat(comps.hour ?? 0)
        let minutes = CGFloat(comps.minute ?? 0) / 60.0
        let seconds = CGFloat(comps.second ?? 0) / 3600.0
        let calculatedDuration = hours + minutes + seconds
        let minDuration: CGFloat = recipe.isSession ? 0.5 : 0.25
        return max(minDuration, calculatedDuration)
    }
}

extension CalendarItemOverlapGeometry {
    static func calculateRelativePlacements(
        for items: [CalendarItemTiming]
    ) -> [String: RelativePlacement] {
        guard !items.isEmpty else { return [:] }

        let sortedIndices = items.indices.sorted { idx1, idx2 in
            let item1 = items[idx1]
            let item2 = items[idx2]
            if item1.startHour != item2.startHour {
                return item1.startHour < item2.startHour
            }
            return item1.durationHours > item2.durationHours
        }

        let indexPosition = Dictionary(uniqueKeysWithValues: sortedIndices.enumerated().map { ($1, $0) })

        var visited = Set<Int>()
        var clusters: [[Int]] = []

        for idx in sortedIndices {
            if visited.contains(idx) { continue }

            var cluster = [Int]()
            var queue = [idx]
            visited.insert(idx)

            while !queue.isEmpty {
                let current = queue.removeFirst()
                cluster.append(current)

                let itemCurrent = items[current]
                let startCurrent = itemCurrent.startHour
                let endCurrent = itemCurrent.startHour + itemCurrent.durationHours

                for other in sortedIndices {
                    if visited.contains(other) { continue }
                    let itemOther = items[other]
                    let startOther = itemOther.startHour
                    let endOther = itemOther.startHour + itemOther.durationHours

                    if startCurrent < endOther && startOther < endCurrent {
                        visited.insert(other)
                        queue.append(other)
                    }
                }
            }

            let sortedCluster = cluster.sorted {
                (indexPosition[$0] ?? 0) < (indexPosition[$1] ?? 0)
            }
            clusters.append(sortedCluster)
        }

        var results = [String: RelativePlacement]()
        results.reserveCapacity(items.count)

        for cluster in clusters {
            var columns: [[Int]] = []
            var itemToColumn = [Int: Int]()

            for idx in cluster {
                let item = items[idx]
                var placed = false
                for colIdx in 0..<columns.count {
                    if let lastIdx = columns[colIdx].last {
                        let lastItem = items[lastIdx]
                        let lastEnd = lastItem.startHour + lastItem.durationHours
                        if item.startHour >= lastEnd {
                            columns[colIdx].append(idx)
                            itemToColumn[idx] = colIdx
                            placed = true
                            break
                        }
                    }
                }
                if !placed {
                    columns.append([idx])
                    itemToColumn[idx] = columns.count - 1
                }
            }

            let columnCount = columns.count

            for idx in cluster {
                let colI = itemToColumn[idx]!
                let itemI = items[idx]
                let startI = itemI.startHour
                let endI = itemI.startHour + itemI.durationHours

                var nextCol = columnCount
                for otherIdx in cluster {
                    if otherIdx == idx { continue }
                    let colJ = itemToColumn[otherIdx]!
                    if colJ > colI {
                        let itemJ = items[otherIdx]
                        let startJ = itemJ.startHour
                        let endJ = itemJ.startHour + itemJ.durationHours

                        if startI < endJ && startJ < endI {
                            nextCol = min(nextCol, colJ)
                        }
                    }
                }

                results[itemI.id] = RelativePlacement(
                    columnIndex: colI,
                    columnSpan: nextCol - colI,
                    totalColumns: columnCount
                )
            }
        }

        return results
    }
}
