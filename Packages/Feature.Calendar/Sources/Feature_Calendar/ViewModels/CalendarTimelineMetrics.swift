import Foundation
import SwiftUI
import SharedUI

/// Encapsulates timeline math for calendar day columns.
/// Pure value type with helpers for y-offsets, sizes, and centers.
struct CalendarTimelineMetrics {
    let hourHeight: CGFloat
    let columnWidth: CGFloat

    // These replicate existing spacing used in DayColumnView to avoid visual changes
    let leftPadding: CGFloat
    let contentWidthSubtract: CGFloat

    init(hourHeight: CGFloat,
         columnWidth: CGFloat,
         leftPadding: CGFloat = 0,
         contentWidthSubtract: CGFloat = 2) {
        self.hourHeight = hourHeight
        self.columnWidth = columnWidth
        self.leftPadding = leftPadding
        self.contentWidthSubtract = contentWidthSubtract
    }

    // Y offset for a specific date within the day (uses hour + minute)
    func yOffset(for date: Date, calendar: Calendar = .current) -> CGFloat {
        let hour = CGFloat(calendar.component(.hour, from: date))
        let minute = CGFloat(calendar.component(.minute, from: date))
        let hourFraction = hour + (minute / 60.0)
        return hourFraction * hourHeight
    }

    // Y offset for a fractional hour value
    func yOffset(forHourFraction hourFraction: CGFloat) -> CGFloat {
        hourFraction * hourHeight
    }

    // Height for a duration in seconds
    func height(forDuration duration: TimeInterval) -> CGFloat {
        let hours = CGFloat(duration / 3600.0)
        // Keep the existing min height and 2pt subtraction used by the view
        return max(10, hours * hourHeight - 2)
    }

    // Width used for an item inside the column based on current padding rules
    var contentWidth: CGFloat { max(0, columnWidth - contentWidthSubtract) }

    // Horizontal center used by positioned blocks
    var centerX: CGFloat { leftPadding + (contentWidth / 2) }
}
