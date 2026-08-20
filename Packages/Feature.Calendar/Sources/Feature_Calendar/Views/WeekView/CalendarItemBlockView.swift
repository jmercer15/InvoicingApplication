import SwiftUI
import Core
import PersistenceModels
import EventKit
import AppKit // Added for NSWorkspace
import SharedUI
import Observation
import UniformTypeIdentifiers

// ─────────────────────────────────────────────────────────────
// MARK: - Unified Calendar Item Block View
// ─────────────────────────────────────────────────────────────

import Foundation

@MainActor
enum CalendarColorProvider {
    private static let preferencesKey = "perCalendarPreferences"
    private static var cachedPreferences: [String: StoredCalendarSettings]?
    private static var isObserving = false

    private struct StoredCalendarSettings: Codable {
        let colorHex: String?
        let isMonitored: Bool?
        let customSyncDirection: String?
    }

    private static func invalidateCache() {
        cachedPreferences = nil
    }

    static func color(for calendarIdentifier: String) -> Color? {
        guard !calendarIdentifier.isEmpty else { return nil }

        if !isObserving {
            NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    invalidateCache()
                }
            }
            isObserving = true
        }

        let preferences: [String: StoredCalendarSettings]
        if let cached = cachedPreferences {
            preferences = cached
        } else {
            let raw = UserDefaults.standard.string(forKey: preferencesKey) ?? "{}"
            guard let data = raw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String: StoredCalendarSettings].self, from: data) else {
                return nil
            }
            cachedPreferences = decoded
            preferences = decoded
        }

        guard let settings = preferences[calendarIdentifier],
              let hex = settings.colorHex, !hex.isEmpty else {
            return nil
        }
        return Color(legacyHex: hex)
    }
}

struct CalendarItemBlockEquatableState: Equatable, Sendable {
    let itemID: String
    let title: String
    let actualStartDate: Date?
    let actualEndDate: Date?
    let sessionStatusRaw: String?
    let clientId: UUID?
    let clientServiceId: UUID?
    let location: String?
    let googleColorId: String?
    let hasInvoice: Bool
    let eventLocation: String?
    let isBulkSelectionMode: Bool
    let isItemSelected: Bool
    let isSelected: Bool
    let isBeingResized: Bool
    let hourHeight: CGFloat
    let slotWidth: CGFloat

    @MainActor
    static func make(
        item: DisplayableCalendarItem,
        viewModel: CalendarViewModel,
        interactionHandler: CalendarInteractionHandler,
        hourHeight: CGFloat,
        slotWidth: CGFloat
    ) -> CalendarItemBlockEquatableState {
        let session = item.underlyingSession
        let selectedSession = viewModel.selectedSessionInfo?.session
        let selectedSessionID = selectedSession?.id
        let isSelected = {
            guard let session, let selectedSessionID else { return false }
            return selectedSessionID == session.id
        }()
        return CalendarItemBlockEquatableState(
            itemID: item.id,
            title: item.title,
            actualStartDate: item.actualStartDate,
            actualEndDate: item.actualEndDate,
            sessionStatusRaw: session?.status?.rawValue,
            clientId: session?.clientId,
            clientServiceId: session?.clientServiceId,
            location: session?.location,
            googleColorId: session?.googleColorId,
            hasInvoice: session?.invoice != nil,
            eventLocation: item.underlyingEvent?.location,
            isBulkSelectionMode: viewModel.isBulkSelectionMode,
            isItemSelected: viewModel.isItemSelected(item),
            isSelected: isSelected,
            isBeingResized: interactionHandler.resizingSessionInfo?.instanceID == item.id,
            hourHeight: hourHeight,
            slotWidth: slotWidth
        )
    }
}

struct CalendarItemBlockView: View, Equatable {
    nonisolated static func == (lhs: CalendarItemBlockView, rhs: CalendarItemBlockView) -> Bool {
        lhs.equatableState == rhs.equatableState
    }

    let equatableState: CalendarItemBlockEquatableState

    private static let leadingColumnPadding: CGFloat = 1
    private static let trailingColumnPadding: CGFloat = 1
    let item: DisplayableCalendarItem
    @Bindable var viewModel: CalendarViewModel
    var interactionHandler: CalendarInteractionHandler
    let hourHeight: CGFloat
    /// Width of this item's overlap slot (from column-level overlap layout), not full day column width.
    let slotWidth: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    @ScaledMetric(relativeTo: .body) private var cornerRadiusXSmall: CGFloat = StyleGuide.Dimensions.cornerRadiusXSmall
    @ScaledMetric(relativeTo: .body) private var paddingSmall: CGFloat = StyleGuide.Dimensions.paddingSmall
    @ScaledMetric(relativeTo: .body) private var paddingXSmall: CGFloat = StyleGuide.Dimensions.paddingXSmall

    private var cardHeight: CGFloat {
        max(18, durationHours * hourHeight)
    }

    // --- Use computed properties from DisplayableCalendarItem ---
    private var statusColor: Color { item.displayColor }
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
    private var durationHours: CGFloat { item.durationHours }
    private static let timeFormatter: Date.FormatStyle = .dateTime.hour().minute()

    private var timeRangeText: String {
        guard let startTime = item.actualStartDate, let endTime = item.actualEndDate else { return "Unknown time" }
        return "\(startTime.formatted(Self.timeFormatter)) - \(endTime.formatted(Self.timeFormatter))"
    }
    private var contentTextColor: Color {
        colorScheme == .dark ? Color.white : .black
    }

    // --- Type-specific computed properties ---
    private var isEvent: Bool { item.isEvent }

    // Adapt status/state properties based on item type
    private var sessionStatus: SessionStatus? {
        item.underlyingSession?.status
    }
    private var isCompleted: Bool { 
        item.isSession && sessionStatus == .completed
    }
    private var isCancelled: Bool { 
        item.isSession && sessionStatus == .cancelled
    }
    private var isPast: Bool { (item.endDate ?? .distantFuture) < Date() } // Common check
    private var isConfirmed: Bool { 
        item.isSession && sessionStatus == .scheduled
    }
    private var isPending: Bool { 
        item.isSession && sessionStatus == .scheduled
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

    private var isBeingResized: Bool {
        interactionHandler.resizingSessionInfo?.instanceID == item.id
    }

    private var isSelected: Bool {
        if let selectedSession = viewModel.selectedSessionInfo?.session,
           let currentSession = item.underlyingSession {
            return selectedSession.id == currentSession.id
        }
        return false
    }

    private var shouldShowResizeControls: Bool {
        !isEvent && (isSelected || isBeingResized)
    }

    private var clientNameText: String {
        guard let session = item.underlyingSession,
              let clientId = session.clientId,
              let name = viewModel.clientName(for: clientId),
              !name.isEmpty else {
            return ""
        }
        return name
    }

    private var statusText: String {
        guard let session = item.underlyingSession,
              let status = session.status else {
            return ""
        }
        return status.rawValue
    }

    private var combinedAccessibilityLabel: String {
        var parts: [String] = [item.title, timeRangeText]
        let client = clientNameText
        if !client.isEmpty {
            parts.append(client)
        }
        let status = statusText
        if !status.isEmpty {
            parts.append(status)
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        let calculatedWidth = max(0, slotWidth - Self.leadingColumnPadding - Self.trailingColumnPadding)
        let cornerRadii = segmentCornerRadii

        Button(action: handleTap) {
            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    UnevenRoundedRectangle(cornerRadii: cornerRadii)
                        .fill(cardColor.opacity(backgroundOpacity))
                        .overlay {
                            UnevenRoundedRectangle(cornerRadii: cornerRadii)
                                .strokeBorder(
                                    viewModel.isItemSelected(item) ? Color.accentColor : cardColor.opacity(0.55),
                                    lineWidth: viewModel.isItemSelected(item) ? 2.0 : 0.8
                                )
                        }
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(cardColor)
                                .frame(width: StyleGuide.Dimensions.calendarEventAccentWidth)
                                .clipShape(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: cornerRadii.topLeading,
                                        bottomLeadingRadius: cornerRadii.bottomLeading,
                                        bottomTrailingRadius: 0,
                                        topTrailingRadius: 0
                                    )
                                )
                        }
                        .overlay(alignment: .topLeading) {
                            contentVStack(slotWidth: slotWidth, cardHeight: cardHeight)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                }
                .frame(width: calculatedWidth, height: cardHeight)
                .clipShape(UnevenRoundedRectangle(cornerRadii: cornerRadii))

                VStack {
                    ResizeHandleView(
                        edge: .top,
                        item: item,
                        viewModel: viewModel,
                        interactionHandler: interactionHandler,
                        hourHeight: hourHeight
                    )
                    Spacer()
                    ResizeHandleView(
                        edge: .bottom,
                        item: item,
                        viewModel: viewModel,
                        interactionHandler: interactionHandler,
                        hourHeight: hourHeight
                    )
                }
                .padding(.vertical, -5)
                .allowsHitTesting(shouldShowResizeControls)
                .opacity(shouldShowResizeControls ? 1 : 0)
            }
            .frame(width: calculatedWidth, height: cardHeight)
            .padding(.leading, Self.leadingColumnPadding)
            .padding(.trailing, Self.trailingColumnPadding)
        }
        .buttonStyle(.plain)
        .frame(width: slotWidth, height: cardHeight, alignment: .topLeading)
        .contextMenu { makeContextMenu() }
        .onDrag {
            let payload = SessionDragPayload(
                sessionID: item.underlyingSession?.id.uuidString ?? item.id,
                originalInstanceDate: item.startDate ?? Date(),
                duration: item.endDate?.timeIntervalSince(item.startDate ?? Date()) ?? 3600
            )

            interactionHandler.startDragging(
                sessionID: payload.sessionID,
                duration: payload.duration,
                originalInstanceDate: payload.originalInstanceDate
            )

            let provider = DragItemProvider()
            provider.onDeinit = {
                Task { @MainActor in
                    if interactionHandler.draggingSessionInfo?.sessionID == payload.sessionID {
                        interactionHandler.draggingSessionInfo = nil
                        interactionHandler.dropTargetTime = nil
                    }
                }
            }

            provider.registerDataRepresentation(forTypeIdentifier: UTType.calendarSessionDragType.identifier, visibility: .all) { completion in
                do {
                    let data = try JSONEncoder().encode(payload)
                    completion(data, nil)
                } catch {
                    completion(nil, error)
                }
                return nil
            }

            return provider
        }
        .opacity(isCancelled ? 0.7 : 1.0)
        .zIndex(isBeingResized ? 10 : (isEvent ? 2 : 1))
        .contentShape(Rectangle())
        .pointerStyle(.link)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(combinedAccessibilityLabel)
        .accessibilityHint("Double click to edit session.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "View Details") {
            handleTap()
        }
    }

    private var segmentCornerRadii: RectangleCornerRadii {
        let defaultRadius: CGFloat = cornerRadiusXSmall
        var tl = defaultRadius
        var tr = defaultRadius
        var bl = defaultRadius
        var br = defaultRadius

        if let start = item.startDate, let origStart = item.originalStartDate, start > origStart {
            tl = 0
            tr = 0
        }

        if let end = item.endDate, let origEnd = item.originalEndDate, end < origEnd {
            bl = 0
            br = 0
        }

        return RectangleCornerRadii(topLeading: tl, bottomLeading: bl, bottomTrailing: br, topTrailing: tr)
    }

    private func handleTap() {
        if viewModel.isBulkSelectionMode, let session = item.underlyingSession {
            viewModel.toggleSelection(for: session.id)
            return
        }

        switch item {
        case .session(let session):
            // It's a non-recurring session, show the editor directly.
            viewModel.selectedSessionInfo = (session: session, instanceStart: session.startTime, instanceEnd: session.endTime)
        case .recurringSessionInstance(let template, let instanceStartDate, let instanceEndDate, _, _, _):
            // It's a recurring instance, show the editor for this specific instance.
            viewModel.selectedSessionInfo = (session: template, instanceStart: instanceStartDate, instanceEnd: instanceEndDate)
        case .event(let event):
            // It's an EKEvent, trigger the conversion flow.
            viewModel.convertEventToSession(event)
        case .eventSegment(let originalEvent, _, _, _, _, _):
            viewModel.convertEventToSession(originalEvent)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func contentVStack(slotWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let titleFontSize: CGFloat = {
            if slotWidth < 60 { return 9 }
            if slotWidth < 90 { return 10 }
            return 11
        }()
        let showTimeLine = cardHeight >= 20 && slotWidth >= 60
        let showPrimaryDetailLine = cardHeight >= 34 && slotWidth >= 70
        let showSecondaryDetailLine = cardHeight >= 52 && slotWidth >= 90
        let showTertiaryDetailLine = cardHeight >= 72 && slotWidth >= 110

        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .top, spacing: 4) {
                Text(item.title)
                    .font(CalendarTypography.blockTitle(size: titleFontSize))
                    .foregroundStyle(contentTextColor)
                    .lineLimit(showSecondaryDetailLine ? 2 : 1)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 2)

                // Status / selection checkmark
                if viewModel.isBulkSelectionMode, item.underlyingSession != nil {
                    Image(systemName: viewModel.isItemSelected(item) ? "checkmark.circle.fill" : "circle")
                        .font(StyleGuide.Typography.caption.weight(.semibold))
                        .foregroundStyle(viewModel.isItemSelected(item) ? Color.accentColor : contentTextColor.opacity(0.6))
                } else if let session = item.underlyingSession, slotWidth >= 50 {
                    statusBadge(for: session)
                }

                // Keep the resize affordance for sessions without stealing much space.
                if shouldShowResizeControls {
                    Image(systemName: "arrow.up.and.down")
                        .font(StyleGuide.Typography.gridSubtext)
                        .foregroundStyle(contentTextColor)
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
        .padding(.leading, paddingSmall + 4.5)
        .padding(.trailing, paddingSmall + 1)
        .padding(.vertical, paddingXSmall)
    }

    @ViewBuilder
    private func compactMetaRow(icon: String, text: String, allowsTruncation: Bool = true) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: icon)
                .font(StyleGuide.Typography.gridSubtext)
                .foregroundStyle(contentTextColor)
            Text(text)
                .font(StyleGuide.Typography.nanoMedium)
                .foregroundStyle(contentTextColor)
                .lineLimit(allowsTruncation ? 1 : nil)
                .fixedSize(horizontal: false, vertical: !allowsTruncation)
                .multilineTextAlignment(.leading)
        }
    }
    
    @ViewBuilder
    private func statusBadge(for session: Session) -> some View {
        let statusToken = Core.SessionStatus(normalized: session.status?.rawValue ?? "")?.token
        let isInvoiced = session.invoice != nil
        
        HStack(spacing: 2) {
            if isInvoiced {
                Image(systemName: "doc.text.fill")
                    .font(StyleGuide.Typography.micro.weight(.semibold))
                    .foregroundStyle(ColorSystem.Status.info)
                    .help("Linked to an invoice")
            }

            if let token = statusToken {
                let (icon, badgeColor, badgeHelp): (String, Color, String?) = {
                    switch token {
                    case Core.SessionStatus.completed.token:
                        return ("checkmark.circle.fill", ColorSystem.Status.success, "Completed — ready in Billing Hub")
                    case Core.SessionStatus.cancelled.token:
                        return ("xmark.circle.fill", ColorSystem.Status.error, "Cancelled")
                    case Core.SessionStatus.scheduled.token:
                        return ("calendar.circle.fill", ColorSystem.Status.info, "Scheduled")
                    case Core.SessionStatus.noShow.token:
                        return ("exclamationmark.circle.fill", ColorSystem.Status.warning, "No show")
                    default:
                        return ("", .clear, nil)
                    }
                }()
                if !icon.isEmpty {
                    Image(systemName: icon)
                        .font(StyleGuide.Typography.micro.weight(.semibold))
                        .foregroundStyle(badgeColor)
                        .help(badgeHelp ?? "")
                }
            }
        }
    }



    // MARK: - Context Menu Builder
    @ViewBuilder
    private func makeContextMenu() -> some View {
        switch item {
        case .session(let session), .recurringSessionInstance(let session, _, _, _, _, _):
            SessionWeekContextMenu.sessionMenu(
                session: session,
                itemStartDate: item.actualStartDate,
                itemEndDate: item.actualEndDate,
                viewModel: viewModel,
                onViewDetails: handleTap
            )
        case .event(let event), .eventSegment(let event, _, _, _, _, _):
            SessionWeekContextMenu.convertEventMenu(event: event, viewModel: viewModel)
        }
    }

    // MARK: - Action Handlers

}

// MARK: - Resize Handle View

struct ResizeHandleView: View {
    let edge: CalendarInteractionHandler.ResizeEdge
    let item: DisplayableCalendarItem
    @Bindable var viewModel: CalendarViewModel
    var interactionHandler: CalendarInteractionHandler
    let hourHeight: CGFloat

    @ScaledMetric(relativeTo: .body) private var paddingXSmall: CGFloat = StyleGuide.Dimensions.paddingXSmall
    @ScaledMetric(relativeTo: .body) private var cornerRadiusXSmall: CGFloat = StyleGuide.Dimensions.cornerRadiusXSmall


    private var isActive: Bool {
        interactionHandler.resizingSessionInfo?.instanceID == item.id && interactionHandler.resizingSessionInfo?.edge == edge
    }

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if interactionHandler.resizingSessionInfo == nil {
                    guard let session = item.underlyingSession,
                          let instanceStartTime = item.startDate,
                          let instanceEndTime = item.endDate
                    else { return }
                    
                    let instanceID = item.id // This is non-optional
                    
                    interactionHandler.resizingSessionInfo = (instanceID: instanceID, masterSessionID: session.id.uuidString, edge: edge, initialStartTime: instanceStartTime, initialEndTime: instanceEndTime)
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
                    interactionHandler.resizePreviewDate = finalDate
                }
            }
            .onEnded { value in
                guard let info = interactionHandler.resizingSessionInfo, let finalDate = interactionHandler.resizePreviewDate else {
                    interactionHandler.resizingSessionInfo = nil
                    interactionHandler.resizePreviewDate = nil
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
                
                interactionHandler.resizingSessionInfo = nil
                interactionHandler.resizePreviewDate = nil
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
            if isActive, let time = interactionHandler.resizePreviewDate {
                Text(viewModel.formatTime(time))
                    .font(StyleGuide.Typography.micro.weight(.bold))
                    .padding(.horizontal, paddingXSmall)
                    .padding(.vertical, paddingXSmall)
                    .background(Color.accentColor)
                    .foregroundStyle(Color.white)
                    .clipShape(.rect(cornerRadius: cornerRadiusXSmall))
                    .offset(y: edge == .top ? -20 : 20)
                    .zIndex(1)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 12)
    }
}

// MARK: - Drag Item Provider
final class DragItemProvider: NSItemProvider {
    var onDeinit: (() -> Void)?
    
    deinit {
        onDeinit?()
    }
}
