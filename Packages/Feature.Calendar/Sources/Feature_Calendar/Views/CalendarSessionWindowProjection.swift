import Foundation

/// Forces `CalendarView` to rebuild its `@Query` when the visible window changes.
struct CalendarQueryRangeIdentity: Hashable {
    let start: Date
    let end: Date

    init(_ range: (start: Date, end: Date)) {
        start = range.start
        end = range.end
    }
}
