import SwiftUI

import EventKit
import AppKit // Added for NSWorkspace

// ─────────────────────────────────────────────────────────────
// MARK: - Unified Calendar Item Block View
// ─────────────────────────────────────────────────────────────

struct CalendarItemBlockView: View {
    let item: DisplayableCalendarItem
    @ObservedObject var viewModel: CalendarViewModel
    let hourHeight: CGFloat
    let columnWidth: CGFloat

    // --- Use computed properties from DisplayableCalendarItem ---
    private var statusColor: Color { item.displayColor }
    private var clientColor: Color {
        switch item {
        case .session(let session):
            // For sessions, use client color if available
            if let client = session.client {
                return Color(hex: client.colorHex)
            }
            return item.displayColor
        case .event(let event):
            // For events, use custom calendar color if set, otherwise use the event's calendar color
            let calendarId = event.calendar.calendarIdentifier
            if let customColor = getCustomCalendarColor(calendarId: calendarId) {
                return customColor
            }
            return Color(event.calendar.cgColor)
        case .recurringSessionInstance(let session, _, _, _):
            // For recurring sessions, use client color if available
            if let client = session.client {
                return Color(hex: client.colorHex)
            }
            return item.displayColor
        case .eventSegment(let originalEvent, _, _, _):
            // For event segments, use custom calendar color if set, otherwise use the original event's calendar color
            let calendarId = originalEvent.calendar.calendarIdentifier
            if let customColor = getCustomCalendarColor(calendarId: calendarId) {
                return customColor
            }
            return Color(originalEvent.calendar.cgColor)
        }
    }
    
    private func getCustomCalendarColor(calendarId: String) -> Color? {
        // Access the preferences through the view model
        let preferences = CalendarPreferences()
        guard let calendarSettings = preferences.perCalendarPreferences[calendarId],
              let hexString = calendarSettings.colorHex else {
            return nil
        }
        return Color(hex: hexString)
    }
    private var cardColor: Color {
        switch item {
        case .session, .recurringSessionInstance:
            // For sessions, use client color if available, otherwise use status color
            if let session = item.underlyingSession, let client = session.client {
                return Color(hex: client.colorHex)
            }
            return statusColor
        case .event, .eventSegment:
            // For events, use the event's calendar color or status color
            return statusColor
        }
    }
    private var startHour: CGFloat { item.startHour }
    private var durationHours: CGFloat { item.durationHours }
    private var timeRangeText: String {
        guard let startTime = item.startDate, let endTime = item.endDate else { return "Unknown time" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "\(f.string(from: startTime)) - \(f.string(from: endTime))"
    }

    // --- Type-specific computed properties ---
    private var isSession: Bool { item.isSession }
    private var isEvent: Bool { item.isEvent }

    // Adapt status/state properties based on item type
    private var isCompleted: Bool { item.isSession && item.underlyingSession?.status == String.sessionStatusCompleted }
    private var isCancelled: Bool { item.isSession && item.underlyingSession?.status == String.sessionStatusCancelled }
    private var isPast: Bool { (item.endDate ?? .distantFuture) < Date() } // Common check
    private var isConfirmed: Bool { item.isSession && item.underlyingSession?.status == String.sessionStatusConfirmed }
    private var isPending: Bool { item.isSession && item.underlyingSession?.status == String.sessionStatusPlanned }

    // Adapt background opacity based on type and state
    private var backgroundOpacity: Double {
        if isEvent { return 0.15 }
        if isCompleted { return 0.15 }
        if isCancelled { return 0.12 }
        if isPast { return 0.1 }
        if isConfirmed { return 0.2 }
        if isPending { return 0.18 }
        return 0.2 // Default for sessions
    }

    @State private var isHovering = false
    @State private var isTopHandleHovered = false
    @State private var isBottomHandleHovered = false

    // Define SessionStatus enum locally for context menu actions
    private enum SessionStatus: String {
        case planned = "Planned"
        case completed = "Completed"
        case cancelled = "Cancelled"
    }

    @EnvironmentObject var eventKitService: EventKitSyncService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let isBeingResized = viewModel.resizingSessionInfo?.instanceID == item.id
        let calculatedWidth = columnWidth - 10
        let (calculatedHeight, _) = calculateHeightAndOffset(isBeingResized: isBeingResized)

        // Track if any handle is being hovered for UI feedback
        let _ = isTopHandleHovered || isBottomHandleHovered
        
        ZStack(alignment: .top) {
            // Main content of the block
            VStack(alignment: .leading, spacing: 0) {
                RightRoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        RightRoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RightRoundedRectangle(cornerRadius: 8)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.25)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        // Diagonal Linear Gradient
                        RightRoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        clientColor.opacity(0.7),
                                        clientColor.opacity(0.6),
                                        clientColor.opacity(0.5),
                                        clientColor.opacity(0.4),
                                        clientColor.opacity(0.35),
                                        clientColor.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        // Dynamic Edge Highlight Effect
                        RightRoundedRectangle(cornerRadius: 8)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        clientColor.opacity(0.8),
                                        clientColor.opacity(0.6),
                                        clientColor.opacity(0.4),
                                        clientColor.opacity(0.2),
                                        clientColor.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .overlay { contentVStack() }
            }
            .appInteractiveCursor()

            // Resize handles overlay
            VStack {
                ResizeHandleView(
                    edge: .top,
                    item: item,
                    viewModel: viewModel,
                    hourHeight: hourHeight,
                    isHandleHovered: $isTopHandleHovered
                )
                Spacer()
                ResizeHandleView(
                    edge: .bottom,
                    item: item,
                    viewModel: viewModel,
                    hourHeight: hourHeight,
                    isHandleHovered: $isBottomHandleHovered
                )
            }
            .padding(.vertical, -5) // Pulls the handles outward by 5pt each, centering them on the edge.
            .allowsHitTesting(isHovering && !isEvent) // Make handles hittable only when card is hovered
            .opacity(isHovering && !isEvent ? 1 : 0) // Only show on hover and for sessions
        }
        .frame(width: calculatedWidth, height: calculatedHeight)
        .shadow(
            color: Color.black.opacity(isHovering || isBeingResized ? 0.3 : 0.1),
            radius: isHovering || isBeingResized ? 8 : 3,
            x: 0,
            y: isHovering || isBeingResized ? 4 : 2
        )
        .opacity(isCancelled ? 0.7 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovering || isBeingResized)
        .zIndex(isHovering || isBeingResized ? 10 : (isEvent ? 2 : 1))
        .contextMenu { makeContextMenu() }
        .onTapGesture { handleTap() }
        .onHover { hovering in
            isHovering = hovering
        }
        .onDrag {
            guard !isBeingResized,
                  let session = item.underlyingSession,
                  let startDate = item.startDate
            else { return NSItemProvider() }
            let sessionID = session.id
            let duration = session.endTime?.timeIntervalSince(session.startTime ?? Date()) ?? 3600
            viewModel.draggingSessionInfo = (sessionID: sessionID.uuidString, duration: duration, originalInstanceDate: startDate)
            return NSItemProvider(object: sessionID.uuidString as NSString)
        } preview: {
            Color.clear
        }
    }
    
    private func calculateHeightAndOffset(isBeingResized: Bool) -> (height: CGFloat, yOffset: CGFloat) {
        let originalHeight = max(10, durationHours * hourHeight - 2)
        let originalYOffset = startHour * hourHeight
        
        // Return the original, calculated values. Do not show live resizing on the card itself.
        // The red preview line is the only visual indicator during the drag.
        return (originalHeight, originalYOffset)
    }

    private func handleTap() {
        switch item {
        case .session(let session):
            // It's a non-recurring session, show the editor directly.
            // Reset selection first to ensure onChange triggers even for same session
            viewModel.selectedSessionInfo = nil
            DispatchQueue.main.async {
                viewModel.selectedSessionInfo = (session: session, instanceStart: session.startTime, instanceEnd: session.endTime)
            }
        case .recurringSessionInstance(let template, let instanceStartDate, let instanceEndDate, _):
            // It's a recurring instance, show the editor for this specific instance.
            // Reset selection first to ensure onChange triggers even for same session
            viewModel.selectedSessionInfo = nil
            DispatchQueue.main.async {
                viewModel.selectedSessionInfo = (session: template, instanceStart: instanceStartDate, instanceEnd: instanceEndDate)
            }
        case .event(let event):
            // It's an EKEvent, trigger the conversion flow.
            viewModel.convertEventToSession(event)
        case .eventSegment(let originalEvent, _, _, _):
            viewModel.convertEventToSession(originalEvent)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func contentVStack() -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if !isEvent {
                        Text(timeRangeText)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Add resize indicator for sessions
                if !isEvent {
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .opacity(isHovering ? 1.0 : 0.3)
                        .animation(.easeInOut(duration: 0.2), value: isHovering)
                }
            }
            
            if let client = item.underlyingSession?.client {
                Text(client.fullName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }



    // MARK: - Context Menu Builder
    @ViewBuilder
    private func makeContextMenu() -> some View {
        switch item {
        case .session(let session), .recurringSessionInstance(let session, _, _, _):
            // --- Edit Button ---
            Button(action: { handleTap() }) {
                Label("View Details", systemImage: "info.circle")
            }
            
            Divider()
            
            // Navigation options using the navigation components
            EntityNavigationContextMenu(entity: .session(
                id: session.id,
                title: session.title,
                date: session.startTime,
                clientID: session.client?.id
            ))

            if !isCompleted && !isCancelled {
                Divider()
                Button(action: { markSessionAs(.completed, session: session) }) {
                    Label("Mark as Completed", systemImage: "checkmark.circle.fill")
                }
                Button(action: { markSessionAs(.cancelled, session: session) }) {
                    Label("Mark as Cancelled", systemImage: "xmark.circle.fill")
                }
            }

            if isCompleted || isCancelled {
                Divider()
                Button(action: { markSessionAs(.planned, session: session) }) {
                    Label("Mark as Planned", systemImage: "calendar")
                }
            }

            Divider()

            Button(action: { viewModel.duplicateSession(session) }) {
                Label("Duplicate Session", systemImage: "plus.square.on.square.fill")
            }
            
            if !session.isTravel {
            Button(action: { 
                viewModel.selectedSessionForTravel = session
                    viewModel.selectedInstanceStartDateForTravel = item.startDate ?? Date()
                    viewModel.selectedInstanceEndDateForTravel = item.endDate ?? Date()
                viewModel.isShowingTravelChargeSheet = true
            }) {
                Label("Add Travel Charges", systemImage: "car.fill")
                }
            }
             // --- Delete ---
            Button(role: .destructive, action: {
                viewModel.handleDeleteFromEditor(
                    with: .thisOnly,
                    viewModel: NewSessionViewModel(
                        context: modelContext,
                        session: session,
                        instanceDate: nil
                    )
                )
            }) {
                Label("Delete Session...", systemImage: "trash.fill")
            }

        case .event(let event):
            // --- Convert Event Button ---
            Button(action: {
                viewModel.convertEventToSession(event)
            }) {
                Label("Convert to Session", systemImage: "arrow.right.circle.fill")
        }
        case .eventSegment(let originalEvent, _, _, _):
             Button(action: {
                viewModel.convertEventToSession(originalEvent)
            }) {
                Label("Convert to Session", systemImage: "arrow.right.circle.fill")
            }
        }
    }

    // MARK: - Action Handlers

    private func markSessionAs(_ status: SessionStatus, session: SessionEntity) {
        let newStatus: String
        switch status {
        case .planned: newStatus = String.sessionStatusPlanned
        case .completed: newStatus = String.sessionStatusCompleted
        case .cancelled: newStatus = String.sessionStatusCancelled
        }
        
        session.status = newStatus
        
        // No need for try-catch as saveContext() doesn't throw
        viewModel.saveContext()
        // The view will update via Combine publishers
    }

    // MARK: - Content Detail Builders

    @ViewBuilder
    private func makeItemHeader() -> some View {
        HStack {
            if isEvent {
                 Image(systemName: "calendar").font(.caption).foregroundColor(.white)
            }
            Text(item.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .italic(isEvent)
            Spacer()
        }
    }

    @ViewBuilder
    private func makeTimeInfo() -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.system(size: 10))
                .foregroundColor(.white)
            Text(timeRangeText)
                .font(.system(size: 11))
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private func makeClientInfo() -> some View {
        if let session = item.underlyingSession, let client = session.client {
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                Text(client.fullName)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func makeServiceInfo() -> some View {
        if let session = item.underlyingSession, let clientService = session.clientService {
            HStack(spacing: 4) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                Text(clientService.serviceName)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func makeLocationInfo() -> some View {
        if let session = item.underlyingSession, let location = session.location, !location.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                Text(location)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func makeCalendarInfo() -> some View {
        if case .event(let event) = item {
            let calendarName = event.calendar.title
            
            VStack(alignment: .leading, spacing: 4) {
                // Calendar source info
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                    Text(calendarName)
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                // Google Calendar color info - show if available
                if let colorId = GoogleCalendarColors.getGoogleEventColorId(event),
                   let _ = GoogleCalendarColors.googleColorMap[colorId],
                   let colorName = GoogleCalendarColors.standard.first(where: { $0.id == colorId })?.name {
                    
                    HStack(spacing: 4) {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                        Text(colorName)
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

// MARK: - Resize Handle View

struct ResizeHandleView: View {
    let edge: CalendarViewModel.ResizeEdge
    let item: DisplayableCalendarItem
    @ObservedObject var viewModel: CalendarViewModel
    let hourHeight: CGFloat
    @Binding var isHandleHovered: Bool
    @State private var isHovering = false
    @Environment(\.modelContext) private var modelContext

    private var isActive: Bool {
        viewModel.resizingSessionInfo?.instanceID == item.id && viewModel.resizingSessionInfo?.edge == edge
    }

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if viewModel.resizingSessionInfo == nil {
                    guard let session = item.underlyingSession,
                          let instanceStartTime = item.startDate,
                          let instanceEndTime = item.endDate
                    else { return }
                    
                    let instanceID = item.id // This is non-optional
                    
                    viewModel.resizingSessionInfo = (instanceID: instanceID, masterSessionID: session.id.uuidString, edge: edge, initialStartTime: instanceStartTime, initialEndTime: instanceEndTime)
                }
                
                let verticalTranslation = value.translation.height
                let timeDifference = (verticalTranslation / hourHeight) * 3600 // In seconds
                
                let initialDate = (edge == .top) ? (item.startDate ?? Date()) : (item.endDate ?? Date())
                let newDate = initialDate.addingTimeInterval(timeDifference)
                
                let calendar = Calendar.current
                let components = calendar.dateComponents([.minute], from: newDate)
                let minutes = components.minute ?? 0
                let snappedMinutes = (Double(minutes) / 5.0).rounded() * 5.0
                
                var finalDateComponents = calendar.dateComponents([.year, .month, .day, .hour], from: newDate)
                finalDateComponents.minute = Int(snappedMinutes)
                
                if let finalDate = calendar.date(from: finalDateComponents) {
                    viewModel.resizePreviewDate = finalDate
                }
            }
            .onEnded { value in
                guard let info = viewModel.resizingSessionInfo, let finalDate = viewModel.resizePreviewDate else {
                    viewModel.resizingSessionInfo = nil
                    viewModel.resizePreviewDate = nil
                    return
                }

                let timeDelta: TimeInterval
                if edge == .top {
                    timeDelta = finalDate.timeIntervalSince(info.initialStartTime)
                } else { // .bottom
                    timeDelta = finalDate.timeIntervalSince(info.initialEndTime)
                }

                viewModel.resizeSession(
                    with: info.masterSessionID,
                    originalInstanceDate: item.startDate ?? Date(),
                    edge: edge,
                    timeDelta: timeDelta
                )
                
                viewModel.resizingSessionInfo = nil
                viewModel.resizePreviewDate = nil
            }
    }

    var body: some View {
        ZStack {
            // Main handle visible part
            Capsule()
                .fill(isActive ? Color.accentColor : (isHovering ? Color.white : Color.white.opacity(0.9)))
                .frame(width: isActive ? 44 : 34, height: isActive ? 8 : 6)
                .allowsHitTesting(false) // The visible capsule is purely decorative

            // The gesture area
            Color.clear
                .contentShape(Rectangle())
                .gesture(gesture)
                .pointerStyle(.rowResize)
                .onHover { hovering in
                    isHandleHovered = hovering
                }

            // Live time preview text
            if isActive, let time = viewModel.resizePreviewDate {
                Text(viewModel.formatTime(for: time))
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .offset(y: edge == .top ? -20 : 20)
                    .zIndex(1)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 12)
        .animation(.easeInOut(duration: 0.1), value: isActive)
    }
}

// MARK: - Custom Shape Definition

struct RightRoundedRectangle: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Start at top-left
        path.move(to: CGPoint(x: 0, y: 0))
        // Top edge
        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: 0))
        // Top-right corner
        path.addArc(center: CGPoint(x: rect.width - cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        // Right edge
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - cornerRadius))
        // Bottom-right corner
        path.addArc(center: CGPoint(x: rect.width - cornerRadius, y: rect.height - cornerRadius), radius: cornerRadius, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        // Bottom edge
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        // Close path
        path.closeSubpath()

        return path
    }
} 
