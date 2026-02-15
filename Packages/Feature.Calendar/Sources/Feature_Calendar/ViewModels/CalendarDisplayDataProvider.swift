import Foundation

struct CalendarDisplayDataProvider {
    func buildMonthGridWeeks(for monthDate: Date, calendar: Calendar = .current) -> [[Date?]] {
        let month = monthDate.startOfMonth
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }

        let firstDayOfMonthWeekday = calendar.component(.weekday, from: monthInterval.start)
        let firstWeekday = calendar.firstWeekday
        let daysToPrepend = (firstDayOfMonthWeekday - firstWeekday + 7) % 7

        var dates: [Date?] = Array(repeating: nil, count: daysToPrepend)
        var currentDate = monthInterval.start
        while currentDate < monthInterval.end {
            dates.append(currentDate)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDay
        }
        let remainingDaysInLastWeek = (7 - (dates.count % 7)) % 7
        if remainingDaysInLastWeek > 0 {
            dates.append(contentsOf: Array(repeating: nil as Date?, count: remainingDaysInLastWeek))
        }
        return stride(from: 0, to: dates.count, by: 7).map {
            Array(dates[$0..<min($0 + 7, dates.count)])
        }
    }
}


