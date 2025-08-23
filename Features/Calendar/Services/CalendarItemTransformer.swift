//
//  CalendarItemTransformer.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Refactoring Initiative
//
import Foundation
import EventKit
import SwiftUI

/// Responsible for transforming raw data models into DisplayableCalendarItem view models
/// Extracted from CalendarViewModel for better separation of concerns and testability
class CalendarItemTransformer {
    
    // MARK: - Item Transformation
    
    /// Transforms sessions into DisplayableCalendarItems
    func transformSessions(_ sessions: [SessionEntity]) -> [DisplayableCalendarItem] {
        return sessions.map { session in
            DisplayableCalendarItem.session(session)
        }
    }
    
    /// Transforms EKEvents into DisplayableCalendarItems
    func transformEvents(_ events: [EKEvent]) -> [DisplayableCalendarItem] {
        return events.map { event in
            DisplayableCalendarItem.event(event)
        }
    }
    
    /// Transforms recurring session data into individual DisplayableCalendarItems
    func transformRecurringSessionData(_ recurrenceData: [RecurrenceService.SessionRecurrenceData]) -> [DisplayableCalendarItem] {
        var items: [DisplayableCalendarItem] = []
        
        for data in recurrenceData {
            for instance in data.instances {
                let item = DisplayableCalendarItem.recurringSessionInstance(
                    template: data.masterSession,
                    instanceStartDate: instance.instanceStart,
                    instanceEndDate: instance.instanceEnd,
                    instanceIsAllDay: data.masterSession.isAllDay
                )
                items.append(item)
            }
        }
        
        return items
    }
    
    /// Combines and transforms all calendar data into sorted DisplayableCalendarItems
    func transformCalendarData(
        sessions: [SessionEntity],
        events: [EKEvent],
        recurrenceData: [RecurrenceService.SessionRecurrenceData]
    ) -> (allDayItems: [DisplayableCalendarItem], timedItems: [DisplayableCalendarItem]) {
        
        var allDayItems: [DisplayableCalendarItem] = []
        var timedItems: [DisplayableCalendarItem] = []
        
        // Transform regular sessions
        let sessionItems = transformSessions(sessions)
        for item in sessionItems {
            if item.isAllDay {
                allDayItems.append(item)
            } else {
                timedItems.append(item)
            }
        }
        
        // Transform recurring session instances
        let recurringItems = transformRecurringSessionData(recurrenceData)
        for item in recurringItems {
            if item.isAllDay {
                allDayItems.append(item)
            } else {
                timedItems.append(item)
            }
        }
        
        // Transform events
        let eventItems = transformEvents(events)
        for item in eventItems {
            if item.isAllDay {
                allDayItems.append(item)
            } else {
                timedItems.append(item)
            }
        }
        
        // Sort items by start date
        allDayItems.sort { $0.startDate ?? .distantPast < $1.startDate ?? .distantPast }
        timedItems.sort { $0.startDate ?? .distantPast < $1.startDate ?? .distantPast }
        
        return (allDayItems: allDayItems, timedItems: timedItems)
    }
    
    // MARK: - Multi-Day Item Splitting
    
    /// Splits multi-day items into daily segments for proper calendar display
    /// This handles events/sessions that span multiple days
    func splitMultiDayItems(
        allDayItems: [DisplayableCalendarItem],
        timedItems: [DisplayableCalendarItem]
    ) -> (allDayItems: [DisplayableCalendarItem], timedItems: [DisplayableCalendarItem]) {
        
        var finalAllDayItems: [DisplayableCalendarItem] = []
        var finalTimedItems: [DisplayableCalendarItem] = []
        
        // Process all-day items
        for item in allDayItems {
            let splitItems = splitMultiDayItem(item)
            finalAllDayItems.append(contentsOf: splitItems.allDay)
            finalTimedItems.append(contentsOf: splitItems.timed)
        }
        
        // Process timed items
        for item in timedItems {
            let splitItems = splitMultiDayItem(item)
            finalAllDayItems.append(contentsOf: splitItems.allDay)
            finalTimedItems.append(contentsOf: splitItems.timed)
        }
        
        return (allDayItems: finalAllDayItems, timedItems: finalTimedItems)
    }
    
    /// Splits a single multi-day item into daily segments
    private func splitMultiDayItem(_ item: DisplayableCalendarItem) -> (allDay: [DisplayableCalendarItem], timed: [DisplayableCalendarItem]) {
        guard let startDate = item.startDate,
              let endDate = item.endDate else {
            // If no dates, return the original item in appropriate category
            return item.isAllDay ? (allDay: [item], timed: []) : (allDay: [], timed: [item])
        }
        
        let calendar = Calendar.current
        let startOfStartDay = calendar.startOfDay(for: startDate)
        let _ = calendar.startOfDay(for: endDate)  // Used for date calculations
        
        // If the item is within a single day, no splitting needed
        if calendar.isDate(startDate, inSameDayAs: endDate) {
            return item.isAllDay ? (allDay: [item], timed: []) : (allDay: [], timed: [item])
        }
        
        var allDay: [DisplayableCalendarItem] = []
        var timed: [DisplayableCalendarItem] = []
        
        // Calculate the effective end date for processing
        let effectiveEndDate = item.isAllDay ? endDate : endDate
        let finalDayStart = calendar.startOfDay(for: effectiveEndDate)
        
        var currentDate = startOfStartDay
        
        while currentDate <= finalDayStart {
            let isFirstDay = calendar.isDate(currentDate, inSameDayAs: startDate)
            let isLastDay = calendar.isDate(currentDate, inSameDayAs: effectiveEndDate)
            
            let instanceStartDate: Date
            let instanceEndDate: Date
            let instanceIsAllDay: Bool
            
            if isFirstDay {
                instanceStartDate = startDate
                instanceEndDate = isLastDay ? effectiveEndDate : endOfDay(for: currentDate, using: calendar)
                instanceIsAllDay = item.isAllDay
            } else if isLastDay {
                instanceStartDate = calendar.startOfDay(for: currentDate)
                instanceEndDate = effectiveEndDate
                instanceIsAllDay = item.isAllDay
            } else { // Middle day
                instanceStartDate = calendar.startOfDay(for: currentDate)
                instanceEndDate = endOfDay(for: currentDate, using: calendar)
                instanceIsAllDay = true // Full day segments are considered all-day
            }
            
            let newItem = createSegment(
                for: item,
                startDate: instanceStartDate,
                endDate: instanceEndDate,
                isAllDay: instanceIsAllDay
            )
            
            if newItem.isAllDay {
                allDay.append(newItem)
            } else {
                timed.append(newItem)
            }
            
            // Move to the next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return (allDay: allDay, timed: timed)
    }
    
    /// Helper function to calculate end of day
    private func endOfDay(for date: Date, using calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        // Add one day and subtract one second to get 23:59:59
        return calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
    }
    
    /// Creates a segment of an original item for multi-day splitting
    private func createSegment(
        for originalItem: DisplayableCalendarItem,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool
    ) -> DisplayableCalendarItem {
        
        switch originalItem {
        case .session(let session):
            return .recurringSessionInstance(
                template: session,
                instanceStartDate: startDate,
                instanceEndDate: endDate,
                instanceIsAllDay: isAllDay
            )
        case .event(let event):
            return .eventSegment(
                originalEvent: event,
                segmentStartDate: startDate,
                segmentEndDate: endDate,
                segmentIsAllDay: isAllDay
            )
        case .recurringSessionInstance(let template, _, _, _):
            return .recurringSessionInstance(
                template: template,
                instanceStartDate: startDate,
                instanceEndDate: endDate,
                instanceIsAllDay: isAllDay
            )
        case .eventSegment(let originalEvent, _, _, _):
            return .eventSegment(
                originalEvent: originalEvent,
                segmentStartDate: startDate,
                segmentEndDate: endDate,
                segmentIsAllDay: isAllDay
            )
        }
    }
    
    // MARK: - Filtering and Sorting
    
    /// Filters items based on search criteria
    func filterItems(
        _ items: [DisplayableCalendarItem],
        searchText: String,
        selectedClientIDs: Set<UUID>,
        statusFilters: Set<String>,
        showCancelled: Bool
    ) -> [DisplayableCalendarItem] {
        
        return items.filter { item in
            // Search text filter
            if !searchText.isEmpty {
                let searchMatch = item.title.localizedCaseInsensitiveContains(searchText)
                if !searchMatch {
                    return false
                }
            }
            
            // Client filter (only applies to sessions)
            if !selectedClientIDs.isEmpty,
               let session = item.underlyingSession,
               let clientID = session.client?.id {
                if !selectedClientIDs.contains(clientID) {
                    return false
                }
            }
            
            // Status filter (only applies to sessions)
            if !statusFilters.isEmpty,
               let session = item.underlyingSession,
               let status = session.status {
                if !statusFilters.contains(status) {
                    return false
                }
            }
            
            // Cancelled sessions filter
            if !showCancelled,
               let session = item.underlyingSession,
               session.status == .sessionStatusCancelled {
                return false
            }
            
            return true
        }
    }
    
    /// Sorts items by their display priority and time
    func sortItemsForDisplay(_ items: [DisplayableCalendarItem]) -> [DisplayableCalendarItem] {
        return items.sorted { item1, item2 in
            let date1 = item1.startDate ?? .distantPast
            let date2 = item2.startDate ?? .distantPast
            
            if date1 != date2 {
                return date1 < date2
            }
            
            // If dates are equal, prioritize sessions over events
            if item1.isSession && !item2.isSession {
                return true
            } else if !item1.isSession && item2.isSession {
                return false
            }
            
            // Finally, sort by title for consistent ordering
            return item1.title < item2.title
        }
    }
    
    // MARK: - Utility Methods
    
    /// Groups items by date for day-based displays
    func groupItemsByDate(_ items: [DisplayableCalendarItem]) -> [Date: [DisplayableCalendarItem]] {
        let calendar = Calendar.current
        var grouped: [Date: [DisplayableCalendarItem]] = [:]
        
        for item in items {
            guard let startDate = item.startDate else { continue }
            let dayKey = calendar.startOfDay(for: startDate)
            
            if grouped[dayKey] == nil {
                grouped[dayKey] = []
            }
            grouped[dayKey]?.append(item)
        }
        
        return grouped
    }
    
    /// Calculates layout positions for overlapping items
    func calculateLayoutPositions(for items: [DisplayableCalendarItem]) -> [String: ItemLayoutPosition] {
        var positions: [String: ItemLayoutPosition] = [:]
        
        // Group items by day first
        let itemsByDay = groupItemsByDate(items)
        
        for (_, dayItems) in itemsByDay {
            let sortedItems = dayItems.sorted { $0.startHour < $1.startHour }
            
            for (index, item) in sortedItems.enumerated() {
                let position = ItemLayoutPosition(
                    column: calculateColumn(for: item, in: sortedItems, upToIndex: index),
                    width: calculateWidth(for: item, in: sortedItems),
                    conflictingItemsCount: countConflictingItems(for: item, in: sortedItems)
                )
                
                positions[item.id] = position
            }
        }
        
        return positions
    }
    
    private func calculateColumn(for item: DisplayableCalendarItem, in items: [DisplayableCalendarItem], upToIndex: Int) -> Int {
        // Simplified column calculation - can be made more sophisticated
        var usedColumns: Set<Int> = []
        
        for i in 0..<upToIndex {
            let otherItem = items[i]
            if itemsOverlap(item, otherItem) {
                // This is a simplified version - real implementation would track column usage
                usedColumns.insert(i % 3) // Limit to 3 columns for now
            }
        }
        
        // Find first available column
        for column in 0..<3 {
            if !usedColumns.contains(column) {
                return column
            }
        }
        
        return 0 // Fallback
    }
    
    private func calculateWidth(for item: DisplayableCalendarItem, in items: [DisplayableCalendarItem]) -> Double {
        let conflictCount = countConflictingItems(for: item, in: items)
        return conflictCount > 0 ? 1.0 / Double(conflictCount + 1) : 1.0
    }
    
    private func countConflictingItems(for item: DisplayableCalendarItem, in items: [DisplayableCalendarItem]) -> Int {
        return items.filter { otherItem in
            otherItem.id != item.id && itemsOverlap(item, otherItem)
        }.count
    }
    
    private func itemsOverlap(_ item1: DisplayableCalendarItem, _ item2: DisplayableCalendarItem) -> Bool {
        guard let start1 = item1.startDate, let end1 = item1.endDate,
              let start2 = item2.startDate, let end2 = item2.endDate else {
            return false
        }
        
        return start1 < end2 && start2 < end1
    }
    
    // MARK: - Helper Types
    
    struct ItemLayoutPosition {
        let column: Int
        let width: Double
        let conflictingItemsCount: Int
    }
} 