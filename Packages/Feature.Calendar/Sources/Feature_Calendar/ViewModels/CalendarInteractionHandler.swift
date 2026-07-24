import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class CalendarInteractionHandler {
    enum ResizeEdge { case top, bottom }

    // Dragging
    var draggingSessionInfo: (sessionID: String, duration: TimeInterval, originalInstanceDate: Date)?
    var dropTargetTime: Date?

    // Resizing
    var resizingSessionInfo: (instanceID: String, masterSessionID: String, edge: ResizeEdge, initialStartTime: Date, initialEndTime: Date)?
    var resizePreviewDate: Date?

    func startDragging(sessionID: String, duration: TimeInterval, originalInstanceDate: Date) {
        draggingSessionInfo = (sessionID, duration, originalInstanceDate)
    }
}
