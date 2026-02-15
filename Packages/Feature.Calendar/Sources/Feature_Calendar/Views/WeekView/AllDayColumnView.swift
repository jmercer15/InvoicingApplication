import SwiftUI
import EventKit // Needed for EKEvent properties
import SharedUI
import Core
import Data

// ─────────────────────────────────────────────────────────────
// MARK: - All Day Strip Container View
// ─────────────────────────────────────────────────────────────

struct AllDayStripView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let timeColumnWidth: CGFloat
    let dayColumnWidth: CGFloat
    private let layout = AllDayLayoutEngine()

    var body: some View {
        HStack(spacing: 0) {
            // Time column label area for "All Day"
            VStack {
                Text("All Day")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .frame(width: timeColumnWidth, alignment: .trailing)
                    .padding(.trailing, StyleGuide.Dimensions.paddingMedium)
                    .padding(.top, StyleGuide.Dimensions.paddingSmall)
                Spacer()
            }
            .frame(width: timeColumnWidth, height: layout.stripHeight)

            // Columns for each day's all-day items
            ForEach(viewModel.currentWeekDays, id: \.self) { day in
                AllDayItemsColumnView(day: day, items: viewModel.getAllDayItems(for: day), viewModel: viewModel)
                    .frame(width: dayColumnWidth)
            }
        }
        .frame(height: layout.stripHeight)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Individual Column for All Day Items
// ─────────────────────────────────────────────────────────────

struct AllDayItemsColumnView: View {
    let day: Date
    let items: [DisplayableCalendarItem]
    @ObservedObject var viewModel: CalendarViewModel
    @State private var isTargeted = false
    @EnvironmentObject var eventKitService: EventKitSyncService
    private let layout = AllDayLayoutEngine()

    private var allDayItems: [DisplayableCalendarItem] {
        viewModel.getAllDayItems(for: day)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(
                    isTargeted ? Color.accentColor.opacity(0.15) : Color("Black30", bundle: .sharedUI)
                )
                .animation(.easeInOut(duration: 0.2), value: isTargeted)

            if !items.isEmpty {
                VStack(spacing: layout.itemSpacing) {
                    // Limit the number of items shown
                    ForEach(layout.visibleItems(from: items)) { item in
                        AllDayCalendarItemView(item: item, viewModel: viewModel)
                            .onTapGesture { handleTap(item: item) }

                    }

                    // Show "+N more" indicator if needed
                    let extra = layout.moreCount(for: items)
                    if extra > 0 {
                        Text("+\(extra) more")
                            .font(.system(size: 9))
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            .padding(.horizontal, layout.moreBadgeHorizontalPadding)
                            .padding(.vertical, layout.moreBadgeVerticalPadding)
                            .background(Capsule().fill(Color.secondary.opacity(0.1)))
                    }
                }
                .padding(.horizontal, layout.columnHorizontalPadding)
                .padding(.vertical, layout.columnVerticalPadding)
            }
        }
        .frame(maxWidth: .infinity)
        .border(Color.secondary.opacity(0.2), width: 0.5)
        .onDrop(of: [.text], delegate: AllDayDropDelegate(day: day, viewModel: viewModel, isTargeted: $isTargeted))
        .onAppear {
            // Original debug print
            print("[AllDayItemsColumnView] for \(day.formatted(date: .numeric, time: .omitted)) got \(items.count) unified items.")
        }
    }

    // Handle tap gestures for different item types
    private func handleTap(item: DisplayableCalendarItem) {
        switch item {
        case .session(let session):
            viewModel.selectedSessionInfo = (session: session, instanceStart: nil, instanceEnd: nil)
        case .event(let event):
            // Event handling
            print("Tapped all-day event: \(event.title ?? "")")
            // Potentially allow converting this specific event instance to a session
            viewModel.convertEventToSession(event)
        case .recurringSessionInstance(let template, let startDate, let endDate, _):
            viewModel.selectedSessionInfo = (session: template, instanceStart: startDate, instanceEnd: endDate)
        case .eventSegment(let originalEvent, _, _, _):
            print("Tapped all-day event segment: \(originalEvent.title ?? "")")
            viewModel.convertEventToSession(originalEvent)
        }
    }
}

struct AllDayDropDelegate: DropDelegate {
    let day: Date
    let viewModel: CalendarViewModel
    @Binding var isTargeted: Bool
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.text])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        // When dropping on All Day, the time is the start of the day.
        let newStartDate = Calendar.current.startOfDay(for: day)

        if let draggedItem = viewModel.interactionHandler.draggingSessionInfo,
           let sessionID = UUID(uuidString: draggedItem.sessionID) {
             viewModel.rescheduleSession(
                with: sessionID,
                originalInstanceDate: draggedItem.originalInstanceDate,
                to: newStartDate,
                isAllDay: true
            )
        }
        
        // Reset dragging state
        viewModel.interactionHandler.draggingSessionInfo = nil
        viewModel.interactionHandler.dropTargetTime = nil
        
        return true
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - View for a Single All Day Item
// ─────────────────────────────────────────────────────────────

struct AllDayCalendarItemView: View {
    let item: DisplayableCalendarItem
    @ObservedObject var viewModel: CalendarViewModel

    @EnvironmentObject var eventKitService: EventKitSyncService
    
    // Define SessionStatus enum locally for context menu actions

    private var statusColor: Color { item.displayColor }
    private var isSession: Bool { item.isSession }
    private var isEvent: Bool { item.isEvent }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(item.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color("Text", bundle: .sharedUI))
                .lineLimit(1)
                .truncationMode(.tail)
                .italic(isEvent)
            
            Spacer()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(statusColor.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(statusColor.opacity(0.78), lineWidth: 0.6)
                )
        )
        .shadow(
            color: Color("Black30", bundle: .sharedUI).opacity(0.33),
            radius: 2,
             x: 0, y: 1
        )
        .zIndex(1)
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .pointerStyle(.link)
        .contextMenu {
            makeContextMenu()
        }
        .onTapGesture {
            handleTap()
        }
    }
    
    // MARK: - Action Handlers

    private func handleTap() {
        switch item {
        case .session(let session), .recurringSessionInstance(let session, _, _, _):
            viewModel.selectedSessionInfo = (session: session, instanceStart: session.startTime, instanceEnd: session.endTime)
        case .event(let event), .eventSegment(let event, _, _, _):
            viewModel.convertEventToSession(event)
        }
    }

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
                print("[AllDayColumnView] Failed to update session status: \(error.localizedDescription)")
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

    // MARK: - Context Menu Builder
    @ViewBuilder
    private func makeContextMenu() -> some View {
        switch item {
        case .session(let session), .recurringSessionInstance(let session, _, _, _):
            Button(action: { handleTap() }) {
                Label("View Details", systemImage: "info.circle")
            }

            Divider()
            
            // Navigation menu placeholder
            Button("View Details") {
                // Navigation logic
            }

            let statusToken = SessionStatus(normalized: session.status ?? "")?.token
            let isCompleted = statusToken == SessionStatus.completed.token
            let isCancelled = statusToken == SessionStatus.cancelled.token
            let canEditCalendarStatus = isCalendarLifecycleStatus(statusToken)

            if canEditCalendarStatus {
                if !isCompleted && !isCancelled {
                    Divider()
                    Button(action: { markSessionAs(.completed, session: session) }) {
                        Label("Mark as Completed", systemImage: "checkmark.circle")
                    }

                    Button(action: { markSessionAs(.cancelled, session: session) }) {
                        Label("Mark as Cancelled", systemImage: "xmark.circle")
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
                Label("Duplicate Session", systemImage: "plus.square.on.square")
            }


            if !session.isTravel {
                Button(action: {
                    viewModel.selectedSessionForTravel = session
                    viewModel.selectedInstanceStartDateForTravel = item.startDate ?? Date()
                    viewModel.selectedInstanceEndDateForTravel = item.endDate ?? Date()
                    viewModel.isShowingTravelChargeSheet = true
                }) {
                    Label("Add Travel Charges", systemImage: "car")
                }

            }
            
            // Delete via repository
            Button(role: .destructive, action: {
                Task {
                    do {
                        try await viewModel.sessionsRepository.delete(id: session.id)
                        await MainActor.run {
                            viewModel.updateDisplayableItems()
                        }
                    } catch {
                        print("[AllDayColumnView] Failed to delete session: \(error.localizedDescription)")
                    }
                }
            }) {
                Label("Delete Session...", systemImage: "trash")
            }


        case .event(let event), .eventSegment(let event, _, _, _):
            Button(action: {
                viewModel.convertEventToSession(event)
            }) {
                Label("Convert to Session", systemImage: "arrow.right.circle.fill")
            }

         }
    }
} 
