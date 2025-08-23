import SwiftUI
import EventKit // Needed for EKEvent properties

// ─────────────────────────────────────────────────────────────
// MARK: - All Day Strip Container View
// ─────────────────────────────────────────────────────────────

struct AllDayStripView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let timeColumnWidth: CGFloat
    let dayColumnWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            // Time column label area for "All Day"
            VStack {
                Text("All Day")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: timeColumnWidth, alignment: .trailing)
                    .padding(.trailing, 8)
                    .padding(.top, 8)
                Spacer()
            }
            .frame(width: timeColumnWidth, height: 40)
            .glassEffect(.regular, in: .rect())

            // Columns for each day's all-day items
            ForEach(viewModel.currentWeekDays, id: \.self) { day in
                AllDayItemsColumnView(day: day, items: viewModel.getAllDayItems(for: day), viewModel: viewModel)
                    .frame(width: dayColumnWidth)
            }
        }
        .frame(height: 40)
        .glassEffect(.regular, in: .rect())
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

    private var allDayItems: [DisplayableCalendarItem] {
        viewModel.getAllDayItems(for: day)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(
                    isTargeted ? Color.accentColor.opacity(0.15) : Color.black.opacity(0.3)
                )
                .animation(.easeInOut(duration: 0.2), value: isTargeted)

            if !items.isEmpty {
                VStack(spacing: 2) {
                    // Limit the number of items shown
                    let maxItemsToShow = 3 // Increased limit
                    ForEach(items.prefix(maxItemsToShow)) { item in
                        AllDayCalendarItemView(item: item, viewModel: viewModel)
                            .onTapGesture { handleTap(item: item) }
                            .appInteractiveCursor()
                    }

                    // Show "+N more" indicator if needed
                    if items.count > maxItemsToShow {
                        Text("+\(items.count - maxItemsToShow) more")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.secondary.opacity(0.1)))
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
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
            // Reset selection first to ensure onChange triggers even for same session
            viewModel.selectedSessionInfo = nil
            DispatchQueue.main.async {
                viewModel.selectedSessionInfo = (session: session, instanceStart: nil, instanceEnd: nil)
            }
        case .event(let event):
            // Event handling
            print("Tapped all-day event: \(event.title ?? "")")
            // Potentially allow converting this specific event instance to a session
            viewModel.convertEventToSession(event)
        case .recurringSessionInstance(let template, let startDate, let endDate, _):
            // Reset selection first to ensure onChange triggers even for same session
            viewModel.selectedSessionInfo = nil
            DispatchQueue.main.async {
                viewModel.selectedSessionInfo = (session: template, instanceStart: startDate, instanceEnd: endDate)
            }
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

        if let draggedItem = viewModel.draggingSessionInfo {
             viewModel.rescheduleSession(
                with: draggedItem.sessionID,
                originalInstanceDate: draggedItem.originalInstanceDate,
                to: newStartDate,
                isAllDay: true
            )
        }
        
        // Reset dragging state
        viewModel.draggingSessionInfo = nil
        viewModel.dropTargetTime = nil
        
        return true
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - View for a Single All Day Item
// ─────────────────────────────────────────────────────────────

struct AllDayCalendarItemView: View {
    let item: DisplayableCalendarItem
    @ObservedObject var viewModel: CalendarViewModel

    @State private var isHovering: Bool = false
    @EnvironmentObject var eventKitService: EventKitSyncService
    
    // Define SessionStatus enum locally for context menu actions
    private enum SessionStatus: String {
        case planned = "Planned"
        case completed = "Completed"
        case cancelled = "Cancelled"
    }

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
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .italic(isEvent)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
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
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
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
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    statusColor.opacity(0.7),
                                    statusColor.opacity(0.6),
                                    statusColor.opacity(0.5),
                                    statusColor.opacity(0.4),
                                    statusColor.opacity(0.35),
                                    statusColor.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    // Dynamic Edge Highlight Effect
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    statusColor.opacity(0.8),
                                    statusColor.opacity(0.6),
                                    statusColor.opacity(0.4),
                                    statusColor.opacity(0.2),
                                    statusColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(
            color: .black.opacity(isHovering ? 0.25 : 0.1),
            radius: isHovering ? 4 : 2,
             x: 0, y: isHovering ? 2 : 1
        )
        .zIndex(isHovering ? 10 : 1)
         .onHover { hovering in
            withAnimation(.easeInOut) {
             isHovering = hovering
            }
        }
        .appInteractiveCursor()
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
    }

    // MARK: - Context Menu Builder
    @ViewBuilder
    private func makeContextMenu() -> some View {
        switch item {
        case .session(let session), .recurringSessionInstance(let session, _, _, _):
            Button(action: { handleTap() }) {
                Label("View Details", systemImage: "info.circle")
            }
            .appInteractiveCursor()
            Divider()
            
            EntityNavigationContextMenu(entity: .session(
                id: session.id,
                title: session.title,
                date: session.startTime,
                clientID: session.client?.id
            ))

            let isCompleted = session.status == .sessionStatusCompleted
            let isCancelled = session.status == .sessionStatusCancelled

            if !isCompleted && !isCancelled {
                Divider()
                Button(action: { markSessionAs(.completed, session: session) }) {
                    Label("Mark as Completed", systemImage: "checkmark.circle")
                }
                .appInteractiveCursor()
                Button(action: { markSessionAs(.cancelled, session: session) }) {
                    Label("Mark as Cancelled", systemImage: "xmark.circle")
                }
                .appInteractiveCursor()
            }

            if isCompleted || isCancelled {
                Divider()
                Button(action: { markSessionAs(.planned, session: session) }) {
                    Label("Mark as Planned", systemImage: "calendar")
                }
                .appInteractiveCursor()
            }

            Divider()

            Button(action: { viewModel.duplicateSession(session) }) {
                Label("Duplicate Session", systemImage: "plus.square.on.square")
            }
            .appInteractiveCursor()

            if !session.isTravel {
                Button(action: {
                    viewModel.selectedSessionForTravel = session
                    viewModel.selectedInstanceStartDateForTravel = item.startDate ?? Date()
                    viewModel.selectedInstanceEndDateForTravel = item.endDate ?? Date()
                    viewModel.isShowingTravelChargeSheet = true
                }) {
                    Label("Add Travel Charges", systemImage: "car")
                }
                .appInteractiveCursor()
            }
            
            Button(role: .destructive, action: {
                viewModel.handleDeleteFromEditor(
                    with: .thisOnly,
                    viewModel: NewSessionViewModel(
                        context: viewModel.modelContext,
                        session: session,
                        instanceDate: nil
                    )
                )
            }) {
                Label("Delete Session...", systemImage: "trash")
            }
            .appInteractiveCursor()

        case .event(let event), .eventSegment(let event, _, _, _):
            Button(action: {
                viewModel.convertEventToSession(event)
            }) {
                Label("Convert to Session", systemImage: "arrow.right.circle.fill")
            }
            .appInteractiveCursor()
         }
    }
} 