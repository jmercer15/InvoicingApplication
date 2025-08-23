import SwiftUI
import EventKit

// MARK: - Compact Calendar Visibility Control (for header bar)

struct CompactCalendarVisibilityControl: View {
    @ObservedObject var viewModel: CalendarViewModel
    @State private var showMenu = false
    
    var body: some View {
        Menu {
            // Show/Hide All option
            Button(action: {
                if viewModel.visibleCalendarIdentifiers.count == viewModel.availableCalendars.count {
                    // All visible, hide all
                    viewModel.visibleCalendarIdentifiers.removeAll()
                } else {
                    // Not all visible, show all monitored calendars
                    viewModel.visibleCalendarIdentifiers = Set(viewModel.availableCalendars.map { $0.calendarIdentifier })
                }
                viewModel.updateDisplayableItems()
            }) {
                Label(
                    viewModel.visibleCalendarIdentifiers.count == viewModel.availableCalendars.count ? "Hide All Calendars" : "Show All Calendars",
                    systemImage: viewModel.visibleCalendarIdentifiers.count == viewModel.availableCalendars.count ? "eye.slash" : "eye"
                )
            }
            
            Divider()
            
            // Individual calendar toggles
            ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
                Button(action: {
                    viewModel.toggleCalendarVisibility(calendarIdentifier: calendar.calendarIdentifier)
                }) {
                    HStack {
                        Circle()
                            .fill(Color(calendar.cgColor ?? CGColor(gray: 0.5, alpha: 1.0)))
                            .frame(width: 8, height: 8)
                        
                        Text(calendar.title)
                            .foregroundColor(viewModel.isCalendarVisible(calendarIdentifier: calendar.calendarIdentifier) ? .primary : .secondary)
                        
                        Spacer()
                        
                        if viewModel.isCalendarVisible(calendarIdentifier: calendar.calendarIdentifier) {
                            Image(systemName: "eye.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "eye.slash")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                Text("\(viewModel.visibleCalendarIdentifiers.count)/\(viewModel.availableCalendars.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(height: 28)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .appInteractiveCursor()
    }
}

// MARK: - Calendar Visibility Control (original full version)

struct CalendarVisibilityControl: View {
    @ObservedObject var viewModel: CalendarViewModel
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with toggle button
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 14, weight: .medium))
                        Text("Monitored Calendars (\(viewModel.visibleCalendarIdentifiers.count)/\(viewModel.availableCalendars.count))")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Quick toggle for all monitored calendars
                Button(action: {
                    if viewModel.visibleCalendarIdentifiers.count == viewModel.availableCalendars.count {
                        // All visible, hide all
                        viewModel.visibleCalendarIdentifiers.removeAll()
                    } else {
                        // Not all visible, show all monitored calendars
                        viewModel.visibleCalendarIdentifiers = Set(viewModel.availableCalendars.map { $0.calendarIdentifier })
                    }
                    viewModel.updateDisplayableItems()
                }) {
                    Text(viewModel.visibleCalendarIdentifiers.count == viewModel.availableCalendars.count ? "Hide All" : "Show All")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 8))
            
            // Calendar list
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
                        CalendarToggleRow(
                            calendar: calendar,
                            isVisible: viewModel.isCalendarVisible(calendarIdentifier: calendar.calendarIdentifier),
                            onToggle: {
                                viewModel.toggleCalendarVisibility(calendarIdentifier: calendar.calendarIdentifier)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(8)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Calendar Toggle Row

struct CalendarToggleRow: View {
    let calendar: EKCalendar
    let isVisible: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Calendar color indicator
            Circle()
                .fill(Color(calendar.cgColor ?? CGColor(gray: 0.5, alpha: 1.0)))
                .frame(width: 12, height: 12)
            
            // Calendar name
            Text(calendar.title)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            // Toggle button
            Button(action: onToggle) {
                Image(systemName: isVisible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isVisible ? .green : .white.opacity(0.5))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

// MARK: - Floating Calendar Visibility Button

struct FloatingCalendarVisibilityButton: View {
    @ObservedObject var viewModel: CalendarViewModel
    @State private var showCalendarControl = false
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                VStack {
                    if showCalendarControl {
                        CalendarVisibilityControl(viewModel: viewModel)
                            .transition(.opacity.combined(with: .scale))
                    }
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCalendarControl.toggle()
                        }
                    }) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
} 