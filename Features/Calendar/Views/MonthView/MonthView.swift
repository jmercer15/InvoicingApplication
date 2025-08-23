import SwiftUI

import EventKit

// ─────────────────────────────────────────────────────────────
// MARK: - Main Month View Structure
// ─────────────────────────────────────────────────────────────

struct MonthView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var showInspector: Bool

    // Access the pre-calculated grid weeks from the ViewModel
    private var weeks: [[Date?]] { viewModel.monthGridWeeks }

    var body: some View {
        HStack(spacing: 0) {
            // Main month grid/content with optimized styling
            monthGrid()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 10,
                    x: 0,
                    y: 5
                )
                .layoutPriority(1)
        }
        .padding(16)
        .clipped()
    }

    @ViewBuilder
    private func monthGrid() -> some View {
        GeometryReader { geometry in
            VStack(spacing: 1) {
                // Use extracted header view
                MonthHeaderView(viewModel: viewModel)
                    .frame(height: 42) // Consistent height with WeekView header

                // Calculate height for week rows
                let availableHeight = geometry.size.height - 43 - 16 // 42 for header + 1 for spacing + 16 for padding
                let weekHeight = max(50, availableHeight / CGFloat(weeks.count)) // Ensure minimum height

                weeksGridView(weekHeight: weekHeight)
            }
            .padding(8)
        }
    }

    // Builds the main grid of week rows
    @ViewBuilder
    private func weeksGridView(weekHeight: CGFloat) -> some View {
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
                    dayCellView(date: date)
                } else {
                    emptyDayCellView()
                }
            }
        }
    }

    // Builds a single day cell, passing necessary data
    @ViewBuilder
    private func dayCellView(date: Date) -> some View {
        MonthDayCellView(
            date: date,
            viewModel: viewModel
        )
        .overlay( // Highlight selected day
            viewModel.isSelectedDay(date)
                ? RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.7), lineWidth: 2).padding(1)
                : nil
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) { viewModel.selectedDate = date }
        }
    }

    // Placeholder for empty cells outside the current month
    @ViewBuilder
    private func emptyDayCellView() -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.2)) // Use a distinguishable background for empty cells
            .frame(maxWidth: .infinity)
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)) // Subtle border
    }
}
