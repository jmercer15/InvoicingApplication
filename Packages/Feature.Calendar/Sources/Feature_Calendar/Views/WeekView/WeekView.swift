import SwiftUI
import Observation
import SharedUI

import EventKit // Import EventKit

// ─────────────────────────────────────────────────────────────
// MARK: - Main Week View Structure
// ─────────────────────────────────────────────────────────────

struct WeekView: View {
    @Bindable var viewModel: CalendarViewModel
    @State private var interactionHandler = CalendarInteractionHandler()

    @ScaledMetric(relativeTo: .body) private var timeColumnWidth: CGFloat = 50
    @ScaledMetric(relativeTo: .body) private var headerHeight: CGFloat = 42
    @ScaledMetric(relativeTo: .body) private var indicatorCircleSize: CGFloat = 6
    @ScaledMetric(relativeTo: .body) private var gridCornerRadius: CGFloat = 20

    // ════════════════════════════════════════════════════════
    // MARK: Body
    // ════════════════════════════════════════════════════════

    var body: some View {
        GeometryReader { gridGeo in
            let layout = WeekViewLayoutMetrics(
                gridSize: gridGeo.size,
                timeColumnWidth: timeColumnWidth,
                headerHeight: headerHeight,
                allDayStripHeight: viewModel.display.allDayStripHeight,
                configuredHourHeight: viewModel.hourHeight
            )

            HStack(spacing: 0) {
                weekGrid(layout: layout)
                    .layoutPriority(1)
            }
            .clipped()
        }
    }

    // ════════════════════════════════════════════════════════
    // MARK: Grid Content View Builder
    // ════════════════════════════════════════════════════════

    @ViewBuilder
    private func weekGrid(layout: WeekViewLayoutMetrics) -> some View {
        VStack(spacing: 0) {
            WeekHeaderView(viewModel: viewModel, timeColumnWidth: layout.timeColumnWidth, dayColumnWidth: layout.dayColumnWidth)
            AllDayStripView(
                viewModel: viewModel,
                interactionHandler: interactionHandler,
                timeColumnWidth: layout.timeColumnWidth,
                dayColumnWidth: layout.dayColumnWidth
            )

            ScrollableWeekGrid(
                viewModel: viewModel,
                interactionHandler: interactionHandler,
                timeColumnWidth: layout.timeColumnWidth,
                dayColumnWidth: layout.dayColumnWidth,
                availW: layout.availableWidth,
                scrollableAreaHeight: layout.scrollableAreaHeight,
                finalEffectiveHourHeight: layout.finalEffectiveHourHeight,
                indicatorCircleSize: indicatorCircleSize
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: gridCornerRadius))
    }
}

private struct WeekViewLayoutMetrics {
    let timeColumnWidth: CGFloat
    let dayColumnWidth: CGFloat
    let availableWidth: CGFloat
    let scrollableAreaHeight: CGFloat
    let finalEffectiveHourHeight: CGFloat

    init(
        gridSize: CGSize,
        timeColumnWidth: CGFloat,
        headerHeight: CGFloat,
        allDayStripHeight: CGFloat,
        configuredHourHeight: CGFloat
    ) {
        self.timeColumnWidth = timeColumnWidth
        availableWidth = max(0, gridSize.width)
        dayColumnWidth = max(50, (availableWidth - timeColumnWidth) / 7)

        let scrollableHeight = max(0, gridSize.height - headerHeight - allDayStripHeight)
        scrollableAreaHeight = scrollableHeight
        let minHourHeight = scrollableHeight / 24.0
        let effectiveHourHeight = max(configuredHourHeight, minHourHeight)
        finalEffectiveHourHeight = max(10, effectiveHourHeight)
    }
}

private struct ScrollableWeekGrid: View {
    let viewModel: CalendarViewModel
    let interactionHandler: CalendarInteractionHandler
    let timeColumnWidth: CGFloat
    let dayColumnWidth: CGFloat
    let availW: CGFloat
    let scrollableAreaHeight: CGFloat
    let finalEffectiveHourHeight: CGFloat
    let indicatorCircleSize: CGFloat
    
    @State private var visibleHourRange: ClosedRange<CGFloat> = 0...24

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical], showsIndicators: false) {
                VStack(spacing: 0) {
                    let currentDate = Date()
                    let weekIdentities = viewModel.currentWeekDayIdentities
                    let showIndicator = weekIdentities.contains { identity in
                        Calendar.current.isDate(identity.resolvedDate(), inSameDayAs: currentDate)
                    }
                    
                    // Use finalEffectiveHourHeight for calculations
                    let currentHour = CGFloat(Calendar.current.component(.hour, from: currentDate))
                    let currentMinute = CGFloat(Calendar.current.component(.minute, from: currentDate))
                    let fractionalHour = currentHour + currentMinute / 60.0
                    let yOffset = fractionalHour * finalEffectiveHourHeight
                    
                    HStack(spacing: 0) {
                        // Pass finalEffectiveHourHeight down
                        TimeColumnView(viewModel: viewModel, width: timeColumnWidth, effectiveHourHeight: finalEffectiveHourHeight)
                        ZStack(alignment: .topLeading) {
                            GlobalHourGridView(effectiveHourHeight: finalEffectiveHourHeight, width: dayColumnWidth * 7)
                                .allowsHitTesting(false)
                            HStack(spacing: 0) {
                                ForEach(weekIdentities) { identity in
                                    let day = identity.resolvedDate()
                                    // Pass finalEffectiveHourHeight down
                                    DayColumnView(
                                        day: day,
                                        items: viewModel.getTimedItems(for: day),
                                        viewModel: viewModel,
                                        interactionHandler: interactionHandler,
                                        columnWidth: dayColumnWidth,
                                        effectiveHourHeight: finalEffectiveHourHeight,
                                        visibleHourRange: visibleHourRange
                                    )
                                }
                            }
                        }
                    }
                    .frame(width: availW) // Constrain the HStack width (non-negative)
                    .overlay(alignment: .topLeading) {
                        if showIndicator {
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(ColorSystem.Status.error)
                                    .frame(width: max(0, availW - timeColumnWidth), height: 1)
                                    .offset(x: timeColumnWidth)
                                
                                Circle()
                                    .fill(ColorSystem.Status.error)
                                    .frame(width: indicatorCircleSize, height: indicatorCircleSize)
                                    .offset(x: timeColumnWidth - indicatorCircleSize / 2)
                            }
                            .offset(y: yOffset - indicatorCircleSize / 2) 
                            .zIndex(100) 
                            .allowsHitTesting(false) 
                        }
                    }
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, contentOffsetY in
                // ScrollGeometry reports a positive content offset while scrolling down.
                // Keep timeline coordinates in that same space so items below midnight
                // remain in the visible range.
                let topY = max(0, contentOffsetY)
                let bottomY = topY + scrollableAreaHeight
                let startHour = max(0, topY / finalEffectiveHourHeight)
                let endHour = min(24, bottomY / finalEffectiveHourHeight)

                let buffer: CGFloat = 2.0
                let newRange = max(0, startHour - buffer)...min(24, endHour + buffer)
                if abs(newRange.lowerBound - visibleHourRange.lowerBound) > 1 ||
                   abs(newRange.upperBound - visibleHourRange.upperBound) > 1 {
                    visibleHourRange = newRange
                }
            }
            .frame(height: scrollableAreaHeight)
            .padding(StyleGuide.Dimensions.zeroPadding)
            .onAppear {
                let currentHour = Calendar.current.component(.hour, from: Date())
                let scrollTarget = max(0, currentHour - 2)
                Task { @MainActor in
                    proxy.scrollTo(scrollTarget, anchor: .top)
                }
            }
        }
    }
}

struct GlobalHourGridView: View {
    let effectiveHourHeight: CGFloat
    let width: CGFloat

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = effectiveHourHeight
            
            for hour in 0..<24 {
                let y = CGFloat(hour) * h
                
                // Hour line
                var hourPath = Path()
                hourPath.move(to: CGPoint(x: 0, y: y))
                hourPath.addLine(to: CGPoint(x: w, y: y))
                
                let isMajor = hour % 3 == 0
                context.stroke(
                    hourPath,
                    with: .color(.secondary.opacity(isMajor ? 0.08 : 0.05)),
                    lineWidth: 1
                )
                
                // Half-hour line
                let halfY = y + (h / 2)
                var halfPath = Path()
                halfPath.move(to: CGPoint(x: 0, y: halfY))
                halfPath.addLine(to: CGPoint(x: w, y: halfY))
                
                context.stroke(
                    halfPath,
                    with: .color(.secondary.opacity(0.03)),
                    lineWidth: 1
                )
            }
        }
        .frame(width: width, height: 24 * effectiveHourHeight)
        .allowsHitTesting(false)
    }
}
