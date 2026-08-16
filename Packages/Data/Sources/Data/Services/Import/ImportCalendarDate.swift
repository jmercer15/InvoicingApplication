import Foundation

/// Fixed `yyyy-MM-dd` parse/format for invoice/session import display and tabular date columns.
///
/// Matches historical bare `DateFormatter` + `dateFormat = "yyyy-MM-dd"` call sites (current locale/timezone).
enum ImportCalendarDate: Sendable {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    nonisolated static func date(from string: String) -> Date? {
        formatter.date(from: string)
    }

    nonisolated static func date(from string: String?) -> Date? {
        guard let string else { return nil }
        return date(from: string)
    }

    nonisolated static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
