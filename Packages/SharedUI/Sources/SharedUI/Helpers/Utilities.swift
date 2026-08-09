import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import SwiftData

// MARK: - Date Extensions
public extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var startOfWeek: Date {
        // Create a calendar that starts the week on Monday
        var mondayFirstCalendar = Calendar(identifier: .gregorian)
        mondayFirstCalendar.firstWeekday = 2  // 2 corresponds to Monday

        // Use the Monday-first calendar to calculate the start of week
        return mondayFirstCalendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: self).date ?? self
    }

    var endOfWeek: Date {
        let components = DateComponents(day: 7, second: -1)
        return Calendar.current.date(byAdding: components, to: startOfWeek) ?? self
    }

    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    var endOfMonth: Date {
        let components = DateComponents(month: 1, day: -1)
        return Calendar.current.date(byAdding: components, to: startOfMonth) ?? self
    }

    // Add currentWeek computed property
    var currentWeek: [Date] {
        // Assuming startOfWeek correctly calculates the start based on Monday being the first day
        let start = self.startOfWeek
        // Generate the 7 days of the week starting from 'start'
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    func formattedTime() -> String {
        DateFormatting.timeOnly(self)
    }

    func formattedMediumDate() -> String {
        DateFormatting.mediumDate(self)
    }
}
