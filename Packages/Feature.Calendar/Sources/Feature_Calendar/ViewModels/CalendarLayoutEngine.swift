import Foundation
import SwiftUI

/// Stateless engine responsible for transforming calendar data into layout positions.
struct CalendarLayoutEngine {
    let metrics: CalendarTimelineMetrics

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
}


