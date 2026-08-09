import SwiftUI
import Core
import PersistenceModels
import EventKit
import SharedUI
import Observation

// ─────────────────────────────────────────────────────────────
// MARK: - Day Cell View (for Month Grid)
// ─────────────────────────────────────────────────────────────

private struct MonthDayIndicatorLayout {
    let visible: [DisplayableCalendarItem]
    let moreCount: Int
}

struct MonthDayCellView: View {
    let date: Date
    @Bindable var viewModel: CalendarViewModel
    let weekIndex: Int
    let dayIndex: Int
    let isLastWeek: Bool

    @State private var dayItems: [DisplayableCalendarItem] = []
    @State private var indicatorLayout = MonthDayIndicatorLayout(visible: [], moreCount: 0)
    @State private var lastIndicatorHeight: CGFloat = -1

    private var dayItemsTaskID: String {
        viewModel.combinedItems(for: date).map(\.id).joined(separator: "\u{1F}")
    }

    // --- Computed Properties --- 
    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    private var isCurrentMonth: Bool { Calendar.current.isDate(date, equalTo: viewModel.selectedDate, toGranularity: .month) }
    private var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // Sunday or Saturday
    }
    private var dayNumber: String {
        DateFormatting.dayNumber(date)
    }
    // --- Dynamic Colors --- 
    private var gridBorderColor: Color {
        isToday ? Color.accentColor.opacity(0.4) : StyleGuide.Colors.border.opacity(0.3)
    }

    private var dayNumberTextColor: Color {
        if isToday { return .white }
        if viewModel.isSelectedDay(date) { return .accentColor }
        if !isCurrentMonth { return StyleGuide.Colors.textSecondary.opacity(0.4) }
        return StyleGuide.Colors.text
    }
    private var cellTint: Color? {
        if isToday { return Color.accentColor.opacity(StyleGuide.Opacity.subtle) }
        if viewModel.isSelectedDay(date) { return Color.accentColor.opacity(StyleGuide.Opacity.faint) }
        if isCurrentMonth {
            return isWeekend ? StyleGuide.Colors.text.opacity(StyleGuide.Opacity.light) : nil
        }
        return StyleGuide.Colors.textSecondary.opacity(StyleGuide.Opacity.faint)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background selector button
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.selectedDate = date
                    }
                } label: {
                    Rectangle()
                        .fill(cellTint ?? .clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select \(DateFormatting.fullAccessibilityDate(date))")
                
                // Foreground Content
                VStack(alignment: .center, spacing: 2) {
                    dayNumberHeader()
                    itemIndicatorsView(geometry: geometry)
                    Spacer()
                }
                .allowsHitTesting(true)
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
                    .frame(width: nil, height: StyleGuide.Dimensions.hairlineWidth)
                    .foregroundStyle(gridBorderColor) : nil,
                alignment: .top
            )
            .overlay(
                // Left border (only for first column)
                dayIndex == 0 ? Rectangle()
                    .frame(width: StyleGuide.Dimensions.hairlineWidth, height: nil)
                    .foregroundStyle(gridBorderColor) : nil,
                alignment: .leading
            )
            .overlay(
                // Right border (for all columns to complete grid)
                Rectangle()
                    .frame(width: StyleGuide.Dimensions.hairlineWidth, height: nil)
                    .foregroundStyle(gridBorderColor),
                alignment: .trailing
            )
            .overlay(
                // Bottom border (for all rows to complete grid)
                Rectangle()
                    .frame(width: nil, height: StyleGuide.Dimensions.hairlineWidth)
                    .foregroundStyle(gridBorderColor),
                alignment: .bottom
            )
            .task(id: dayItemsTaskID) {
                dayItems = viewModel.combinedItems(for: date)
                lastIndicatorHeight = -1
            }
            .contextMenu {
                ForEach(dayItems.filter { $0.underlyingSession != nil }) { item in
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
        let isSelected = viewModel.isSelectedDay(date)
        HStack {
            Spacer()
            Text(dayNumber)
                .font(StyleGuide.Typography.gridDayNumber.weight(isToday ? .bold : (isSelected ? .semibold : (isCurrentMonth ? .medium : .regular))))
                .foregroundStyle(isToday ? Color.white : (isSelected ? Color.accentColor : dayNumberTextColor))
                .frame(width: StyleGuide.Dimensions.calendarDayCellSize, height: StyleGuide.Dimensions.calendarDayCellSize)
                .background {
                    if isToday {
                        Circle()
                            .fill(Color.accentColor)
                    } else if isSelected {
                        Circle()
                            .stroke(Color.accentColor, lineWidth: 1.5)
                            .background(Circle().fill(Color.accentColor.opacity(0.08)))
                    }
                }
                .monospacedDigit()
            Spacer()
        }
        .padding(.top, StyleGuide.Dimensions.paddingSmall)
    }

    private func itemHeight(for item: DisplayableCalendarItem) -> CGFloat {
        switch item {
        case .session(let session):
            return session.clientId != nil ? 28 : 22
        case .recurringSessionInstance(let template, _, _, _, _, _):
            return template.clientId != nil ? 28 : 22
        default:
            return 22
        }
    }

    private func visibleItemsAndMoreCount(for items: [DisplayableCalendarItem], availableHeight: CGFloat) -> (visible: [DisplayableCalendarItem], moreCount: Int) {
        let spacing: CGFloat = 3
        let badgeHeight: CGFloat = 16
        
        // First check: can we fit all items?
        var totalHeightOfAll: CGFloat = 0
        for (idx, item) in items.enumerated() {
            totalHeightOfAll += itemHeight(for: item)
            if idx > 0 {
                totalHeightOfAll += spacing
            }
        }
        
        if totalHeightOfAll <= availableHeight {
            return (items, 0)
        }
        
        // Not all items fit. We must show a "+X more" badge.
        let availableHeightForItems = availableHeight - badgeHeight - spacing
        var totalHeightWithBadge: CGFloat = 0
        var visibleCount = 0
        
        for item in items {
            let h = itemHeight(for: item)
            let nextHeight = totalHeightWithBadge + h + (visibleCount > 0 ? spacing : 0)
            if nextHeight <= availableHeightForItems {
                totalHeightWithBadge = nextHeight
                visibleCount += 1
            } else {
                break
            }
        }
        
        let finalVisibleCount = max(1, visibleCount)
        return (Array(items.prefix(finalVisibleCount)), items.count - finalVisibleCount)
    }

    @ViewBuilder
    private func itemIndicatorsView(geometry: GeometryProxy) -> some View {
        let spacing: CGFloat = 3
        let headerHeight: CGFloat = 30
        let bottomPadding: CGFloat = 4
        let availableHeight = max(0, geometry.size.height - headerHeight - bottomPadding)

        if !dayItems.isEmpty {
            VStack(spacing: spacing) {
                ForEach(indicatorLayout.visible, id: \DisplayableCalendarItem.id) { item in
                    itemView(for: item)
                }

                if indicatorLayout.moreCount > 0 {
                    HStack {
                        Spacer()
                        Text("+\(indicatorLayout.moreCount) more")
                            .font(StyleGuide.Typography.caption)
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, StyleGuide.Dimensions.paddingXSmall)
                            .padding(.vertical, StyleGuide.Dimensions.calendarBadgeVerticalPadding)
                            .background(Color.accentColor.opacity(StyleGuide.Opacity.faint))
                            .cornerRadius(StyleGuide.Dimensions.calendarBadgeCornerRadius)
                        Spacer()
                    }
                    .padding(.top, StyleGuide.Dimensions.calendarBadgeTopPadding)
                }
            }
            .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
            .onAppear {
                refreshIndicatorLayout(availableHeight: availableHeight)
            }
            .onChange(of: availableHeight) { _, newHeight in
                refreshIndicatorLayout(availableHeight: newHeight)
            }
            .onChange(of: dayItemsTaskID) { _, _ in
                refreshIndicatorLayout(availableHeight: availableHeight)
            }
        }
    }

    private func refreshIndicatorLayout(availableHeight: CGFloat) {
        guard !dayItems.isEmpty else {
            indicatorLayout = MonthDayIndicatorLayout(visible: [], moreCount: 0)
            lastIndicatorHeight = availableHeight
            return
        }
        guard lastIndicatorHeight != availableHeight else { return }
        lastIndicatorHeight = availableHeight
        let computed = visibleItemsAndMoreCount(for: dayItems, availableHeight: availableHeight)
        indicatorLayout = MonthDayIndicatorLayout(visible: computed.visible, moreCount: computed.moreCount)
    }

    @ViewBuilder
    private func itemView(for item: DisplayableCalendarItem) -> some View {
        switch item {
        case .session(let session):
            Button {
                if viewModel.isBulkSelectionMode {
                    viewModel.toggleSelection(for: session.id)
                } else {
                    viewModel.selectedSessionInfo = (session: session, instanceStart: item.startDate, instanceEnd: item.endDate)
                }
            } label: {
                MonthSessionItemView(session: session, viewModel: viewModel)
            }
            .buttonStyle(.plain)
        case .event(let event):
            Button {
                viewModel.convertEventToSession(event)
            } label: {
                MonthEventItemView(event: event)
            }
            .buttonStyle(.plain)
        case .recurringSessionInstance(let template, let instanceStartDate, let instanceEndDate, _, _, _):
            Button {
                if viewModel.isBulkSelectionMode {
                    viewModel.toggleSelection(for: template.id)
                } else {
                    viewModel.selectedSessionInfo = (session: template, instanceStart: instanceStartDate, instanceEnd: instanceEndDate)
                }
            } label: {
                MonthSessionItemView(session: template, viewModel: viewModel)
            }
            .buttonStyle(.plain)
        case .eventSegment(let originalEvent, _, _, _, _, _):
            Button {
                viewModel.convertEventToSession(originalEvent)
            } label: {
                MonthEventItemView(event: originalEvent)
            }
            .buttonStyle(.plain)
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Session Cell Item (Minimal for Month View)
// ─────────────────────────────────────────────────────────────

struct MonthSessionItemView: View {
    let session: Session
    @Bindable var viewModel: CalendarViewModel
    
    private var clientColor: Color {
        if let clientId = session.clientId {
            return ColorSystem.Client.color(for: clientId)
        }
        return StyleGuide.Colors.secondary
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall)
                .fill(clientColor.opacity(0.36))
                .overlay {
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall)
                        .strokeBorder(
                            viewModel.bulkSelectedSessionIDs.contains(session.id)
                                ? Color.accentColor
                                : clientColor.opacity(0.55),
                            lineWidth: viewModel.bulkSelectedSessionIDs.contains(session.id) ? 1.5 : 0.6
                        )
                }

            HStack(spacing: 4) {
                if viewModel.isBulkSelectionMode {
                    Image(systemName: viewModel.bulkSelectedSessionIDs.contains(session.id) ? "checkmark.circle.fill" : "circle")
                        .font(StyleGuide.Typography.caption)
                        .foregroundStyle(viewModel.bulkSelectedSessionIDs.contains(session.id) ? Color.accentColor : StyleGuide.Colors.textSecondary)
                } else {
                    Rectangle()
                         .fill(clientColor)
                         .frame(width: StyleGuide.Dimensions.accentBarWidth, height: StyleGuide.Dimensions.fontSizeCompactTitle + StyleGuide.Dimensions.paddingXSmall)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.title)
                        .font(StyleGuide.Typography.gridSubtext)
                        .foregroundStyle(StyleGuide.Colors.text)
                        .lineLimit(1)
                    
                    if let clientId = session.clientId {
                        ClientNameView(
                            clientId: clientId,
                            viewModel: viewModel
                        )
                        .font(StyleGuide.Typography.caption)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                        .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.vertical, StyleGuide.Dimensions.calendarItemVerticalPadding)
            .padding(.horizontal, StyleGuide.Dimensions.calendarItemHorizontalPadding)
        }
        .contentShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall, style: .continuous))
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
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall)
                .fill(calendarColor.opacity(0.36))
                .overlay {
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall)
                        .strokeBorder(calendarColor.opacity(0.55), lineWidth: 0.6)
                }

            HStack(spacing: 4) {
                 Rectangle()
                     .fill(calendarColor)
                     .frame(width: StyleGuide.Dimensions.accentBarWidth, height: StyleGuide.Dimensions.fontSizeCompactTitle + StyleGuide.Dimensions.paddingXSmall)

                Text(event.title ?? "Event")
                    .font(StyleGuide.Typography.gridSubtextRegular)
                    .italic()
                    .foregroundStyle(StyleGuide.Colors.text)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.vertical, StyleGuide.Dimensions.calendarItemVerticalPadding)
            .padding(.horizontal, StyleGuide.Dimensions.calendarItemHorizontalPadding)
        }
        .contentShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall, style: .continuous))
        .pointerStyle(.link)
    }
}
