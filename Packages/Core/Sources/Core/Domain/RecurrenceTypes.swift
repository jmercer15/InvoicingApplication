import Foundation
import EventKit

// MARK: - Recurrence Types

public enum RecurrenceFrequency: String, CaseIterable, Identifiable {
    case none = "None"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    public var id: String { self.rawValue }
}

public enum RecurrenceEndType: String, CaseIterable, Identifiable {
    case never = "Never"
    case afterCount = "After"
    case onDate = "On Date"
    public var id: String { self.rawValue }

    public var displayName: String {
        switch self {
        case .never: return "Never"
        case .afterCount: return "After"
        case .onDate: return "On Date"
        }
    }
}

// Enum for Monthly/Yearly Recurrence Pattern Type
public enum PositionalRecurrenceType: String, CaseIterable, Identifiable {
    case onSpecificDays = "On specific day(s)"
    case onTheOrdinalDayOfWeek = "On the..."
    public var id: String { self.rawValue }

    public var displayName: String {
        switch self {
        case .onSpecificDays: return "On specific day(s)"
        case .onTheOrdinalDayOfWeek: return "On the ordinal weekday"
        }
    }
}

// Helper Enum for Weekday Selection
public enum SelectableWeekday: Int, CaseIterable, Identifiable {
    case monday = 2, tuesday, wednesday, thursday, friday, saturday, sunday = 1

    public var id: Int { self.rawValue }

    public var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    public var ekDayOfWeek: EKRecurrenceDayOfWeek {
        return EKRecurrenceDayOfWeek(EKWeekday(rawValue: self.rawValue)!)
    }
}

// Helper for "Day of Week" options in more complex recurrences (e.g. "First Monday")
public enum DayOfWeekOption: Int, CaseIterable, Identifiable {
    case day = 0 // Represents any day
    case weekday = 1 // Represents a weekday
    case weekendDay = 2 // Represents a weekend day
    case sunday = 3
    case monday = 4
    case tuesday = 5
    case wednesday = 6
    case thursday = 7
    case friday = 8
    case saturday = 9

    public var id: Int { self.rawValue }

    public var displayName: String {
        switch self {
        case .day: return "Day"
        case .weekday: return "Weekday"
        case .weekendDay: return "Weekend Day"
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    public var ekDayOfWeek: EKRecurrenceDayOfWeek {
        return EKRecurrenceDayOfWeek(EKWeekday(rawValue: self.rawValue)!)
    }

    public var ekDaysOfWeek: [EKRecurrenceDayOfWeek]? {
        return [ekDayOfWeek]
    }
}

// Helper Enum for Month Selection
public enum SelectableMonth: Int, CaseIterable, Identifiable {
    case january = 1, february, march, april, may, june, july, august, september, october, november, december

    public var id: Int { self.rawValue }

    public var shortName: String {
        switch self {
        case .january: return "Jan"
        case .february: return "Feb"
        case .march: return "Mar"
        case .april: return "Apr"
        case .may: return "May"
        case .june: return "Jun"
        case .july: return "Jul"
        case .august: return "Aug"
        case .september: return "Sep"
        case .october: return "Oct"
        case .november: return "Nov"
        case .december: return "Dec"
        }
    }

    public var fullName: String {
        switch self {
        case .january: return "January"
        case .february: return "February"
        case .march: return "March"
        case .april: return "April"
        case .may: return "May"
        case .june: return "June"
        case .july: return "July"
        case .august: return "August"
        case .september: return "September"
        case .october: return "October"
        case .november: return "November"
        case .december: return "December"
        }
    }
}

// Helper for "Ordinal" options (First, Second, Third, Fourth, Last)
public enum OrdinalSelection: Int, CaseIterable, Identifiable {
    case first = 1, second, third, fourth, last = -1

    public var id: Int { self.rawValue }

    public var displayName: String {
        switch self {
        case .first: return "First"
        case .second: return "Second"
        case .third: return "Third"
        case .fourth: return "Fourth"
        case .last: return "Last"
        }
    }

    public var ekRecurrenceOrdinal: EKRecurrenceDayOfWeek {
        return EKRecurrenceDayOfWeek(EKWeekday(rawValue: self.rawValue)!)
    }

    public init?(intValue: Int) {
        self.init(rawValue: intValue)
    }
}
