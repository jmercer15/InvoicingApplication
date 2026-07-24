import SwiftUI
import EventKit
import SharedUI
import Core
import Observation
import UniformTypeIdentifiers

// ─────────────────────────────────────────────────────────────
// MARK: - All Day Strip Container View
// ─────────────────────────────────────────────────────────────

struct AllDayStripView: View {
    private static let layoutMetrics = AllDayLayoutEngine()

    let viewModel: CalendarViewModel
    var interactionHandler: CalendarInteractionHandler
    let timeColumnWidth: CGFloat
    let dayColumnWidth: CGFloat

    @ScaledMetric(relativeTo: .body) private var paddingMedium: CGFloat = StyleGuide.Dimensions.paddingMedium
    @ScaledMetric(relativeTo: .body) private var paddingSmall: CGFloat = StyleGuide.Dimensions.paddingSmall

    var body: some View {
        let positionedItems = viewModel.allDayPositionedItems
        let height = viewModel.allDayStripHeight

        if height > 0 {
            ZStack(alignment: .topLeading) {
                // Background grid columns
                HStack(spacing: 0) {
                    // Time column label area for "All Day"
                    VStack {
                        Text("All Day")
                            .font(StyleGuide.Typography.caption)
                            .foregroundColor(StyleGuide.Colors.textSecondary)
                            .frame(width: timeColumnWidth, alignment: .trailing)
                            .padding(.trailing, paddingMedium)
                            .padding(.top, paddingSmall)
                        Spacer()
                    }
                    .frame(width: timeColumnWidth, height: height)
                    .overlay(
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: StyleGuide.Dimensions.hairlineWidth),
                        alignment: .trailing
                    )

                    // Daily grid column backgrounds
                    ForEach(viewModel.currentWeekDays, id: \.self) { day in
                        AllDayGridColumnView(
                            day: day,
                            viewModel: viewModel,
                            interactionHandler: interactionHandler
                        )
                            .frame(width: dayColumnWidth, height: height)
                    }
                }

                // Horizontal banners for all-day items
                let itemSpacing = Self.layoutMetrics.itemSpacing
                let verticalPadding = Self.layoutMetrics.columnVerticalPadding
                let rowHeight: CGFloat = 24

                ForEach(positionedItems) { pItem in
                    let startX = timeColumnWidth + CGFloat(pItem.startDayIndex) * dayColumnWidth
                    let spanCount = CGFloat(pItem.endDayIndex - pItem.startDayIndex + 1)
                    let width = max(10, spanCount * dayColumnWidth - 4)
                    let topY = verticalPadding + CGFloat(pItem.rowIndex) * (rowHeight + itemSpacing)

                    AllDayCalendarItemView(
                        item: pItem.item,
                        viewModel: viewModel
                    )
                    .frame(width: width, height: rowHeight)
                    .offset(x: startX + 2, y: topY)
                }
            }
            .frame(height: height)
            .overlay(
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: StyleGuide.Dimensions.hairlineWidth),
                alignment: .bottom
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Individual Column Background & Drop Target
// ─────────────────────────────────────────────────────────────

struct AllDayGridColumnView: View {
    let day: Date
    let viewModel: CalendarViewModel
    var interactionHandler: CalendarInteractionHandler
    @State private var isTargeted = false

    var body: some View {
        Rectangle()
            .fill(
                isTargeted ? Color.accentColor.opacity(0.15) : Color.clear
            )
            .overlay(
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: StyleGuide.Dimensions.hairlineWidth),
                alignment: .trailing
            )
            .onDrop(
                of: [.calendarSessionDragType],
                delegate: AllDayDropDelegate(
                    day: day,
                    viewModel: viewModel,
                    interactionHandler: interactionHandler,
                    isTargeted: $isTargeted
                )
            )
    }
}

struct AllDayDropDelegate: DropDelegate {
    let day: Date
    let viewModel: CalendarViewModel
    let interactionHandler: CalendarInteractionHandler
    @Binding var isTargeted: Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.calendarSessionDragType])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
        Task { @MainActor in
            if interactionHandler.draggingSessionInfo == nil {
                if let provider = info.itemProviders(for: [.calendarSessionDragType]).first {
                    let _ = provider.loadTransferable(type: SessionDragPayload.self) { result in
                        DispatchQueue.main.async {
                            if case .success(let payload) = result {
                                interactionHandler.startDragging(
                                    sessionID: payload.sessionID,
                                    duration: payload.duration,
                                    originalInstanceDate: payload.originalInstanceDate
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        let newStartDate = Calendar.current.startOfDay(for: day)

        guard let provider = info.itemProviders(for: [.calendarSessionDragType]).first else {
            interactionHandler.draggingSessionInfo = nil
            interactionHandler.dropTargetTime = nil
            return false
        }

        let _ = provider.loadTransferable(type: SessionDragPayload.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let payload):
                    if let sessionID = UUID(uuidString: payload.sessionID) {
                        viewModel.rescheduleSession(
                            with: sessionID,
                            originalInstanceDate: payload.originalInstanceDate,
                            to: newStartDate,
                            isAllDay: true
                        )
                    }
                case .failure(let error):
                    print("Failed to load drag payload in AllDayDropDelegate: \(error)")
                }
                interactionHandler.draggingSessionInfo = nil
                interactionHandler.dropTargetTime = nil
            }
        }

        return true
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - View for a Single All Day Item
// ─────────────────────────────────────────────────────────────

struct AllDayCalendarItemView: View {
    let item: DisplayableCalendarItem
    let viewModel: CalendarViewModel
    var onActivate: (() -> Void)? = nil

    private var statusColor: Color { item.displayColor }
    private var isEvent: Bool { item.isEvent }

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 4) {
                if viewModel.isBulkSelectionMode, item.underlyingSession != nil {
                    Image(systemName: viewModel.isItemSelected(item) ? "checkmark.circle.fill" : "circle")
                        .font(StyleGuide.Typography.micro.weight(.semibold))
                        .foregroundColor(viewModel.isItemSelected(item) ? .accentColor : StyleGuide.Colors.textSecondary)
                } else {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                }

                Text(item.title)
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundColor(StyleGuide.Colors.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .italic(isEvent)

                Spacer()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact)
                    .fill(statusColor.opacity(0.36))
                    .overlay(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact)
                            .stroke(statusColor.opacity(0.55), lineWidth: 0.6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact)
                            .stroke(
                                viewModel.isItemSelected(item) ? Color.accentColor : Color.clear,
                                lineWidth: viewModel.isItemSelected(item) ? 1.5 : 0.0
                            )
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact, style: .continuous))
        }
        .buttonStyle(.plain)
        .zIndex(1)
        .pointerStyle(.link)
        .contextMenu {
            makeContextMenu()
        }
    }

    // MARK: - Action Handlers

    private func handleTap() {
        if viewModel.isBulkSelectionMode, let session = item.underlyingSession {
            viewModel.toggleSelection(for: session.id)
            return
        }

        if let onActivate {
            onActivate()
            return
        }

        switch item {
        case .session(let session):
            viewModel.selectedSessionInfo = (session: session, instanceStart: session.startTime, instanceEnd: session.endTime)
        case .recurringSessionInstance(let session, let start, let end, _, _, _):
            viewModel.selectedSessionInfo = (session: session, instanceStart: start, instanceEnd: end)
        case .event(let event):
            viewModel.convertEventToSession(event)
        case .eventSegment(let event, _, _, _, _, _):
            viewModel.convertEventToSession(event)
        }
    }

    // MARK: - Context Menu Builder
    @ViewBuilder
    private func makeContextMenu() -> some View {
        switch item {
        case .session(let session):
            SessionWeekContextMenu.sessionMenu(
                session: session,
                itemStartDate: item.startDate ?? Date(),
                itemEndDate: item.endDate ?? Date(),
                viewModel: viewModel,
                onViewDetails: handleTap,
                symbols: .init(
                    viewDetails: "info.circle",
                    markCompleted: "checkmark.circle",
                    markCancelled: "xmark.circle",
                    markPlanned: "calendar",
                    duplicate: "plus.square.on.square",
                    travel: "car",
                    delete: "trash"
                )
            )
        case .recurringSessionInstance(let session, let start, let end, _, _, _):
            SessionWeekContextMenu.sessionMenu(
                session: session,
                itemStartDate: start,
                itemEndDate: end,
                viewModel: viewModel,
                onViewDetails: handleTap,
                symbols: .init(
                    viewDetails: "info.circle",
                    markCompleted: "checkmark.circle",
                    markCancelled: "xmark.circle",
                    markPlanned: "calendar",
                    duplicate: "plus.square.on.square",
                    travel: "car",
                    delete: "trash"
                )
            )
        case .event(let event):
            SessionWeekContextMenu.convertEventMenu(event: event, viewModel: viewModel)
        case .eventSegment(let event, _, _, _, _, _):
            SessionWeekContextMenu.convertEventMenu(event: event, viewModel: viewModel)
        }
    }
}
