//
//  CalendarDataManager.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Refactoring Initiative
//
import Foundation
import SwiftData
import Data
import EventKit
import Combine

/// Responsible for fetching raw data from Core Data and EventKit
/// Extracted from CalendarViewModel for better separation of concerns and testability
@MainActor
public class CalendarDataManager: ObservableObject {
    
    private let context: ModelContext
    private let eventKitService: EventKitSyncService
    
    public init(context: ModelContext, eventKitService: EventKitSyncService) {
        self.context = context
        self.eventKitService = eventKitService
    }
    
    // MARK: - Session Data Fetching
    

    
    /// Fetches sessions from SwiftData for the specified date range
    /// Handles both recurring and non-recurring sessions
    func fetchSessions(from startDate: Date, to endDate: Date) -> [SessionEntity] {
        // Fetch non-recurring sessions
        let nonRecurringPredicate = #Predicate<SessionEntity> { 
            $0.recurrenceRuleData == nil &&
            $0.startTime != nil
        }
        
        // Fetch recurring sessions
        let recurringPredicate = #Predicate<SessionEntity> { 
            $0.recurrenceRuleData != nil &&
            $0.startTime != nil
        }

        let nonRecurringDescriptor = FetchDescriptor(
            predicate: nonRecurringPredicate, 
            sortBy: [SortDescriptor(\SessionEntity.startTime)]
        )
        let recurringDescriptor = FetchDescriptor(
            predicate: recurringPredicate, 
            sortBy: [SortDescriptor(\SessionEntity.startTime)]
        )
        
        do {
            let nonRecurringSessions: [SessionEntity] = try context.fetch(nonRecurringDescriptor)
            let recurringSessions: [SessionEntity] = try context.fetch(recurringDescriptor)
            
            // Filter non-recurring sessions in memory
            let filteredNonRecurring = nonRecurringSessions.filter { session in
                guard let startTime = session.startTime else { return false }
                return startTime >= startDate && startTime < endDate
            }
            
            // For recurring sessions, we still need to filter in memory for the date range
            // since SwiftData predicates can't handle complex recurrence rules
            let filteredRecurring = recurringSessions.filter {
                ($0.startTime ?? Date.distantFuture) < endDate
            }
            
            return filteredNonRecurring + filteredRecurring
        } catch {
            print("[CalendarDataManager] Failed to fetch sessions: \(error)")
            return []
        }
    }
    

    
    // MARK: - EventKit Data Fetching
    
    /// Fetches events from EventKit for the specified date range
    /// Filters out events that have corresponding SessionEntities
    func fetchFilteredEvents(from startDate: Date, to endDate: Date, excludingSessionEventIDs: Set<String>) -> [EKEvent] {
        let allEvents = eventKitService.fetchEvents(start: startDate, end: endDate)
        
        return allEvents.filter { event in
            guard let eventID = event.eventIdentifier else {
                print("[CalendarDataManager] Skipping EKEvent with no eventIdentifier: \(event.title ?? "Untitled")")
                return false
            }
            
            // Filter out events that have corresponding SessionEntities
            return !excludingSessionEventIDs.contains(eventID)
        }
    }
    
    // MARK: - Combined Data Fetching
    
    /// Fetches both sessions and filtered events for a date range
    /// Returns a tuple with sessions and the event IDs that should be excluded
    func fetchCalendarData(from startDate: Date, to endDate: Date) -> (sessions: [SessionEntity], events: [EKEvent]) {
        let sessions = fetchSessions(from: startDate, to: endDate)
        
        // Collect event IDs that should be excluded
        let derivedEventIDs = Set(sessions.compactMap { $0.derivedFromEKEventID })
        let sessionEventIDs = Set(sessions.compactMap { $0.eventIdentifier })
        let excludingEventIDs = derivedEventIDs.union(sessionEventIDs)
        
        let events = fetchFilteredEvents(
            from: startDate, 
            to: endDate, 
            excludingSessionEventIDs: excludingEventIDs
        )
        
        print("[CalendarDataManager] Fetched \(sessions.count) sessions and \(events.count) events for range \(startDate) to \(endDate)")
        
        return (sessions: sessions, events: events)
    }
    
    // MARK: - Utility Methods
    
    /// Finds a specific session by ID
    func findSession(with id: String) -> SessionEntity? {
        guard let sessionUUID = UUID(uuidString: id) else { return nil }
        
        let descriptor = FetchDescriptor<SessionEntity>(
            predicate: #Predicate<SessionEntity> { $0.id == sessionUUID }, 
            sortBy: [SortDescriptor(\SessionEntity.startTime)],
        )
        
        return try? context.fetch(descriptor).first
    }
    
    /// Checks if the data manager has access to EventKit
    var hasEventKitAccess: Bool {
        eventKitService.accessGranted
    }
    
    /// Publisher for EventKit access changes
    var eventKitAccessPublisher: AnyPublisher<Bool, Never> {
        eventKitService.$accessGranted.eraseToAnyPublisher()
    }
}

 
