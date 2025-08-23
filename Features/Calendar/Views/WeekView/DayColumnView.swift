import SwiftUI


// ─────────────────────────────────────────────────────────────
// MARK: - Day Column View (Container for Hours & Items)
// ─────────────────────────────────────────────────────────────

struct DayColumnView: View {
    let day: Date
    let items: [DisplayableCalendarItem]
    @ObservedObject var viewModel: CalendarViewModel
    let columnWidth: CGFloat
    let effectiveHourHeight: CGFloat

    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private let hours = Array(0...23)

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            hourGridView()
            calendarItemBlocksView()
            
            // --- RE-ADD: Visual guide for resizing ---
            if let resizeInfo = viewModel.resizingSessionInfo,
               let resizePreviewDate = viewModel.resizePreviewDate {
                
                let viewRange = viewModel.currentViewDateRange
                if Calendar.current.isDate(resizePreviewDate, inSameDayAs: day) &&
                   (resizeInfo.initialStartTime >= viewRange.start && resizeInfo.initialStartTime < viewRange.end) {

                    let yOffset = (CGFloat(Calendar.current.component(.hour, from: resizePreviewDate)) + CGFloat(Calendar.current.component(.minute, from: resizePreviewDate)) / 60.0) * effectiveHourHeight
                    
                    Group {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: yOffset))
                            path.addLine(to: CGPoint(x: columnWidth, y: yOffset))
                        }
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .zIndex(20)

                        Text(viewModel.formatTime(for: resizePreviewDate))
                            .font(.caption2.bold())
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                            .offset(x: 5, y: yOffset - 12)
                            .zIndex(21)
                            .allowsHitTesting(false)
                    }
                    .animation(.easeInOut(duration: 0.1), value: yOffset)
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
                .fill(Color.secondary.opacity(hour % 3 == 0 ? 0.25 : 0.15))
                .frame(height: 1)

            // Half-hour line space and line
            Spacer().frame(height: effectiveHourHeight / 2 - 1)
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
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
            if let dragInfo = viewModel.draggingSessionInfo,
               let targetTime = viewModel.dropTargetTime,
               Calendar.current.isDate(targetTime, inSameDayAs: day) {
                
                let placeholderItem = PlaceholderCalendarItem(
                    id: dragInfo.sessionID,
                    startDate: targetTime,
                    duration: dragInfo.duration
                )
                
                let topOffset = placeholderItem.startHour * effectiveHourHeight
                let calculatedHeight = max(10, placeholderItem.durationHours * effectiveHourHeight - 2)
                let centerX = (columnWidth - 10) / 2 + 5
                let centerY = topOffset + calculatedHeight / 2
                
                DropPlaceholderView(height: calculatedHeight, time: viewModel.formatTime(for: targetTime))
                    .position(x: centerX, y: centerY)
                    .animation(.easeInOut(duration: 0.1), value: targetTime)
            }

            ForEach(items) { item in
                // Hide the original view of the item being dragged
                let isBeingDragged = viewModel.draggingSessionInfo?.sessionID == item.id
                if !isBeingDragged {
                // Calculate position for this specific item here
                let itemIsEvent = item.isEvent
                let calculatedWidth = columnWidth - 10
                let calculatedHeight = max(10, item.durationHours * effectiveHourHeight - 2)
                let topOffset = item.startHour * effectiveHourHeight + (itemIsEvent ? 1 : 0)
                let centerX = 5 + calculatedWidth / 2
                let centerY = topOffset + calculatedHeight / 2
                
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
        let isDropTarget = isHovering && viewModel.draggingSessionInfo != nil
        return Rectangle()
            .fill(
                isDropTarget ? Color.accentColor.opacity(0.15) :
                (isToday ? Color.accentColor.opacity(0.04) : Color.clear)
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
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .background(Color.accentColor.opacity(0.1).cornerRadius(8))
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 5)
        .transition(.opacity.animation(.easeInOut))
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
            viewModel.dropTargetTime = newTargetTime
        }
        return DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
        // Clear the placeholder when exiting
        viewModel.dropTargetTime = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        let newStartDate = calculateTargetTime(from: info.location)
        
        // Finalize the drop
        if let draggedItem = viewModel.draggingSessionInfo {
            viewModel.rescheduleSession(
                with: draggedItem.sessionID,
                originalInstanceDate: draggedItem.originalInstanceDate,
                to: newStartDate,
                isAllDay: false
            )
        }
        
        // Reset dragging state
        viewModel.draggingSessionInfo = nil
        viewModel.dropTargetTime = nil
        
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
