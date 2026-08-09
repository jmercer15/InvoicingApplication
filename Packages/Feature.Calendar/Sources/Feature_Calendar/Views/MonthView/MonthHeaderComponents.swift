import SwiftUI
import SharedUI
import Observation

// ─────────────────────────────────────────────────────────────
// MARK: - Month Header View (Displays Weekday Names)
// ─────────────────────────────────────────────────────────────

struct MonthHeaderView: View {
    @Bindable var viewModel: CalendarViewModel // Needed to get currentWeekDays for layout

    var body: some View {
        HStack(spacing: 0) {
            // Iterate over the days of the week to display headers
            ForEach(viewModel.currentWeekDays.indices, id: \.self) { index in
                let day = viewModel.currentWeekDays[index] // Use a representative day
                MonthDayHeaderItemView(day: day)
                    .frame(maxWidth: .infinity)
                    // Add left border to all but the first day header
                    .overlay(
                        index > 0 ?
                        Rectangle().frame(width: StyleGuide.Dimensions.hairlineWidth, height: nil).foregroundStyle(StyleGuide.Colors.border.opacity(0.3))
                        : nil // No border for the first item
                        , alignment: .leading
                    )
            }
        }
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: StyleGuide.Dimensions.cornerRadiusLarge + 4,
                topTrailingRadius: StyleGuide.Dimensions.cornerRadiusLarge + 4
            )
                .fill(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.strong))
        }
        // Add bottom border only to the day headers section
        .overlay(
            Rectangle().frame(width: nil, height: 1).foregroundStyle(StyleGuide.Colors.border.opacity(0.2)),
            alignment: .bottom
        )
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Individual Day Header Item (for Month View)
// ─────────────────────────────────────────────────────────────

struct MonthDayHeaderItemView: View {
    let day: Date // A representative date for the weekday

    private var isTodayWeekday: Bool {
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: Date())
        let dayWeekday = calendar.component(.weekday, from: day)
        return todayWeekday == dayWeekday
    }
    private var dayOfWeekString: String {
        DateFormatting.weekdayAbbreviation(day)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(dayOfWeekString)
                .font(StyleGuide.Typography.gridWeekday.weight(isTodayWeekday ? .bold : .semibold))
                .foregroundStyle(isTodayWeekday ? Color.accentColor : StyleGuide.Colors.text)
        }
        .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
    }
} 
