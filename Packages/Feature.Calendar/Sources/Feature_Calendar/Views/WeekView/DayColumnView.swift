import SwiftUI
import SharedUI
import Observation
import UniformTypeIdentifiers


// ─────────────────────────────────────────────────────────────
// MARK: - Day Column View (Container for Hours & Items)
// ─────────────────────────────────────────────────────────────

struct DayColumnView: View {
    let day: Date
    let items: [DisplayableCalendarItem]
    @Bindable var viewModel: CalendarViewModel
    var interactionHandler: CalendarInteractionHandler
    let columnWidth: CGFloat
    let effectiveHourHeight: CGFloat
    var visibleHourRange: ClosedRange<CGFloat> = 0...24

    @ScaledMetric(relativeTo: .body) private var paddingSmall: CGFloat = StyleGuide.Dimensions.paddingSmall
    @ScaledMetric(relativeTo: .body) private var paddingXSmall: CGFloat = StyleGuide.Dimensions.paddingXSmall
    @ScaledMetric(relativeTo: .body) private var cornerRadiusSmall: CGFloat = StyleGuide.Dimensions.cornerRadiusSmall

    // Inject lightweight layout helpers derived from inputs
    private var metrics: CalendarTimelineMetrics {
        CalendarTimelineMetrics(hourHeight: effectiveHourHeight, columnWidth: columnWidth)
    }
    private var layoutEngine: CalendarLayoutEngine { CalendarLayoutEngine(metrics: metrics) }

    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: day)
        return weekday == 1 || weekday == 7 // Sunday or Saturday
    }
    private let hours = Array(0...23)

    @State private var isDropTargeted = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            calendarItemBlocksView()
            
            // --- Visual guide for resizing ---
            if let resizeInfo = interactionHandler.resizingSessionInfo,
               let resizePreviewDate = interactionHandler.resizePreviewDate {
                
                let viewRange = viewModel.currentViewDateRange
                if Calendar.current.isDate(resizePreviewDate, inSameDayAs: day) &&
                   (resizeInfo.initialStartTime >= viewRange.start && resizeInfo.initialStartTime < viewRange.end) {

                    let yOffset = metrics.yOffset(for: resizePreviewDate)
                    
                    Group {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: yOffset))
                            path.addLine(to: CGPoint(x: columnWidth, y: yOffset))
                        }
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .zIndex(20)

                        Text(viewModel.formatTime(resizePreviewDate))
                            .font(StyleGuide.Typography.micro.weight(.bold))
                            .padding(.horizontal, paddingSmall)
                            .padding(.vertical, paddingXSmall)
                            .background(Color.accentColor)
                            .foregroundColor(StyleGuide.Colors.text)
                            .cornerRadius(cornerRadiusSmall)
                            .offset(x: 5, y: yOffset - 12)
                            .zIndex(21)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(height: CGFloat(hours.count) * effectiveHourHeight)
        .frame(width: columnWidth)
        .background(columnBackground)
        .overlay(columnBorder)
        .onDrop(
            of: [.calendarSessionDragType],
            delegate: DayColumnDropDelegate(
                day: day,
                viewModel: viewModel,
                interactionHandler: interactionHandler,
                effectiveHourHeight: effectiveHourHeight,
                isTargeted: $isDropTargeted
            )
        )
        .accessibilityRotor("Scheduled Events") {
            ForEach(items) { item in
                AccessibilityRotorEntry(item.title, id: item.id)
            }
        }
    }

    // Builds the overlay containing the actual calendar item blocks
    // Pre-calculated relative placements from the view model
    private var relativePlacements: [String: CalendarItemOverlapGeometry.RelativePlacement] {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return viewModel.relativePlacementsByDay[components] ?? [:]
    }

    private func slotWidth(for id: String) -> CGFloat {
        let placement = relativePlacements[id] ?? CalendarItemOverlapGeometry.RelativePlacement(columnIndex: 0, columnSpan: 1, totalColumns: 1)
        return columnWidth * CGFloat(placement.columnSpan) / CGFloat(placement.totalColumns)
    }

    @ViewBuilder
    private func calendarItemBlocksView() -> some View {
        let placements = relativePlacements
        ZStack(alignment: .topLeading) {
            // Drop-in placeholder view
            if let dragInfo = interactionHandler.draggingSessionInfo,
               let targetTime = interactionHandler.dropTargetTime,
               Calendar.current.isDate(targetTime, inSameDayAs: day) {
                
                let placeholder = layoutEngine.placeholderCenter(for: targetTime, duration: dragInfo.duration)
                let calculatedHeight = placeholder.height
                let centerX = placeholder.centerX
                let centerY = placeholder.centerY
                
                DropPlaceholderView(height: calculatedHeight, time: viewModel.formatTime(targetTime))
                    .offset(x: centerX - layoutEngine.metrics.contentWidth / 2, y: centerY - calculatedHeight / 2)
            }

            CalendarItemLayout(hourHeight: effectiveHourHeight, relativePlacements: placements) {
                let culledItems = items.filter { item in
                    let itemStart = CGFloat(item.startHour)
                    let itemEnd = itemStart + CGFloat(item.durationHours)
                    return itemEnd >= visibleHourRange.lowerBound && itemStart <= visibleHourRange.upperBound
                }
                
                ForEach(culledItems) { item in
                    let isBeingDragged = interactionHandler.draggingSessionInfo?.sessionID == (item.underlyingSession?.id.uuidString ?? item.id)
                    CalendarItemBlockView(
                        item: item,
                        viewModel: viewModel,
                        interactionHandler: interactionHandler,
                        hourHeight: effectiveHourHeight,
                        slotWidth: slotWidth(for: item.id)
                    )
                    .equatable()
                    .layoutValue(key: CalendarItemKey.self, value: CalendarItemLayoutValue(item))
                    .accessibilityIdentifier(item.id)
                    .opacity(isBeingDragged ? 0.4 : 1.0)
                    .allowsHitTesting(!isBeingDragged)
                }
            }
        }
        .frame(width: columnWidth, height: 24 * effectiveHourHeight, alignment: .topLeading)
        .background(Color.primary.opacity(0.0001)) // Ensure it captures clicks
        .contentShape(Rectangle())
    }

    // Background color for the column
    private var columnBackground: some View {
        let isDropTarget = isDropTargeted && interactionHandler.draggingSessionInfo != nil
        return Rectangle()
            .fill(
                isDropTarget ? Color.accentColor.opacity(0.15) :
                (isToday ? Color.accentColor.opacity(0.04) :
                 (isWeekend ? Color.black.opacity(0.08) : Color.clear))
            )
    }

    // Border for the column
    private var columnBorder: some View {
        ZStack {
            if isToday {
                // Today has a full highlight border around it
                Rectangle()
                    .stroke(Color.accentColor.opacity(0.4), lineWidth: 1.5)
            } else {
                // Regular column has only a trailing divider line
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: StyleGuide.Dimensions.hairlineWidth)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Placeholder Structs and Views for Dragging

private struct PlaceholderCalendarItem: Identifiable {
    var id: String
    var startDate: Date
    var duration: TimeInterval
}

private struct DropPlaceholderView: View {
    var height: CGFloat
    var time: String
    
    @ScaledMetric(relativeTo: .body) private var paddingXSmall: CGFloat = StyleGuide.Dimensions.paddingXSmall
    @ScaledMetric(relativeTo: .body) private var cornerRadiusSmall: CGFloat = StyleGuide.Dimensions.cornerRadiusSmall

    var body: some View {
        HStack(spacing: 6) {
            Text(time)
                .font(StyleGuide.Typography.caption.weight(.semibold))
                .foregroundColor(.accentColor)
                .padding(.leading, 8)
            
            Spacer()
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: cornerRadiusSmall)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .background(Color.accentColor.opacity(StyleGuide.Opacity.light).cornerRadius(cornerRadiusSmall))
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, paddingXSmall)
        .fluidTransition()
        .zIndex(0) // Ensure it's behind the actual items
    }
}

struct DayColumnDropDelegate: DropDelegate {
    let day: Date
    let viewModel: CalendarViewModel
    let interactionHandler: CalendarInteractionHandler
    let effectiveHourHeight: CGFloat
    @Binding var isTargeted: Bool

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.calendarSessionDragType])
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        let newTargetTime = calculateTargetTime(from: info.location)
        if interactionHandler.dropTargetTime != newTargetTime {
            interactionHandler.dropTargetTime = newTargetTime
        }
        if interactionHandler.draggingSessionInfo == nil,
           let provider = info.itemProviders(for: [.calendarSessionDragType]).first {
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
        return DropProposal(operation: .move)
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
        // Clear the placeholder when exiting
        interactionHandler.dropTargetTime = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        let newStartDate = calculateTargetTime(from: info.location)
        
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
                            isAllDay: false
                        )
                    }
                case .failure(let error):
                    print("Failed to load drag payload: \(error)")
                }
                interactionHandler.draggingSessionInfo = nil
                interactionHandler.dropTargetTime = nil
            }
        }
        
        return true
    }
    
    private func calculateTargetTime(from location: CGPoint) -> Date {
        let dropY = location.y
        let hourFraction = max(0, dropY / effectiveHourHeight)
        
        // Snap to 5-minute intervals
        let totalMinutes = hourFraction * 60
        let snappedMinutes = (totalMinutes / 5).rounded() * 5
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = Int(snappedMinutes / 60)
        components.minute = Int(snappedMinutes.truncatingRemainder(dividingBy: 60))

        return calendar.date(from: components) ?? day
    }
} 
