import Foundation
import SwiftUI

@MainActor
final class CalendarInteractionHandler: ObservableObject {
    enum ResizeEdge { case top, bottom }

    // Dragging
    @Published var draggingSessionInfo: (sessionID: String, duration: TimeInterval, originalInstanceDate: Date)?
    @Published var dropTargetTime: Date?

    // Resizing
    @Published var resizingSessionInfo: (instanceID: String, masterSessionID: String, edge: ResizeEdge, initialStartTime: Date, initialEndTime: Date)?
    @Published var resizePreviewDate: Date?

    func startDragging(sessionID: String, duration: TimeInterval, originalInstanceDate: Date) {
        draggingSessionInfo = (sessionID, duration, originalInstanceDate)
    }

    func endDragging() {
        draggingSessionInfo = nil
        dropTargetTime = nil
    }

    func setDropTarget(_ date: Date?) {
        dropTargetTime = date
    }

    func beginResize(instanceID: String, masterSessionID: String, edge: ResizeEdge, initialStartTime: Date, initialEndTime: Date) {
        resizingSessionInfo = (instanceID, masterSessionID, edge, initialStartTime, initialEndTime)
    }

    func updateResizePreview(_ date: Date?) {
        resizePreviewDate = date
    }

    func endResize() {
        resizingSessionInfo = nil
        resizePreviewDate = nil
    }
}


