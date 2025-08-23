import SwiftUI

import EventKit

// ─────────────────────────────────────────────────────────────
// MARK: - Day Cell View (for Month Grid)
// ─────────────────────────────────────────────────────────────

struct MonthDayCellView: View {
    let date: Date
    @ObservedObject var viewModel: CalendarViewModel


    @State private var isHovering = false

    // --- Computed Properties --- 
    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    private var isCurrentMonth: Bool { Calendar.current.isDate(date, equalTo: viewModel.selectedDate, toGranularity: .month) }
    private var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // Sunday or Saturday
    }
    private var dayNumber: String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }
    private var allItemsForDay: [DisplayableCalendarItem] {
        let timedForDay = viewModel.getTimedItems(for: date)
        let allDayForDay = viewModel.getAllDayItems(for: date)
        return (timedForDay + allDayForDay).sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
    }
    private var totalItemCount: Int { allItemsForDay.count }

    // --- Dynamic Colors --- 
    private var dayNumberTextColor: Color {
        if isToday { return .accentColor }
        if !isCurrentMonth { return .white.opacity(0.4) }
        return isWeekend ? Color.white.opacity(0.6) : Color.white.opacity(0.9)
    }
    private var cellBackground: Color {
        if isHovering { return Color.white.opacity(0.02) } 
        if isCurrentMonth {
            return isWeekend ? Color.white.opacity(0.02) : Color(red: 0.11, green: 0.11, blue: 0.13)
        }
        return Color.black.opacity(0.2)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 2) {
                dayNumberHeader()
                itemIndicatorsView(geometry: geometry)
                Spacer() // Pushes content to top
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(cellBackground)
            .overlay(cellBorder)
            .onHover { hovering in isHovering = hovering }
            // Tap gesture handled by parent MonthView
            .padding(1)
            .contextMenu {
                // Directly iterate over the items for the context menu
                ForEach(viewModel.getTimedItems(for: date)) { item in
                    if let session = item.underlyingSession {
                        Button {
                            // Reset selection first to ensure onChange triggers even for same session
                            viewModel.selectedSessionInfo = nil
                            DispatchQueue.main.async {
                                viewModel.selectedSessionInfo = (session: session, instanceStart: item.startDate, instanceEnd: item.endDate)
                            }
                        } label: {
                            Label(session.title, systemImage: "pencil")
                        }
                    }
                }
            }
        }
    }

    // --- Subview Builders --- 
    @ViewBuilder
    private func dayNumberHeader() -> some View {
        HStack {
            // Map navigation button (only show when hovering and there are sessions)
            if isHovering && !allItemsForDay.isEmpty {
                NavigateToMapButton(date: date, style: .icon)
                    .scaleEffect(0.8)
                    .opacity(0.7)
            }
            
            Spacer()
            Text(dayNumber)
                .font(.system(size: 16, weight: isToday ? .bold : (isCurrentMonth ? .medium : .regular)))
                .foregroundColor(dayNumberTextColor)
                .frame(minWidth: 24, minHeight: 24)
                .monospacedDigit()
            Spacer()
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func itemIndicatorsView(geometry: GeometryProxy) -> some View {
        if !allItemsForDay.isEmpty {
            // Wrap the item list in a vertical ScrollView
            ScrollView(.vertical, showsIndicators: false) { 
                LazyVStack(spacing: 3) {
                    // Iterate over ALL items
                    ForEach(allItemsForDay, id: \DisplayableCalendarItem.id) { item in
                        switch item {
                        case .session(let session):
                            MonthSessionItemView(session: session)
                                .onTapGesture { 
                                    // Reset selection first to ensure onChange triggers even for same session
                                    viewModel.selectedSessionInfo = nil
                                    DispatchQueue.main.async {
                                        viewModel.selectedSessionInfo = (session: session, instanceStart: item.startDate, instanceEnd: item.endDate)
                                    }
                                }
                        case .event(let event):
                            MonthEventItemView(event: event)
                                .onTapGesture { 
                                    viewModel.convertEventToSession(event)
                                }
                        case .recurringSessionInstance(let template, let instanceStartDate, let instanceEndDate, _):
                            MonthSessionItemView(session: template)
                                .onTapGesture { 
                                    // Reset selection first to ensure onChange triggers even for same session
                                    viewModel.selectedSessionInfo = nil
                                    DispatchQueue.main.async {
                                        viewModel.selectedSessionInfo = (session: template, instanceStart: instanceStartDate, instanceEnd: instanceEndDate)
                                    }
                                }
                        case .eventSegment(let originalEvent, _, _, _):
                            MonthEventItemView(event: originalEvent)
                                .onTapGesture {
                                    viewModel.convertEventToSession(originalEvent)
                                }
                                }
                        }
                    }
            }
            .clipped() // Clip the ScrollView content
            .padding(.horizontal, 6) // Apply padding to the ScrollView itself
        }
    }

    // --- Border Overlay --- 
    private var cellBorder: some View {
        Rectangle()
            .stroke(
                isToday
                    ? Color.accentColor.opacity(0.6)
                    : Color.secondary.opacity(0.2),
                lineWidth: isToday ? 1.5 : 0.5
            )
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Session Cell Item (Minimal for Month View)
// ─────────────────────────────────────────────────────────────

struct MonthSessionItemView: View {
    let session: SessionEntity
    private var clientColor: Color {
        if let client = session.client {
            return Color(hex: client.colorHex)
        }
        return .gray
    }

    var body: some View {
        HStack(spacing: 4) {
            Rectangle()
                 .fill(clientColor)
                 .frame(width: 3, height: 18)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(session.title).font(.caption)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.9))
                    .lineLimit(1)
                
                if let clientName = session.client?.fullName, !clientName.isEmpty {
                    Text(clientName)
                        .font(.system(size: 9))
                        .foregroundColor(Color.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.clear,
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .overlay(
                    // Client color overlay
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    clientColor.opacity(0.3),
                                    clientColor.opacity(0.2),
                                    clientColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .appInteractiveCursor()
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Calendar Event Cell Item (Minimal for Month View)
// ─────────────────────────────────────────────────────────────

struct MonthEventItemView: View {
    let event: EKEvent
    private var calendarColor: Color { 
        let calendarId = event.calendar.calendarIdentifier
        if let customColor = getCustomCalendarColor(calendarId: calendarId) {
            return customColor
        }
        return Color(event.calendar.cgColor)
    }
    
    private func getCustomCalendarColor(calendarId: String) -> Color? {
        let preferences = CalendarPreferences()
        guard let calendarSettings = preferences.perCalendarPreferences[calendarId],
              let hexString = calendarSettings.colorHex else {
            return nil
        }
        return Color(hex: hexString)
    }

    var body: some View {
        HStack(spacing: 4) {
             Rectangle()
                 .fill(calendarColor)
                 .frame(width: 3, height: 18)

            Text(event.title ?? "Event")
                .font(.system(size: 10))
                .italic()
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.clear,
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .overlay(
                    // Calendar color overlay
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    calendarColor.opacity(0.3),
                                    calendarColor.opacity(0.2),
                                    calendarColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .appInteractiveCursor()
    }
} 