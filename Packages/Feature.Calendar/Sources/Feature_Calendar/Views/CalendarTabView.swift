import SwiftUI
import SwiftData
import EventKit
import SharedUI
import Observation

// MARK: - Enhanced TabView-based Calendar Container

/// A modern TabView implementation for calendar view switching that follows Apple's design guidelines.
/// 
/// This implementation provides:
/// - Native TabView with proper Tab and TabSection usage
/// - Full accessibility support with labels, hints, and traits
/// - Smooth animations and haptic feedback
/// - Custom tab bar styling with material effects
/// - Automatic tab bar placement and minimize behavior
/// - Bidirectional synchronization with the view model
///
/// The TabView automatically adapts to different screen sizes and orientations,
/// providing an optimal user experience across all Apple platforms.
struct CalendarTabView: View {
    @Bindable var viewModel: CalendarViewModel
    @State private var monthGridWeeks: [[Date?]] = []
    private let monthGridProvider = CalendarDisplayDataProvider()

    private var monthGridTaskID: Date {
        viewModel.selectedDate.startOfMonth
    }

    var body: some View {
        Group {
            switch viewModel.calendarViewType {
            case .week:
                WeekView(viewModel: viewModel)
                    .transition(.opacity)
            case .month:
                MonthView(viewModel: viewModel, precomputedWeeks: monthGridWeeks)
                    .transition(.opacity)
            }
        }
        .task(id: monthGridTaskID) {
            guard viewModel.calendarViewType == .month else { return }
            monthGridWeeks = monthGridProvider.buildMonthGridWeeks(for: viewModel.selectedDate)
        }
        .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: viewModel.calendarViewType)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Calendar view container")
    }
}

// MARK: - Preview
#Preview {
    // Preview intentionally disabled while Calendar wiring is being modernized.
    EmptyView()
}
