import SwiftUI
import EventKit
import SwiftData

struct TimelineView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var showInspector: Bool
    
    // Timeline state
    @State private var timelineScale: TimelineScale = .hour
    @State private var zoomLevel: CGFloat = 1.0
    
    private var markerHeight: CGFloat {
        let baseHeight: CGFloat
        switch timelineScale {
        case .hour: baseHeight = 35
        case .day: baseHeight = 52
        case .week: baseHeight = 70
        case .month: baseHeight = 87
        }
        return baseHeight * zoomLevel
    }
    
    var body: some View {
        HStack(spacing: 0) {
            timelineContainer()
                .frame(width: 300)
            
            Spacer()
        }
        .padding(16)
        .clipped()
    }

    @ViewBuilder
    private func timelineContainer() -> some View {
        GeometryReader { geometry in
            // Calculate marker height to fill available space
            let availableHeight = geometry.size.height
            let minHourHeight = availableHeight / 25.0 // 24 hours + 1 extra line
            let effectiveHourHeight = max(35, minHourHeight) // Minimum 35pt, or calculated to fill space
            
            timelineContent(effectiveHourHeight: effectiveHourHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.04),
                                    Color.white.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
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
                                    lineWidth: 1.5
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.blue.opacity(0.12),
                                            Color.purple.opacity(0.08),
                                            Color.indigo.opacity(0.04),
                                            Color.clear
                                        ],
                                        center: .topLeading,
                                        startRadius: 0,
                                        endRadius: 250
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.02),
                                            Color.clear,
                                            Color.white.opacity(0.01)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                )
                .shadow(
                    color: Color.black.opacity(0.15),
                    radius: 25,
                    x: 0,
                    y: 12
                )
                .shadow(
                    color: Color.blue.opacity(0.1),
                    radius: 15,
                    x: 0,
                    y: 6
                )
        }
    }

    @ViewBuilder
    private func timelineContent(effectiveHourHeight: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Time labels
            VStack(spacing: 0) {
                ForEach(timeMarkers, id: \.self) { marker in
                    Text(marker.timeString)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(isBoldHour(marker) ? .white : .secondary)
                        .frame(width: 50, height: effectiveHourHeight, alignment: .trailing)
                }
                
                // Additional marker for the last gridline
                Text("12:00am")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 50, height: effectiveHourHeight, alignment: .trailing)
            }
            .frame(width: 60)
            
            // Timeline grid with events
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    // Grid lines
                    VStack(spacing: 0) {
                        ForEach(timeMarkers, id: \.self) { marker in
                            // Hour line (thicker) - align with marker
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                    .frame(maxWidth: .infinity)
                                .frame(height: effectiveHourHeight)
                        }
                        
                        // Additional hour line after the last one
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    .frame(maxWidth: .infinity)
                            .frame(height: effectiveHourHeight)
                    }
                    
                    // 30-minute lines overlay
                    VStack(spacing: 0) {
                        ForEach(timeMarkers, id: \.self) { marker in
                            // 30-minute line (thinner) - positioned at 30 minutes past the hour
                            Rectangle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 0.5)
                                .frame(maxWidth: .infinity)
                                .frame(height: effectiveHourHeight)
                                .offset(y: effectiveHourHeight / 2)
        }
    }
    
                    // 15-minute dotted lines overlay
            VStack(spacing: 0) {
                ForEach(timeMarkers, id: \.self) { marker in
                            // 15-minute dotted line - positioned at 15 minutes past the hour
                            Rectangle()
                                .stroke(Color.gray.opacity(0.1), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                                .frame(height: 0.5)
                                .frame(maxWidth: .infinity)
                                .frame(height: effectiveHourHeight)
                                .offset(y: effectiveHourHeight * (1 / 4))
                        }
                    }
                    VStack(spacing: 0) {
                        ForEach(timeMarkers, id: \.self) { marker in
                            // 45-minute dotted line - positioned at 45 minutes past the hour
                            Rectangle()
                                .stroke(Color.gray.opacity(0.1), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                                .frame(height: 0.5)
                                .frame(maxWidth: .infinity)
                                .frame(height: effectiveHourHeight)
                                .offset(y: effectiveHourHeight * (3 / 4))
                        }
                    }
                    
                    // Event cards layer - perfectly aligned with grid
                    eventCardsLayer(geometry: geometry, effectiveHourHeight: effectiveHourHeight)
                }
            }
        }
        .frame(height: CGFloat(timeMarkers.count + 1) * effectiveHourHeight)
    }

    private var timeMarkers: [TimeMarker] {
        let calendar = Calendar.current
        let startDate = viewModel.selectedDate
        let markers: [TimeMarker]
        
        switch timelineScale {
        case .hour:
            let startOfDay = calendar.startOfDay(for: startDate)
            markers = (0..<24).map { hour in
                let time = calendar.date(byAdding: .hour, value: hour, to: startOfDay) ?? startOfDay
                return TimeMarker(
                    time: time,
                    timeString: time.formatted(date: .omitted, time: .shortened)
                )
            }
        case .day:
            markers = (0..<7).map { day in
                let time = calendar.date(byAdding: .day, value: day, to: startDate) ?? startDate
                return TimeMarker(
                    time: time,
                    timeString: time.formatted(date: .abbreviated, time: .omitted)
                )
            }
        case .week:
            markers = (0..<4).map { week in
                let time = calendar.date(byAdding: .weekOfYear, value: week, to: startDate) ?? startDate
                return TimeMarker(
                    time: time,
                    timeString: "Week \(week + 1)"
                )
            }
        case .month:
            markers = (0..<12).map { month in
                let time = calendar.date(byAdding: .month, value: month, to: startDate) ?? startDate
                return TimeMarker(
                    time: time,
                    timeString: time.formatted(date: .abbreviated, time: .omitted)
                )
            }
        }
        
        return markers
    }
    
    private func isBoldHour(_ marker: TimeMarker) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: marker.time)
        return hour % 6 == 0
    }
    
    @ViewBuilder
    private func eventCardsLayer(geometry: GeometryProxy, effectiveHourHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(viewModel.displayableItems) { item in
                if let startDate = item.startDate, let endDate = item.endDate {
                    EventCardView(
                        item: item,
                        startDate: startDate,
                        endDate: endDate,
                        timeMarkers: timeMarkers,
                        markerHeight: effectiveHourHeight,
                        timelineScale: timelineScale,
                        geometry: geometry,
                        viewModel: viewModel
                    )
                }
            }
        }
    }
}

struct TimeMarker: Hashable {
    let time: Date
    let timeString: String
}

enum TimelineScale: CaseIterable {
    case hour, day, week, month
    
    var displayName: String {
        switch self {
        case .hour: return "Hour"
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}

struct EventCardView: View {
    let item: DisplayableCalendarItem
    let startDate: Date
    let endDate: Date
    let timeMarkers: [TimeMarker]
    let markerHeight: CGFloat
    let timelineScale: TimelineScale
    let geometry: GeometryProxy
    @ObservedObject var viewModel: CalendarViewModel
    
    // Use the same approach as WeekView
    private var startHour: CGFloat { item.startHour }
    private var durationHours: CGFloat { item.durationHours }
    
    private var itemPosition: (y: CGFloat, height: CGFloat) {
        // Use the same calculation as WeekView
        let calculatedHeight = max(10, durationHours * markerHeight - 2)
        let topOffset = startHour * markerHeight
        
        // Add half-hour offset for better alignment
        let offset = markerHeight / 2
        let adjustedPosition = topOffset + offset
        
        return (adjustedPosition, calculatedHeight)
    }
    
    private var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    private var locationString: String? {
        if case .session(let session) = item {
            return session.location
        }
        return nil
    }
    
    private var clientName: String? {
        if case .session(let session) = item, let client = session.client {
            return client.fullName
        }
        return nil
    }
    
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Always show title
            Text(item.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
            
            // Show time range if height allows (minimum 30pt)
            if itemPosition.height >= 30 {
                Text(timeRangeString)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            
            // Show client name if height allows (minimum 45pt)
            if itemPosition.height >= 45, let clientName = clientName {
                Text(clientName)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            // Show location if height allows (minimum 60pt)
            if itemPosition.height >= 60, let location = locationString, !location.isEmpty {
                Text(location)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: itemPosition.height)
        .background(
            RoundedRectangle(cornerRadius: 8)
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
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
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
                    RoundedRectangle(cornerRadius: 8)
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
                    RoundedRectangle(cornerRadius: 8)
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
        )
        .shadow(
            color: Color.black.opacity(0.2),
            radius: 8,
            x: 0,
            y: 4
        )
        .shadow(
            color: item.displayColor.opacity(0.3),
            radius: 4,
            x: 0,
            y: 2
        )
        .frame(width: geometry.size.width - 16) // 8px spacing on each side
        .position(x: geometry.size.width / 2, y: itemPosition.y + (itemPosition.height / 2))
        .appInteractiveCursor()
        .onTapGesture {
            handleTap()
        }
    }
}

#Preview {
    TimelineView(viewModel: CalendarViewModel(
        context: ModelContext(try! ModelContainer(for: SessionEntity.self)),
        eventKitService: EventKitSyncService.shared,
        dataManager: CalendarDataManager(
            context: ModelContext(try! ModelContainer(for: SessionEntity.self)),
            eventKitService: EventKitSyncService.shared
        )
    ), showInspector: .constant(false))
} 
