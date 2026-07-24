import Foundation
import SwiftData
import Core
import Data

extension CalendarViewModel {
    public var showDatePicker: Bool {
        get { workspaceShowDatePicker }
        set { workspaceShowDatePicker = newValue }
    }

    public var selectedStatusFilters: Set<String> {
        get { filterStatuses }
        set { filterStatuses = newValue }
    }

    public var selectedClientFilters: Set<UUID> {
        get { selectedClientFilterIDs }
        set { selectedClientFilterIDs = newValue }
    }

    public var hourHeightBinding: Double {
        get { Double(hourHeight) }
        set {
            hourHeight = CGFloat(newValue)
            UserDefaults.standard.set(newValue, forKey: "hourHeightDouble")
        }
    }

    public func goToPreviousWeek() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) {
            selectedDate = newDate
        }
    }

    public func goToNextWeek() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) {
            selectedDate = newDate
        }
    }

    public func goToPreviousMonth() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
            selectedDate = newDate
        }
    }

    public func goToNextMonth() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
            selectedDate = newDate
        }
    }

    public func goToToday() {
        selectedDate = Date()
    }

    public func goToDate(_ date: Date) {
        selectedDate = date
    }

    public func goToPrevious() {
        switch calendarViewType {
        case .week: goToPreviousWeek()
        case .month: goToPreviousMonth()
        }
    }

    public func goToNext() {
        switch calendarViewType {
        case .week: goToNextWeek()
        case .month: goToNextMonth()
        }
    }

    public func createNewSession() {
        let calendar = Calendar.current
        let selectedDay = selectedDate
        let startTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDay) ?? selectedDay
        let endTime = calendar.date(byAdding: .hour, value: 1, to: startTime) ?? startTime
        selectedSessionInfo = (session: nil, instanceStart: startTime, instanceEnd: endTime)
    }

    public func clearSelectedSession() {
        selectedSessionInfo = nil
    }
}
