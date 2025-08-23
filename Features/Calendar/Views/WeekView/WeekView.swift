import SwiftUI

import EventKit // Import EventKit

// ─────────────────────────────────────────────────────────────
// MARK: - Main Week View Structure
// ─────────────────────────────────────────────────────────────

struct WeekView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var showInspector: Bool

    // ════════════════════════════════════════════════════════
    // MARK: Body
    // ════════════════════════════════════════════════════════

    var body: some View {
        HStack(spacing: 0) {
            // Main week grid with optimized styling
            weekGrid()
                .background(
                    // Match TimelineView's layered glass/gradient background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.04),
                                    Color.white.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
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
                                    lineWidth: 1.5
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.blue.opacity(0.12),
                                            Color.purple.opacity(0.08),
                                            Color.indigo.opacity(0.04),
                                            Color.clear
                                        ],
                                        center: .topLeading,
                                        startRadius: 0,
                                        endRadius: 250
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.02),
                                            Color.clear,
                                            Color.white.opacity(0.01)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
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
        .padding(16)
        .clipped()
    }

    // ════════════════════════════════════════════════════════
    // MARK: Grid Content View Builder
    // ════════════════════════════════════════════════════════

    @ViewBuilder
    private func weekGrid() -> some View {
        GeometryReader { gridGeo in
            let timeW: CGFloat = 50
            // Account for the padding we added (8 points on each side)
            let availW = max(0, gridGeo.size.width - 16) // Clamp to non-negative
            let colW = max(50, (availW - timeW) / 7)
            
            // Calculate effective hour height
            let headerHeight: CGFloat = 42
            let allDayStripHeight: CGFloat = 40
            let scrollableAreaHeight = max(0, gridGeo.size.height - headerHeight - allDayStripHeight - 16) // Account for header, all-day strip, and padding
            let minHourHeight = scrollableAreaHeight / 24.0
            let effectiveHourHeight = max(viewModel.hourHeight, minHourHeight)
            // Ensure effectiveHourHeight is at least a sensible minimum (e.g., 10) to avoid visual glitches
            let finalEffectiveHourHeight = max(10, effectiveHourHeight)

            VStack(spacing: 0) {
                WeekHeaderView(viewModel: viewModel, timeColumnWidth: timeW, dayColumnWidth: colW)
                AllDayStripView(viewModel: viewModel, timeColumnWidth: timeW, dayColumnWidth: colW)

                ScrollView([.vertical], showsIndicators: false) {
                    VStack(spacing: 0) {
                        let currentDate = Date()
                        let showIndicator = viewModel.currentWeekDays.contains { day in
                            Calendar.current.isDate(day, inSameDayAs: currentDate)
                        }
                        
                        // Use finalEffectiveHourHeight for calculations
                        let currentHour = CGFloat(Calendar.current.component(.hour, from: currentDate))
                        let currentMinute = CGFloat(Calendar.current.component(.minute, from: currentDate))
                        let fractionalHour = currentHour + currentMinute / 60.0
                        let yOffset = fractionalHour * finalEffectiveHourHeight
                        
                        HStack(spacing: 0) {
                            // Pass finalEffectiveHourHeight down
                            TimeColumnView(viewModel: viewModel, width: timeW, effectiveHourHeight: finalEffectiveHourHeight)
                            ForEach(viewModel.currentWeekDays, id: \.self) { day in
                                // Pass finalEffectiveHourHeight down
                                DayColumnView(
                                    day: day,
                                    items: viewModel.getTimedItems(for: day),
                                    viewModel: viewModel,
                                    columnWidth: colW,
                                    effectiveHourHeight: finalEffectiveHourHeight
                                )
                            }
                        }
                        .frame(width: availW) // Constrain the HStack width (non-negative)
                        .overlay(alignment: .topLeading) {
                            if showIndicator {
                                ZStack(alignment: .leading) {
                                    Path { path in
                                        path.move(to: CGPoint(x: 0, y: 0))
                                        path.addLine(to: CGPoint(x: availW - timeW, y: 0))
                                    }
                                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                                    .fill(Color.red)
                                    .frame(width: max(0, availW - timeW), height: 1.5)
                                    .offset(x: timeW)
                                    
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: timeW - 4)
                                }
                                // Use yOffset calculated with finalEffectiveHourHeight
                                .offset(y: yOffset - 4) 
                                .zIndex(100) 
                                .allowsHitTesting(false) 
                            }
                        }
                    }
                }
                .padding(0)
            }
            .padding(8)
            .clipped() // Ensure content doesn't overflow the bounds
        }
    }
}
