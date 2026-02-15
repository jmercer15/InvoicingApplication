import Foundation

extension Calendar {
    func endOfDay(for date: Date) -> Date {
        // Return 23:59:59 of the given date
        return self.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
    }
}
