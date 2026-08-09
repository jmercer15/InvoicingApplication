import Foundation
import PersistenceModels
import Observation

/// Display cache for calendar rendering. Separated from interaction/filter state so
/// week grid views do not invalidate when toolbar selection or bulk mode changes.
@Observable
@MainActor
final class CalendarDisplayState {
    var isLoading = false
    var filteredSessions: [Session] = []
    var sessionRegistry: [UUID: Session] = [:]
    var clientNamesCache: [UUID: String] = [:]
    var serviceNamesCache: [UUID: String] = [:]

    var allDayItems: [DisplayableCalendarItem] = []
    var timedItems: [DisplayableCalendarItem] = []

    var timedItemsByDay: [DateComponents: [DisplayableCalendarItem]] = [:]
    var allDayItemsByDay: [DateComponents: [DisplayableCalendarItem]] = [:]
    var combinedItemsByDay: [DateComponents: [DisplayableCalendarItem]] = [:]

    var relativePlacementsByDay: [DateComponents: [String: CalendarItemOverlapGeometry.RelativePlacement]] = [:]

    var allDayPositionedItems: [AllDayPositionedItem] = []
    var allDayStripHeight: CGFloat = 0

    var displayableItems: [DisplayableCalendarItem] {
        allDayItems + timedItems
    }

    /// Drops every live `Session` / display item so CloudKit HistoryExpired cannot
    /// fault invalidated backing data during the next body evaluation.
    func clearLiveSessionModels() {
        filteredSessions = []
        sessionRegistry = [:]
        clientNamesCache = [:]
        serviceNamesCache = [:]
        allDayItems = []
        timedItems = []
        timedItemsByDay = [:]
        allDayItemsByDay = [:]
        combinedItemsByDay = [:]
        relativePlacementsByDay = [:]
        allDayPositionedItems = []
        allDayStripHeight = 0
        isLoading = true
    }

    func timedItems(for day: Date) -> [DisplayableCalendarItem] {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return timedItemsByDay[components] ?? []
    }

    func allDayItems(for day: Date) -> [DisplayableCalendarItem] {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return allDayItemsByDay[components] ?? []
    }

    func combinedItems(for day: Date) -> [DisplayableCalendarItem] {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return combinedItemsByDay[components] ?? []
    }
}
