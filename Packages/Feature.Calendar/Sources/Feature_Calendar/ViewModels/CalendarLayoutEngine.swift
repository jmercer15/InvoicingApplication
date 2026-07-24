import Foundation
import SwiftUI

/// Stateless engine responsible for transforming calendar data into layout positions.
struct CalendarLayoutEngine {
    let metrics: CalendarTimelineMetrics

    struct PositionedBlock {
        let centerX: CGFloat
        let centerY: CGFloat
        let height: CGFloat
        let width: CGFloat
    }

    // Placeholder item metrics for drag/drop preview
    func placeholderCenter(for startDate: Date, duration: TimeInterval) -> (centerX: CGFloat, centerY: CGFloat, height: CGFloat) {
        let height = metrics.height(forDuration: duration)
        let centerY = metrics.yOffset(for: startDate) + height / 2
        return (metrics.centerX, centerY, height)
    }

    // Positioned block parameters for a normal item
    func positionedBlock(for item: DisplayableCalendarItem) -> (centerX: CGFloat, centerY: CGFloat, height: CGFloat, width: CGFloat) {
        // Use hour fraction and durationHours provided by DisplayableCalendarItem to avoid optional dates
        let topOffset = metrics.yOffset(forHourFraction: item.startHour) + (item.isEvent ? 1 : 0)
        let height = max(10, item.durationHours * metrics.hourHeight - 2)
        let centerY = topOffset + height / 2
        return (metrics.centerX, centerY, height, metrics.contentWidth)
    }

    /// Calculates horizontal layout positions and widths for a set of items, handling overlaps.
    func calculateLayout(for items: [DisplayableCalendarItem]) -> [String: PositionedBlock] {
        guard !items.isEmpty else { return [:] }

        // 1. Sort items by startHour ascending
        let sortedItems = items.sorted { $0.startHour < $1.startHour }

        // 2. Group overlapping items into clusters
        var clusters: [[DisplayableCalendarItem]] = []
        for item in sortedItems {
            if let lastCluster = clusters.last,
               let lastItem = lastCluster.max(by: { ($0.startHour + $0.durationHours) < ($1.startHour + $1.durationHours) }) {
                let maxEndHour = lastItem.startHour + lastItem.durationHours
                if item.startHour < maxEndHour {
                    // Overlaps with the current cluster
                    clusters[clusters.count - 1].append(item)
                } else {
                    // Starts a new cluster
                    clusters.append([item])
                }
            } else {
                clusters.append([item])
            }
        }

        var layoutMap: [String: PositionedBlock] = [:]

        // 3. Process each cluster to determine columns
        for cluster in clusters {
            var columns: [[DisplayableCalendarItem]] = []
            var itemToColumnIndex: [String: Int] = [:]

            for item in cluster {
                var placed = false
                for (colIndex, colItems) in columns.enumerated() {
                    if let lastItemInCol = colItems.last {
                        let endHour = lastItemInCol.startHour + lastItemInCol.durationHours
                        if item.startHour >= endHour {
                            columns[colIndex].append(item)
                            itemToColumnIndex[item.id] = colIndex
                            placed = true
                            break
                        }
                    }
                }
                if !placed {
                    columns.append([item])
                    itemToColumnIndex[item.id] = columns.count - 1
                }
            }

            let totalColumns = columns.count

            // 4. Calculate colspan and layout coordinates for each item in the cluster
            for item in cluster {
                guard let colIndex = itemToColumnIndex[item.id] else { continue }
                
                var colspan = 1
                while colIndex + colspan < totalColumns {
                    let targetColItems = columns[colIndex + colspan]
                    let overlaps = targetColItems.contains { other in
                        let itemEnd = item.startHour + item.durationHours
                        let otherEnd = other.startHour + other.durationHours
                        return item.startHour < otherEnd && other.startHour < itemEnd
                    }
                    if overlaps {
                        break
                    }
                    colspan += 1
                }

                let singleColWidth = metrics.contentWidth / CGFloat(totalColumns)
                let horizontalSpacing: CGFloat = totalColumns > 1 ? 1.0 : 0.0
                let itemWidth = max(5, singleColWidth * CGFloat(colspan) - horizontalSpacing)
                let leftOffset = metrics.leftPadding + CGFloat(colIndex) * singleColWidth
                let centerX = leftOffset + (itemWidth / 2)

                let topOffset = metrics.yOffset(forHourFraction: item.startHour) + (item.isEvent ? 1 : 0)
                let height = max(10, item.durationHours * metrics.hourHeight - 2)
                let centerY = topOffset + height / 2

                layoutMap[item.id] = PositionedBlock(
                    centerX: centerX,
                    centerY: centerY,
                    height: height,
                    width: itemWidth
                )
            }
        }

        return layoutMap
    }
}



