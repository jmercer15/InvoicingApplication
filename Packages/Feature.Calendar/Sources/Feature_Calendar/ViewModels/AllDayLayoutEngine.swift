import Foundation
import SwiftUI
import SharedUI

struct AllDayPositionedItem: Identifiable {
    let id: String
    let item: DisplayableCalendarItem
    let startDayIndex: Int
    let endDayIndex: Int
    let rowIndex: Int
}

/// Layout helper for the all‑day strip.
struct AllDayLayoutEngine {
    // Display configuration
    let maxItemsToShow: Int
    let itemSpacing: CGFloat
    let columnHorizontalPadding: CGFloat
    let columnVerticalPadding: CGFloat
    let moreBadgeHorizontalPadding: CGFloat
    let moreBadgeVerticalPadding: CGFloat
    let stripHeight: CGFloat

    init(maxItemsToShow: Int = 3,
         itemSpacing: CGFloat = StyleGuide.Dimensions.paddingXSmall,
         columnHorizontalPadding: CGFloat = StyleGuide.Dimensions.paddingMedium,
         columnVerticalPadding: CGFloat = StyleGuide.Dimensions.paddingSmall,
         moreBadgeHorizontalPadding: CGFloat = StyleGuide.Dimensions.paddingSmall,
         moreBadgeVerticalPadding: CGFloat = StyleGuide.Dimensions.paddingXSmall,
         stripHeight: CGFloat = 40) {
        self.maxItemsToShow = maxItemsToShow
        self.itemSpacing = itemSpacing
        self.columnHorizontalPadding = columnHorizontalPadding
        self.columnVerticalPadding = columnVerticalPadding
        self.moreBadgeHorizontalPadding = moreBadgeHorizontalPadding
        self.moreBadgeVerticalPadding = moreBadgeVerticalPadding
        self.stripHeight = stripHeight
    }

    func visibleItems<T: RandomAccessCollection>(from items: T) -> Array<T.Element> where T.Element: Identifiable {
        Array(items.prefix(maxItemsToShow))
    }

    func moreCount<T: Collection>(for items: T) -> Int { max(0, items.count - maxItemsToShow) }

    /// Calculates the required height for the all-day strip based on the maximum number of items in any of the days.
    @MainActor func stripHeight(for weekDays: [Date], viewModel: CalendarViewModel) -> CGFloat {
        let positionedItems = calculateAllDayLayout(for: viewModel.allDayItems, weekDays: weekDays)
        let maxRowIndex = positionedItems.map { $0.rowIndex }.max() ?? -1
        let rowCount = maxRowIndex + 1

        if rowCount == 0 {
            return 0
        }

        let rowHeight: CGFloat = 24
        let spacing = itemSpacing

        var totalHeight = CGFloat(rowCount) * rowHeight + CGFloat(rowCount - 1) * spacing
        totalHeight += 2 * columnVerticalPadding

        return totalHeight + 4 // Safety margin
    }

    /// Group daily segments, compute spans, sort them (longer first), and assign row indices using a greedy interval coloring algorithm.
    func calculateAllDayLayout(
        for items: [DisplayableCalendarItem],
        weekDays: [Date]
    ) -> [AllDayPositionedItem] {
        guard !items.isEmpty, !weekDays.isEmpty else { return [] }

        let calendar = Calendar.current

        // 1. Group items by their logical identity to merge multi-day segments
        var groupedSegments: [String: [DisplayableCalendarItem]] = [:]
        for item in items {
            let key: String
            switch item {
            case .session(let session):
                key = "session_\(session.id.uuidString)"
            case .recurringSessionInstance(let template, let startDate, _, _, _, _):
                let occurrenceDate = calendar.startOfDay(for: startDate)
                key = "recurring_\(template.id.uuidString)_\(occurrenceDate.timeIntervalSinceReferenceDate)"
            case .event(let event):
                let eventId = event.eventIdentifier ?? "unsaved"
                key = "event_\(eventId)_\(calendar.startOfDay(for: event.startDate).timeIntervalSinceReferenceDate)"
            case .eventSegment(let originalEvent, _, _, _, _, _):
                let eventId = originalEvent.eventIdentifier ?? "unsaved"
                key = "event_\(eventId)_\(calendar.startOfDay(for: originalEvent.startDate).timeIntervalSinceReferenceDate)"
            }
            groupedSegments[key, default: []].append(item)
        }

        // 2. For each group, find its day span within the current week
        struct TempSpan {
            let key: String
            let representativeItem: DisplayableCalendarItem
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

            if minIndex <= maxIndex {
                spans.append(TempSpan(
                    key: key,
                    representativeItem: segments[0],
                    startDayIndex: minIndex,
                    endDayIndex: maxIndex,
                    spanLength: maxIndex - minIndex + 1
                ))
            }
        }

        // 3. Sort spans: longer spans first (looks cleaner), then by startDayIndex
        let sortedSpans = spans.sorted {
            if $0.spanLength != $1.spanLength {
                return $0.spanLength > $1.spanLength
            }
            return $0.startDayIndex < $1.startDayIndex
        }

        // 4. Place spans into rows using a greedy interval coloring algorithm
        var rows: [[TempSpan]] = []
        var positionedItems: [AllDayPositionedItem] = []

        for span in sortedSpans {
            var placed = false
            for (rowIndex, rowSpans) in rows.enumerated() {
                let overlaps = rowSpans.contains { other in
                    span.startDayIndex <= other.endDayIndex && other.startDayIndex <= span.endDayIndex
                }
                if !overlaps {
                    rows[rowIndex].append(span)
                    positionedItems.append(AllDayPositionedItem(
                        id: span.key,
                        item: span.representativeItem,
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
                positionedItems.append(AllDayPositionedItem(
                    id: span.key,
                    item: span.representativeItem,
                    startDayIndex: span.startDayIndex,
                    endDayIndex: span.endDayIndex,
                    rowIndex: rows.count - 1
                ))
            }
        }

        return positionedItems
    }
}
