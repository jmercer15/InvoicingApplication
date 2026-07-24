import SwiftUI
import SharedUI
import Observation

import EventKit

// ─────────────────────────────────────────────────────────────
// MARK: - Main Month View Structure
// ─────────────────────────────────────────────────────────────

struct MonthView: View {
    @Bindable var viewModel: CalendarViewModel
    var precomputedWeeks: [[Date?]]? = nil
    
    // Access precomputed weeks if provided; otherwise fall back to ViewModel
    private var weeks: [[Date?]] { precomputedWeeks ?? [] }

    var body: some View {
        HStack(spacing: 0) {
            // Main month grid/content with optimized styling
            monthGrid()
                .layoutPriority(1)
        }
        .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge + 4))
    }

    // ════════════════════════════════════════════════════════
    // MARK: Grid Content View Builder
    // ════════════════════════════════════════════════════════

    @ViewBuilder
    private func monthGrid() -> some View {
        GeometryReader { geometry in
            // Calculate dimensions similar to WeekView approach
            let headerHeight: CGFloat = 42
            let availableHeight = max(0, geometry.size.height - headerHeight) // Account for header only
            let weekHeight = max(50, availableHeight / CGFloat(weeks.count)) // Ensure minimum height

            VStack(spacing: 0) {
                // Use extracted header view with consistent styling
                MonthHeaderView(viewModel: viewModel)
                    .frame(height: headerHeight)

                // Main month grid content
                monthGridView(weekHeight: weekHeight)
            }
            .clipped() // Ensure content doesn't overflow the bounds
        }
    }

    // Builds the main grid of week rows
    @ViewBuilder
    private func monthGridView(weekHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Use the weeks property derived from the ViewModel
            ForEach(weeks.indices, id: \.self) { weekIndex in
                weekRowView(weekIndex: weekIndex, week: weeks[weekIndex])
                    .frame(height: weekHeight)
            }
        }
    }

    // Builds a single row (week) in the grid
    @ViewBuilder
    private func weekRowView(weekIndex: Int, week: [Date?]) -> some View {
        HStack(spacing: 0) { // Use 0 spacing for seamless cells
            ForEach(0..<7, id: \.self) { dayIndex in
                if let date = week[dayIndex] {
                    dayCellView(date: date, weekIndex: weekIndex, dayIndex: dayIndex)
                } else {
                    emptyDayCellView(weekIndex: weekIndex, dayIndex: dayIndex)
                }
            }
        }
    }

    // Builds a single day cell, passing necessary data
    @ViewBuilder
    private func dayCellView(date: Date, weekIndex: Int, dayIndex: Int) -> some View {
        MonthDayCellView(
            date: date,
            viewModel: viewModel,
            weekIndex: weekIndex,
            dayIndex: dayIndex,
            isLastWeek: weekIndex == weeks.count - 1
        )
    }

    // Placeholder for empty cells outside the current month
    @ViewBuilder
    private func emptyDayCellView(weekIndex: Int, dayIndex: Int) -> some View {
        let cellDate = dateForCell(weekIndex: weekIndex, dayIndex: dayIndex)
        let numStr = dayNumber(for: cellDate)
        
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(StyleGuide.Colors.textSecondary.opacity(StyleGuide.Opacity.subtle))
            
            Text(numStr)
                .font(StyleGuide.Typography.gridDayNumber)
                .foregroundColor(StyleGuide.Colors.textSecondary.opacity(0.3))
                .padding(.top, StyleGuide.Dimensions.paddingSmall)
                .padding(.trailing, StyleGuide.Dimensions.paddingMedium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .overlay(
            // Top border (for all rows to maintain grid structure)
            Rectangle()
                .frame(width: nil, height: StyleGuide.Dimensions.hairlineWidth)
                .foregroundColor(StyleGuide.Colors.border.opacity(0.2)),
            alignment: .top
        )
        .overlay(
            // Left border (only for first column)
            dayIndex == 0 ? Rectangle()
                .frame(width: StyleGuide.Dimensions.hairlineWidth, height: nil)
                .foregroundColor(StyleGuide.Colors.border.opacity(0.2)) : nil,
            alignment: .leading
        )
        .overlay(
            // Right border (only for last column to complete grid outline)
            dayIndex == 6 ? Rectangle()
                .frame(width: StyleGuide.Dimensions.hairlineWidth, height: nil)
                .foregroundColor(StyleGuide.Colors.border.opacity(0.2)) : nil,
            alignment: .trailing
        )
        .overlay(
            // Bottom border (for all rows to maintain grid structure)
            Rectangle()
                .frame(width: nil, height: StyleGuide.Dimensions.hairlineWidth)
                .foregroundColor(StyleGuide.Colors.border.opacity(0.2)),
            alignment: .bottom
        )
    }

    private func dateForCell(weekIndex: Int, dayIndex: Int) -> Date {
        let calendar = Calendar.current
        let month = viewModel.selectedDate.startOfMonth
        let firstDayOfMonthWeekday = calendar.component(.weekday, from: month)
        let firstWeekday = calendar.firstWeekday
        let daysToPrepend = (firstDayOfMonthWeekday - firstWeekday + 7) % 7
        guard let gridStartDate = calendar.date(byAdding: .day, value: -daysToPrepend, to: month) else {
            return viewModel.selectedDate
        }
        let offsetDays = weekIndex * 7 + dayIndex
        return calendar.date(byAdding: .day, value: offsetDays, to: gridStartDate) ?? gridStartDate
    }

    private static let dayNumberFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private func dayNumber(for date: Date) -> String {
        return Self.dayNumberFormatter.string(from: date)
    }
}

// MARK: - RoundedCorner Shape
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: Corner = .allCorners

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0
        
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight), radius: topRight, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        path.addArc(center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight), radius: bottomRight, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft), radius: bottomLeft, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        path.addArc(center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft), radius: topLeft, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Corner OptionSet
struct Corner: OptionSet {
    let rawValue: Int
    
    static let topLeft = Corner(rawValue: 1 << 0)
    static let topRight = Corner(rawValue: 1 << 1)
    static let bottomLeft = Corner(rawValue: 1 << 2)
    static let bottomRight = Corner(rawValue: 1 << 3)
    static let allCorners: Corner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}
