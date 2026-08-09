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

}


