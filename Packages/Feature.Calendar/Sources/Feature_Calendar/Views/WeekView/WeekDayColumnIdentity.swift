import Foundation

/// Stable week-column identity keyed by calendar day components (DST-safe).
struct WeekDayColumnIdentity: Hashable, Identifiable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    var id: String { "\(year)-\(month)-\(day)" }

    init(calendarDay: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: calendarDay)
        year = components.year ?? 0
        month = components.month ?? 0
        day = components.day ?? 0
    }

    func resolvedDate(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
            ?? calendar.startOfDay(for: .distantPast)
    }
}

extension CalendarViewModel {
    var currentWeekDayIdentities: [WeekDayColumnIdentity] {
        currentWeekDays.map { WeekDayColumnIdentity(calendarDay: $0) }
    }
}
