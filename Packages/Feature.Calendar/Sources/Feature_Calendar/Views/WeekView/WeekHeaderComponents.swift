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
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = StyleGuide.Dimensions.cornerRadiusLarge + 4

    var body: some View {
        HStack(spacing: 0) {
            // Placeholder for the time column
            Color.clear
                .frame(width: timeColumnWidth, height: headerHeight)
                .overlay(
                    Rectangle()
                        .fill(StyleGuide.Colors.border.opacity(0.2))
                        .frame(width: StyleGuide.Dimensions.hairlineWidth),
                    alignment: .trailing
                )

            // Day headers
            ForEach(viewModel.currentWeekDays.indices, id: \.self) { index in
                let day = viewModel.currentWeekDays[index]
                DayHeaderItemView(day: day)
                    .frame(width: dayColumnWidth)
                    .overlay(
                        Rectangle()
                            .fill(StyleGuide.Colors.border.opacity(0.2))
                            .frame(width: StyleGuide.Dimensions.hairlineWidth),
                        alignment: .trailing
                    )
            }
        }
        .background(
            UnevenRoundedRectangle(topLeadingRadius: cornerRadius, topTrailingRadius: cornerRadius)
                .fill(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.strong))
        )
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: StyleGuide.Dimensions.hairlineWidth),
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
    private static let dayOfWeekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
    
    private static let dayNumberFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private var dayOfWeekString: String {
        Self.dayOfWeekFormatter.string(from: day)
    }
    private var dayNumberString: String {
        Self.dayNumberFormatter.string(from: day)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(dayOfWeekString)
                .font(CalendarTypography.headerWeekday(size: textFontSizeOfWeek, isToday: isToday))
                .foregroundColor(isToday ? .accentColor : StyleGuide.Colors.text)

            Text(dayNumberString)
                .font(CalendarTypography.headerDayNumber(size: textFontSizeOfNumber, isToday: isToday))
                .foregroundColor(isToday ? .white : StyleGuide.Colors.textSecondary)
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
