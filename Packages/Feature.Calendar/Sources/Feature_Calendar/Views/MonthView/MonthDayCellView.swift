import SwiftUI
import Core
import EventKit
import Data
import SharedUI

// ─────────────────────────────────────────────────────────────
// MARK: - Day Cell View (for Month Grid)
// ─────────────────────────────────────────────────────────────

struct MonthDayCellView: View {
    let date: Date
    @ObservedObject var viewModel: CalendarViewModel
    let weekIndex: Int
    let dayIndex: Int
    let isLastWeek: Bool

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
        if !isCurrentMonth { return Color("TextSecondary", bundle: .sharedUI).opacity(0.4) }
        return Color("Text", bundle: .sharedUI)
    }
    private var cellTint: Color? {
        if isToday { return Color.accentColor.opacity(0.04) }
        if isCurrentMonth {
            return isWeekend ? Color.black.opacity(0.08) : nil
        }
        return Color.secondary.opacity(0.05)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 2) {
                dayNumberHeader()
                itemIndicatorsView(geometry: geometry)
                Spacer() // Pushes content to top
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if let tint = cellTint {
                    Rectangle()
                        .fill(tint)
                }
            }
            .overlay(
                // Top border (only for first row)
                weekIndex == 0 ? Rectangle()
                    .frame(width: nil, height: 0.5)
                    .foregroundColor(
                        isToday
                            ? Color.accentColor.opacity(0.4)
                            : Color.secondary.opacity(0.3)
                    ) : nil,
                alignment: .top
            )
            .overlay(
                // Left border (only for first column)
                dayIndex == 0 ? Rectangle()
                    .frame(width: 0.5, height: nil)
                    .foregroundColor(
                        isToday
                            ? Color.accentColor.opacity(0.4)
                            : Color.secondary.opacity(0.3)
                    ) : nil,
                alignment: .leading
            )
            .overlay(
                // Right border (for all columns to complete grid)
                Rectangle()
                    .frame(width: 0.5, height: nil)
                    .foregroundColor(
                        isToday
                            ? Color.accentColor.opacity(0.4)
                            : Color.secondary.opacity(0.3)
                    ),
                alignment: .trailing
            )
            .overlay(
                // Bottom border (for all rows to complete grid)
                Rectangle()
                    .frame(width: nil, height: 0.5)
                    .foregroundColor(
                        isToday
                            ? Color.accentColor.opacity(0.4)
                            : Color.secondary.opacity(0.3)
                    ),
                alignment: .bottom
            )
            // Tap gesture handled by parent MonthView
            .contextMenu {
                // Directly iterate over the items for the context menu
                ForEach(viewModel.getTimedItems(for: date)) { item in
                    if let session = item.underlyingSession {
                        Button {
                            viewModel.selectedSessionInfo = (session: session, instanceStart: item.startDate, instanceEnd: item.endDate)
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
                            MonthSessionItemView(session: session, viewModel: viewModel)
                                .onTapGesture { 
                                    viewModel.selectedSessionInfo = (session: session, instanceStart: item.startDate, instanceEnd: item.endDate)
                                }
                        case .event(let event):
                            MonthEventItemView(event: event)
                                .onTapGesture { 
                                    viewModel.convertEventToSession(event)
                                }
                        case .recurringSessionInstance(let template, let instanceStartDate, let instanceEndDate, _):
                            MonthSessionItemView(session: template, viewModel: viewModel)
                                .onTapGesture { 
                                    viewModel.selectedSessionInfo = (session: template, instanceStart: instanceStartDate, instanceEnd: instanceEndDate)
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


}

// ─────────────────────────────────────────────────────────────
// MARK: - Session Cell Item (Minimal for Month View)
// ─────────────────────────────────────────────────────────────

struct MonthSessionItemView: View {
    let session: Session
    @ObservedObject var viewModel: CalendarViewModel
    
    private var clientColor: Color {
        if let clientId = session.clientId {
            return ColorSystem.Client.color(for: clientId)
        }
        return Color("Gray20", bundle: .sharedUI)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(clientColor.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(clientColor.opacity(0.78), lineWidth: 0.6)
                )

            HStack(spacing: 4) {
                Rectangle()
                     .fill(clientColor)
                     .frame(width: 3, height: 18)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.title).font(.caption)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .lineLimit(1)
                    
                    if let clientId = session.clientId {
                        ClientNameView(
                            clientId: clientId,
                            viewModel: viewModel
                        )
                        .font(.system(size: 9))
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 5)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 1.5, x: 0, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .pointerStyle(.link)
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
        CalendarColorProvider.color(for: calendarId)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(calendarColor.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(calendarColor.opacity(0.78), lineWidth: 0.6)
                )

            HStack(spacing: 4) {
                 Rectangle()
                     .fill(calendarColor)
                     .frame(width: 3, height: 18)

                Text(event.title ?? "Event")
                    .font(.system(size: 10))
                    .italic()
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 5)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 1.5, x: 0, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .pointerStyle(.link)
    }
}
