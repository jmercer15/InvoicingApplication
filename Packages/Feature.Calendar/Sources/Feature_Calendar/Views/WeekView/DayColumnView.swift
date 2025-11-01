import SwiftUI
import SharedUI


// ─────────────────────────────────────────────────────────────
// MARK: - Day Column View (Container for Hours & Items)
// ─────────────────────────────────────────────────────────────

struct DayColumnView: View {
    let day: Date
    let items: [DisplayableCalendarItem]
    @ObservedObject var viewModel: CalendarViewModel
    let columnWidth: CGFloat
    let effectiveHourHeight: CGFloat

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

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            hourGridView()
            calendarItemBlocksView()
            
            // --- Visual guide for resizing ---
            if let resizeInfo = viewModel.interactionHandler.resizingSessionInfo,
               let resizePreviewDate = viewModel.interactionHandler.resizePreviewDate {
                
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

                        Text(viewModel.formatTime(for: resizePreviewDate))
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
                            .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                            .background(Color.accentColor)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                            .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
                            .offset(x: 5, y: yOffset - 12)
                            .zIndex(21)
                            .allowsHitTesting(false)
                    }
                    .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: yOffset)
                }
            }
        }
        .frame(height: CGFloat(hours.count) * effectiveHourHeight)
        .frame(width: columnWidth)
        .background(columnBackground)
        .overlay(columnBorder)
        .onHover { hovering in isHovering = hovering }
        .onDrop(of: [.text], delegate: DayColumnDropDelegate(day: day, viewModel: viewModel, effectiveHourHeight: effectiveHourHeight, isTargeted: $isHovering))
    }

    // Builds the grid lines for the hours
    @ViewBuilder
    private func hourGridView() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                hourGridLines(hour: hour)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // View for a single hour cell's grid lines
    @ViewBuilder
    private func hourGridLines(hour: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hour line
            Rectangle()
                .fill(Color.secondary.opacity(hour % 3 == 0 ? 0.08 : 0.05))
                .frame(height: 1)

            // Half-hour line space and line
            Spacer().frame(height: effectiveHourHeight / 2 - 1)
            Rectangle()
                .fill(Color.secondary.opacity(0.03))
                .frame(height: 1)
            // Implicit Spacer fills the rest
        }
        .frame(height: effectiveHourHeight, alignment: .topLeading)
    }

    // Builds the overlay containing the actual calendar item blocks
    @ViewBuilder
    private func calendarItemBlocksView() -> some View {
        // Use .topLeading alignment for the ZStack holding the positioned items
        ZStack(alignment: .topLeading) {
            // Drop-in placeholder view
            if let dragInfo = viewModel.interactionHandler.draggingSessionInfo,
               let targetTime = viewModel.interactionHandler.dropTargetTime,
               Calendar.current.isDate(targetTime, inSameDayAs: day) {
                
                let _ = PlaceholderCalendarItem(
                    id: dragInfo.sessionID,
                    startDate: targetTime,
                    duration: dragInfo.duration
                )
                
                let placeholder = layoutEngine.placeholderCenter(for: targetTime, duration: dragInfo.duration)
                let calculatedHeight = placeholder.height
                let centerX = placeholder.centerX
                let centerY = placeholder.centerY
                
                DropPlaceholderView(height: calculatedHeight, time: viewModel.formatTime(for: targetTime))
                    .position(x: centerX, y: centerY)
                    .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: targetTime)
            }

            ForEach(items) { item in
                // Hide the original view of the item being dragged
                let isBeingDragged = viewModel.interactionHandler.draggingSessionInfo?.sessionID == item.id
                if !isBeingDragged {
                // Calculate position for this specific item here
                let positioned = layoutEngine.positionedBlock(for: item)
                let _ = positioned.width
                let _ = positioned.height
                let centerX = positioned.centerX
                let centerY = positioned.centerY
                
                CalendarItemBlockView(
                    item: item,
                    viewModel: viewModel,
                    hourHeight: effectiveHourHeight,
                    columnWidth: columnWidth
                )
                // Apply position modifier here
                .position(x: centerX, y: centerY)
                }
            }
            .onAppear {
                // Original debug print
                print("[DayColumnView] for \(day.formatted(date: .numeric, time: .omitted)) got \(items.count) timed unified items.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.0001)) // Ensure it captures clicks
        .onTapGesture(coordinateSpace: .local) { location in

        }

    }

    // Background color for the column
    private var columnBackground: some View {
        let isDropTarget = isHovering && viewModel.interactionHandler.draggingSessionInfo != nil
        return Rectangle()
            .fill(
                isDropTarget ? Color.accentColor.opacity(0.15) :
                (isToday ? Color.accentColor.opacity(0.04) : 
                 (isWeekend ? Color.black.opacity(0.08) : Color.clear))
            )
            .animation(.easeOut(duration: 0.2), value: isDropTarget || isToday)
    }

    // Border for the column
    private var columnBorder: some View {
        Rectangle()
            .stroke(
                isToday
                    ? Color.accentColor.opacity(0.4)
                    : Color.secondary.opacity(0.3),
                lineWidth: isToday || isHovering ? 1 : 0.5
            )
            .frame(maxWidth: .infinity)
            .animation(.easeOut(duration: 0.2), value: isHovering)
    }
}

// MARK: - Placeholder Structs and Views for Dragging

private struct PlaceholderCalendarItem: Identifiable {
    var id: String
    var startDate: Date
    var duration: TimeInterval

    var startHour: CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: startDate)
        let minute = calendar.component(.minute, from: startDate)
        return CGFloat(hour) + CGFloat(minute) / 60.0
    }

    var durationHours: CGFloat {
        return CGFloat(duration / 3600.0)
    }
}

private struct DropPlaceholderView: View {
    var height: CGFloat
    var time: String
    
    var body: some View {
        HStack(spacing: 6) {
            Text(time)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.accentColor)
                .padding(.leading, 8)
            
            Spacer()
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .background(Color.accentColor.opacity(StyleGuide.Opacity.light).cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall))
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, StyleGuide.Dimensions.paddingXSmall)
        .fluidTransition()
        .zIndex(0) // Ensure it's behind the actual items
    }
}

struct DayColumnDropDelegate: DropDelegate {
    let day: Date
    let viewModel: CalendarViewModel
    let effectiveHourHeight: CGFloat
    @Binding var isTargeted: Bool

    func validateDrop(info: DropInfo) -> Bool {
        // A more robust solution would use a custom UTI.
        return info.hasItemsConforming(to: [.text])
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        let newTargetTime = calculateTargetTime(from: info.location)
        DispatchQueue.main.async {
            viewModel.interactionHandler.dropTargetTime = newTargetTime
        }
        return DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
        // Clear the placeholder when exiting
        viewModel.interactionHandler.dropTargetTime = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        let newStartDate = calculateTargetTime(from: info.location)
        
        // Finalize the drop
        if let draggedItem = viewModel.interactionHandler.draggingSessionInfo {
            viewModel.rescheduleSession(
                with: draggedItem.sessionID,
                originalInstanceDate: draggedItem.originalInstanceDate,
                to: newStartDate,
                isAllDay: false
            )
        }
        
        // Reset dragging state
        viewModel.interactionHandler.draggingSessionInfo = nil
        viewModel.interactionHandler.dropTargetTime = nil
        
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
