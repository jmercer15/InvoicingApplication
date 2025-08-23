import SwiftUI

// ─────────────────────────────────────────────────────────────
// MARK: - Week Header Bar View
// ─────────────────────────────────────────────────────────────

struct WeekHeaderView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let timeColumnWidth: CGFloat
    let dayColumnWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            // Day headers
            HStack(spacing: 0) {
            ForEach(viewModel.currentWeekDays.indices, id: \.self) { index in
                let day = viewModel.currentWeekDays[index]
                DayHeaderItemView(day: day)
                    .frame(width: index == 0 ? dayColumnWidth + timeColumnWidth : dayColumnWidth)
                    // Add right border to all but the last day header
                    .overlay(
                        index < viewModel.currentWeekDays.count - 1 ?
                        Rectangle().frame(width: 1.5, height: nil).foregroundColor(Color.secondary.opacity(0.3))
                        : nil // No border for the last item
                        , alignment: .trailing
                    )
            }
        }
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                    .fill(Color.black.opacity(0.3))
            )
            // Add bottom border only to the day headers section
        .overlay(Rectangle().frame(width: nil, height: 1).foregroundColor(Color.secondary.opacity(0.2)), alignment: .bottom)
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Individual Day Header Item
// ─────────────────────────────────────────────────────────────

struct DayHeaderItemView: View {
    let day: Date

    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private var isWeekend: Bool {
        let wd = Calendar.current.component(.weekday, from: day)
        return wd == 1 || wd == 7
    }
    private var dayOfWeekString: String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: day)
    }
    private var dayNumberString: String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: day)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(dayOfWeekString)
                .font(.system(size: 20))
                .fontWeight(isToday ? .bold : .semibold)
                .tracking(1.5)
                .foregroundColor(.primary)

            Text(dayNumberString)
                .font(.system(size: 20, weight: .ultraLight))
                .tracking(1.5)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
    }
} 