import SwiftUI
import SharedUI

// ─────────────────────────────────────────────────────────────
// MARK: - Month Header View (Displays Weekday Names)
// ─────────────────────────────────────────────────────────────

struct MonthHeaderView: View {
    @ObservedObject var viewModel: CalendarViewModel // Needed to get currentWeekDays for layout

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
                        Rectangle().frame(width: 0.5, height: nil).foregroundColor(Color.secondary.opacity(0.3))
                        : nil // No border for the first item
                        , alignment: .leading
                    )
            }
        }
        .background {
            let shape = UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .glassEffect(
                    .regular.tint(Color.white.opacity(0.15)),
                    in: .rect(cornerRadius: 20)
                )
                .clipShape(shape)
        }
        // Add bottom border only to the day headers section
        .overlay(Rectangle().frame(width: nil, height: 1).foregroundColor(Color.secondary.opacity(0.2)), alignment: .bottom)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Individual Day Header Item (for Month View)
// ─────────────────────────────────────────────────────────────

struct MonthDayHeaderItemView: View {
    let day: Date // A representative date for the weekday

    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private var isWeekend: Bool {
        let wd = Calendar.current.component(.weekday, from: day)
        return wd == 1 || wd == 7
    }
    private var dayOfWeekString: String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: day)
    }

    var body: some View {
        // Match WeekView styling - just day name for month view
        HStack(spacing: 6) {
            Text(dayOfWeekString)
                .font(.system(size: 20))
                .fontWeight(isToday ? .bold : .semibold)
                .tracking(1.5)
                .foregroundColor(Color("Text", bundle: .sharedUI))
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
    }
} 
