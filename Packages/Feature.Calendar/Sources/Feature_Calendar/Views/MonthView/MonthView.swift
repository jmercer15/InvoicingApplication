import SwiftUI

import EventKit

// ─────────────────────────────────────────────────────────────
// MARK: - Main Month View Structure
// ─────────────────────────────────────────────────────────────

struct MonthView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var showInspector: Bool
    var precomputedWeeks: [[Date?]]? = nil
    
    // Access precomputed weeks if provided; otherwise fall back to ViewModel
    private var weeks: [[Date?]] { precomputedWeeks ?? viewModel.monthGridWeeks }

    var body: some View {
        HStack(spacing: 0) {
            // Main month grid/content with optimized styling
            monthGrid()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
                .shadow(
                    color: Color.black.opacity(0.15),
                    radius: 25,
                    x: 0,
                    y: 12
                )
                .shadow(
                    color: Color.blue.opacity(0.1),
                    radius: 15,
                    x: 0,
                    y: 6
                )
                .layoutPriority(1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
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
        .overlay( // Highlight selected day
            viewModel.isSelectedDay(date)
                ? RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.7), lineWidth: 2)
                : nil
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) { viewModel.selectedDate = date }
        }
    }

    // Placeholder for empty cells outside the current month
    @ViewBuilder
    private func emptyDayCellView(weekIndex: Int, dayIndex: Int) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.15)) // Consistent with WeekView styling
            .frame(maxWidth: .infinity)
            .background(
                RoundedCorner(
                    radius: 20,
                    corners: weekIndex == weeks.count - 1 ? 
                        (dayIndex == 0 ? .bottomLeft : dayIndex == 6 ? .bottomRight : []) : []
                )
                .fill(Color.black.opacity(0.15))
            )
            .overlay(
                // Top border (for all rows to maintain grid structure)
                Rectangle()
                    .frame(width: nil, height: 0.5)
                    .foregroundColor(Color.secondary.opacity(0.2)),
                alignment: .top
            )
            .overlay(
                // Left border (only for first column)
                dayIndex == 0 ? Rectangle()
                    .frame(width: 0.5, height: nil)
                    .foregroundColor(Color.secondary.opacity(0.2)) : nil,
                alignment: .leading
            )
            .overlay(
                // Right border (only for last column to complete grid outline)
                dayIndex == 6 ? Rectangle()
                    .frame(width: 0.5, height: nil)
                    .foregroundColor(Color.secondary.opacity(0.2)) : nil,
                alignment: .trailing
            )
            .overlay(
                // Bottom border (for all rows to maintain grid structure)
                Rectangle()
                    .frame(width: nil, height: 0.5)
                    .foregroundColor(Color.secondary.opacity(0.2)),
                alignment: .bottom
            )
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
