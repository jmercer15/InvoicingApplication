import SwiftUI
import Core
import EventKit
import AppKit // Added for NSWorkspace
import SharedUI
import Data

// ─────────────────────────────────────────────────────────────
// MARK: - Unified Calendar Item Block View
// ─────────────────────────────────────────────────────────────

enum CalendarColorProvider {
    private static let preferencesKey = "perCalendarPreferences"

    private struct StoredCalendarSettings: Codable {
        let colorHex: String?
        let isMonitored: Bool?
        let customSyncDirection: String?
    }

    static func color(for calendarIdentifier: String) -> Color? {
        guard !calendarIdentifier.isEmpty,
              let raw = UserDefaults.standard.string(forKey: preferencesKey),
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: StoredCalendarSettings].self, from: data),
              let settings = decoded[calendarIdentifier],
              let hex = settings.colorHex, !hex.isEmpty else {
            return nil
        }
        return Color(hex: hex)
    }
}

struct CalendarItemBlockView: View {
    private static let leadingColumnPadding: CGFloat = 1
    private static let trailingColumnPadding: CGFloat = 3
    let item: DisplayableCalendarItem
    @ObservedObject var viewModel: CalendarViewModel
    let hourHeight: CGFloat
    let columnWidth: CGFloat
    @State private var isHovered = false

    // --- Use computed properties from DisplayableCalendarItem ---
    private var statusColor: Color { item.displayColor }
    private var clientColor: Color {
        switch item {
        case .session(let session):
            // For sessions, use client color if available
            if let clientId = session.clientId {
                return ColorSystem.Client.color(for: clientId)
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
            if let clientId = session.clientId {
                return ColorSystem.Client.color(for: clientId)
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
        CalendarColorProvider.color(for: calendarId)
    }
    private var cardColor: Color {
        switch item {
        case .session, .recurringSessionInstance:
            // For sessions, use client color if available, otherwise use status color
            if let session = item.underlyingSession, let clientId = session.clientId {
                return ColorSystem.Client.color(for: clientId)
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
    private var cardHeight: CGFloat { max(10, durationHours * hourHeight - 2) }
    private var showTimeLine: Bool { cardHeight >= 20 }
    private var showPrimaryDetailLine: Bool { cardHeight >= 34 }
    private var showSecondaryDetailLine: Bool { cardHeight >= 52 }
    private var showTertiaryDetailLine: Bool { cardHeight >= 72 }
    private var contentTextColor: Color { Color("Text", bundle: .sharedUI) }

    // --- Type-specific computed properties ---
    private var isSession: Bool { item.isSession }
    private var isEvent: Bool { item.isEvent }

    // Adapt status/state properties based on item type
    private var sessionStatusToken: String? {
        SessionStatus(normalized: item.underlyingSession?.status ?? "")?.token
    }
    private var isCompleted: Bool { 
        item.isSession && sessionStatusToken == SessionStatus.completed.token
    }
    private var isCancelled: Bool { 
        item.isSession && sessionStatusToken == SessionStatus.cancelled.token
    }
    private var isPast: Bool { (item.endDate ?? .distantFuture) < Date() } // Common check
    private var isConfirmed: Bool { 
        item.isSession && sessionStatusToken == SessionStatus.scheduled.token
    }
    private var isPending: Bool { 
        item.isSession && sessionStatusToken == SessionStatus.scheduled.token
    }

    // Adapt background opacity based on type and state
    private var backgroundOpacity: Double {
        if isEvent { return 0.36 }
        if isCompleted { return 0.36 }
        if isCancelled { return 0.34 }
        if isPast { return 0.32 }
        if isConfirmed { return 0.42 }
        if isPending { return 0.40 }
        return 0.42 // Default for sessions
    }

    // Define SessionStatus enum locally for context menu actions

    @EnvironmentObject var eventKitService: EventKitSyncService

    private var isBeingResized: Bool {
        viewModel.interactionHandler.resizingSessionInfo?.instanceID == item.id
    }

    private var shouldShowResizeControls: Bool {
        !isEvent && (isHovered || isBeingResized)
    }

    var body: some View {
        let calculatedWidth = max(0, columnWidth - Self.leadingColumnPadding - Self.trailingColumnPadding)
        let (calculatedHeight, _) = calculateHeightAndOffset(isBeingResized: isBeingResized)
        
        ZStack(alignment: .top) {
            // Main content of the block
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall, style: .continuous)
                    .fill(cardColor.opacity(backgroundOpacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall, style: .continuous)
                            .stroke(cardColor.opacity(0.78), lineWidth: 0.8)
                    )
                    .overlay(alignment: .topLeading) {
                        contentVStack()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
            }


            // Resize handles overlay
            VStack {
                ResizeHandleView(
                    edge: .top,
                    item: item,
                    viewModel: viewModel,
                    hourHeight: hourHeight
                )
                Spacer()
                ResizeHandleView(
                    edge: .bottom,
                    item: item,
                    viewModel: viewModel,
                    hourHeight: hourHeight
                )
            }
            .padding(.vertical, -5) // Pulls the handles outward by 5pt each, centering them on the edge.
            .allowsHitTesting(shouldShowResizeControls)
            .opacity(shouldShowResizeControls ? 1 : 0)
        }
        .frame(width: calculatedWidth, height: calculatedHeight)
        .shadow(
            color: Color.black.opacity(isBeingResized ? 0.3 : 0.1),
            radius: isBeingResized ? 8 : 3,
            x: 0,
            y: isBeingResized ? 4 : 2
        )
        .opacity(isCancelled ? 0.7 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isBeingResized)
        .zIndex(isBeingResized ? 10 : (isEvent ? 2 : 1))
        .contentShape(Rectangle())
        .pointerStyle(.link)
        .contextMenu { makeContextMenu() }
        .onTapGesture { handleTap() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }

        .onDrag {
            guard !isBeingResized,
                  let session = item.underlyingSession,
                  let startDate = item.startDate
            else { return NSItemProvider() }
            let sessionID = session.id
            let duration = session.endTime?.timeIntervalSince(session.startTime ?? Date()) ?? 3600
            viewModel.interactionHandler.draggingSessionInfo = (sessionID: sessionID.uuidString, duration: duration, originalInstanceDate: startDate)
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
            viewModel.selectedSessionInfo = (session: session, instanceStart: session.startTime, instanceEnd: session.endTime)
        case .recurringSessionInstance(let template, let instanceStartDate, let instanceEndDate, _):
            // It's a recurring instance, show the editor for this specific instance.
            viewModel.selectedSessionInfo = (session: template, instanceStart: instanceStartDate, instanceEnd: instanceEndDate)
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
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .top, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(contentTextColor)
                    .lineLimit(showSecondaryDetailLine ? 2 : 1)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 2)
                
                // Status indicator badge for sessions
                if let session = item.underlyingSession {
                    statusBadge(for: session)
                }

                // Keep the resize affordance for sessions without stealing much space.
                if shouldShowResizeControls {
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(contentTextColor)
                        .opacity(StyleGuide.Opacity.strong)
                }
            }

            if showTimeLine {
                compactMetaRow(icon: "clock", text: timeRangeText)
            }

            if let session = item.underlyingSession {
                if showPrimaryDetailLine, let clientId = session.clientId {
                    ClientNameView(
                        clientId: clientId,
                        viewModel: viewModel,
                        fontSize: 9,
                        textColor: contentTextColor
                    )
                }

                if showSecondaryDetailLine, let serviceId = session.clientServiceId {
                    ServiceNameView(
                        serviceId: serviceId,
                        viewModel: viewModel,
                        fontSize: 9,
                        textColor: contentTextColor
                    )
                }

                if showTertiaryDetailLine, let location = session.location, !location.isEmpty {
                    compactMetaRow(icon: "mappin.and.ellipse", text: location, allowsTruncation: false)
                }
            } else if let event = item.underlyingEvent {
                if showPrimaryDetailLine {
                    compactMetaRow(icon: "calendar", text: event.calendar.title)
                }

                if showSecondaryDetailLine, let location = event.location, !location.isEmpty {
                    compactMetaRow(icon: "mappin.and.ellipse", text: location, allowsTruncation: false)
                }
            }
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingSmall + 1)
        .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
    }

    @ViewBuilder
    private func compactMetaRow(icon: String, text: String, allowsTruncation: Bool = true) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(contentTextColor)
            Text(text)
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(contentTextColor)
                .lineLimit(allowsTruncation ? 1 : nil)
                .fixedSize(horizontal: false, vertical: !allowsTruncation)
                .multilineTextAlignment(.leading)
        }
    }
    
    @ViewBuilder
    private func statusBadge(for session: Session) -> some View {
        let statusToken = SessionStatus(normalized: session.status ?? "")?.token
        
        if let token = statusToken {
            let (icon, badgeColor): (String, Color) = {
                switch token {
                case SessionStatus.completed.token:
                    return ("checkmark.circle.fill", .green)
                case SessionStatus.cancelled.token:
                    return ("xmark.circle.fill", .red)
                case SessionStatus.scheduled.token:
                    return ("calendar.circle.fill", .blue)
                case SessionStatus.noShow.token:
                    return ("exclamationmark.circle.fill", .orange)
                default:
                    return ("", .clear)
                }
            }()
            
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(badgeColor)
            }
        }
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
            Button("View Details") {
                // Navigation logic
            }

            let statusToken = SessionStatus(normalized: session.status ?? "")?.token
            let canEditCalendarStatus = isCalendarLifecycleStatus(statusToken)

            if canEditCalendarStatus {
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
                    Button(action: { markSessionAs(.scheduled, session: session) }) {
                        Label("Mark as Planned", systemImage: "calendar")
                    }
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
            // Delete via repository (TravelChargeView now accepts Session domain models)
            Button(role: .destructive, action: {
                Task {
                    do {
                        try await viewModel.sessionsRepository.delete(id: session.id)
                        await MainActor.run {
                            viewModel.updateDisplayableItems()
                        }
                    } catch {
                        print("[CalendarItemBlockView] Failed to delete session: \(error.localizedDescription)")
                    }
                }
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

    private func markSessionAs(_ status: SessionStatus, session: Session) {
        guard isCalendarLifecycleStatus(SessionStatus(normalized: session.status ?? "")?.token) else {
            return
        }
        let newStatus = status.token
        
        // Update session status via repository
        Task {
            do {
                try await viewModel.sessionsRepository.updateStatus(id: session.id, status: newStatus)
                await MainActor.run {
                    viewModel.updateDisplayableItems()
                }
            } catch {
                print("[CalendarItemBlockView] Failed to update session status: \(error.localizedDescription)")
            }
        }
    }

    private func isCalendarLifecycleStatus(_ token: String?) -> Bool {
        switch token {
        case "scheduled", "completed", "cancelled", "no_show", "rescheduled":
            return true
        default:
            return false
        }
    }

    // MARK: - Content Detail Builders

    @ViewBuilder
    private func makeItemHeader() -> some View {
        HStack {
            if isEvent {
                 Image(systemName: "calendar").font(.caption).foregroundColor(Color("Text", bundle: .sharedUI))
            }
            Text(item.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color("Text", bundle: .sharedUI))
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
                .foregroundColor(Color("Text", bundle: .sharedUI))
            Text(timeRangeText)
                .font(.system(size: 11))
                .foregroundColor(Color("Text", bundle: .sharedUI))
        }
    }

    @ViewBuilder
    private func makeClientInfo() -> some View {
        if let session = item.underlyingSession, let clientId = session.clientId {
            ClientNameView(
                clientId: clientId,
                viewModel: viewModel,
                textColor: contentTextColor
            )
        }
    }

    @ViewBuilder
    private func makeServiceInfo() -> some View {
        if let session = item.underlyingSession, let serviceId = session.clientServiceId {
            ServiceNameView(
                serviceId: serviceId,
                viewModel: viewModel,
                textColor: contentTextColor
            )
        }
    }

    @ViewBuilder
    private func makeLocationInfo() -> some View {
        if let session = item.underlyingSession, let location = session.location, !location.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 10))
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                Text(location)
                    .font(.system(size: 11))
                    .foregroundColor(Color("Text", bundle: .sharedUI))
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
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    Text(calendarName)
                        .font(.system(size: 11))
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .lineLimit(1)
                }
                
                // Google Calendar color info - show if available
                if let colorId = GoogleCalendarColors.getGoogleEventColorId(event),
                   let _ = GoogleCalendarColors.googleColorMap[colorId],
                   let colorName = GoogleCalendarColors.standard.first(where: { $0.id == colorId })?.name {
                    
                    HStack(spacing: 4) {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        Text(colorName)
                            .font(.system(size: 11))
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

// MARK: - Resize Handle View

struct ResizeHandleView: View {
    let edge: CalendarInteractionHandler.ResizeEdge
    let item: DisplayableCalendarItem
    @ObservedObject var viewModel: CalendarViewModel
    let hourHeight: CGFloat


    private var isActive: Bool {
        viewModel.interactionHandler.resizingSessionInfo?.instanceID == item.id && viewModel.interactionHandler.resizingSessionInfo?.edge == edge
    }

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if viewModel.interactionHandler.resizingSessionInfo == nil {
                    guard let session = item.underlyingSession,
                          let instanceStartTime = item.startDate,
                          let instanceEndTime = item.endDate
                    else { return }
                    
                    let instanceID = item.id // This is non-optional
                    
                    viewModel.interactionHandler.resizingSessionInfo = (instanceID: instanceID, masterSessionID: session.id.uuidString, edge: edge, initialStartTime: instanceStartTime, initialEndTime: instanceEndTime)
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
                    viewModel.interactionHandler.resizePreviewDate = finalDate
                }
            }
            .onEnded { value in
                guard let info = viewModel.interactionHandler.resizingSessionInfo, let finalDate = viewModel.interactionHandler.resizePreviewDate else {
                    viewModel.interactionHandler.resizingSessionInfo = nil
                    viewModel.interactionHandler.resizePreviewDate = nil
                    return
                }

                let timeDelta: TimeInterval
                if edge == .top {
                    timeDelta = finalDate.timeIntervalSince(info.initialStartTime)
                } else { // .bottom
                    timeDelta = finalDate.timeIntervalSince(info.initialEndTime)
                }

                if let sessionID = UUID(uuidString: info.masterSessionID) {
                    viewModel.resizeSession(
                        with: sessionID,
                        originalInstanceDate: item.startDate ?? Date(),
                        edge: edge,
                        timeDelta: timeDelta
                    )
                }
                
                viewModel.interactionHandler.resizingSessionInfo = nil
                viewModel.interactionHandler.resizePreviewDate = nil
            }
    }

    var body: some View {
        ZStack {
            // Main handle visible part
            Capsule()
                .fill(isActive ? Color.accentColor : Color.white.opacity(0.9))
                .frame(width: isActive ? 44 : 34, height: isActive ? 8 : 6)
                .allowsHitTesting(false) // The visible capsule is purely decorative

            // The gesture area
            Color.clear
                .contentShape(Rectangle())
                .gesture(gesture)
                .pointerStyle(.rowResize)

            // Live time preview text
            if isActive, let time = viewModel.interactionHandler.resizePreviewDate {
                Text(viewModel.formatTime(time))
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, StyleGuide.Dimensions.paddingXSmall)
                    .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                    .background(Color.accentColor)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                    .offset(y: edge == .top ? -20 : 20)
                    .zIndex(1)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 12)
        .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: isActive)
    }
}
