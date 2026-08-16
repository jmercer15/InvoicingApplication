import SwiftUI
import SharedUI
import Observation

// ─────────────────────────────────────────────────────────────
// MARK: - Week Header Bar View
// ─────────────────────────────────────────────────────────────

struct WeekHeaderView: View {
    @Bindable var viewModel: CalendarViewModel
    let timeColumnWidth: CGFloat
    let dayColumnWidth: CGFloat

    @ScaledMetric(relativeTo: .body) private var headerHeight: CGFloat = 42

    var body: some View {
        HStack(spacing: 0) {
            // Placeholder for the time column
            Color.clear
                .frame(width: timeColumnWidth, height: headerHeight)
                .overlay(CalendarHeaderColumnDivider(), alignment: .trailing)

            // Day headers
            ForEach(viewModel.currentWeekDayIdentities) { identity in
                DayHeaderItemView(day: identity.resolvedDate())
                    .frame(width: dayColumnWidth)
                    .overlay(CalendarHeaderColumnDivider(), alignment: .trailing)
            }
        }
        .background {
            CalendarHeaderBarBackground()
        }
        .overlay(
            CalendarHeaderBottomHairline(fill: Color.secondary.opacity(0.2)),
            alignment: .bottom
        )
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Individual Day Header Item
// ─────────────────────────────────────────────────────────────

struct DayHeaderItemView: View {
    let day: Date

    @ScaledMetric(relativeTo: .body) private var textFontSizeOfWeek: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var textFontSizeOfNumber: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var numberCircleSize: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var headerHeight: CGFloat = 42

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    private var dayOfWeekString: String {
        DateFormatting.weekdayAbbreviation(day)
    }
    private var dayNumberString: String {
        DateFormatting.dayNumber(day)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(dayOfWeekString)
                .font(CalendarTypography.headerWeekday(size: textFontSizeOfWeek, isToday: isToday))
                .foregroundStyle(isToday ? Color.accentColor : StyleGuide.Colors.text)

            Text(dayNumberString)
                .font(CalendarTypography.headerDayNumber(size: textFontSizeOfNumber, isToday: isToday))
                .foregroundStyle(isToday ? Color.white : StyleGuide.Colors.textSecondary)
                .frame(width: numberCircleSize, height: numberCircleSize)
                .background {
                    if isToday {
                        Circle()
                            .fill(Color.accentColor)
                    }
                }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .frame(height: headerHeight)
    }
} 
