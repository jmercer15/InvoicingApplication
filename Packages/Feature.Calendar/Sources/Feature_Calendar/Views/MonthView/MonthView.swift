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
                .foregroundStyle(StyleGuide.Colors.textSecondary.opacity(0.3))
                .padding(.top, StyleGuide.Dimensions.paddingSmall)
                .padding(.trailing, StyleGuide.Dimensions.paddingMedium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .overlay(
            // Top border (for all rows to maintain grid structure)
            Rectangle()
                .frame(width: nil, height: StyleGuide.Dimensions.hairlineWidth)
                .foregroundStyle(StyleGuide.Colors.border.opacity(0.2)),
            alignment: .top
        )
        .overlay(
            // Left border (only for first column)
            dayIndex == 0 ? Rectangle()
                .frame(width: StyleGuide.Dimensions.hairlineWidth, height: nil)
                .foregroundStyle(StyleGuide.Colors.border.opacity(0.2)) : nil,
            alignment: .leading
        )
        .overlay(
            // Right border (only for last column to complete grid outline)
            dayIndex == 6 ? Rectangle()
                .frame(width: StyleGuide.Dimensions.hairlineWidth, height: nil)
                .foregroundStyle(StyleGuide.Colors.border.opacity(0.2)) : nil,
            alignment: .trailing
        )
        .overlay(
            // Bottom border (for all rows to maintain grid structure)
            Rectangle()
                .frame(width: nil, height: StyleGuide.Dimensions.hairlineWidth)
                .foregroundStyle(StyleGuide.Colors.border.opacity(0.2)),
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

    private func dayNumber(for date: Date) -> String {
        DateFormatting.dayNumber(date)
    }
}
