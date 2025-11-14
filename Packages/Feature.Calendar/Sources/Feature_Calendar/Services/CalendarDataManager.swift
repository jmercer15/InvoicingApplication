//
//  CalendarDataManager.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Refactoring Initiative
//
import Foundation
import EventKit
import Combine
import Core
import Data

/// Responsible for fetching raw data from repositories and EventKit
/// Extracted from CalendarViewModel for better separation of concerns and testability
/// Uses repository pattern instead of direct ModelContext access
@MainActor
public class CalendarDataManager: ObservableObject {
    
    private let sessionsRepository: SessionsRepository
    private let eventKitService: EventKitSyncService
    
    public init(sessionsRepository: SessionsRepository, eventKitService: EventKitSyncService) {
        self.sessionsRepository = sessionsRepository
        self.eventKitService = eventKitService
    }
    
    // MARK: - Session Data Fetching
    
    /// Fetches sessions from repository for the specified date range
    /// Handles both recurring and non-recurring sessions
    func fetchSessions(from startDate: Date, to endDate: Date) async -> [Session] {
        do {
            // Fetch all sessions in the date range (repository handles the query)
            let allSessions = try await sessionsRepository.fetch(from: startDate, to: endDate)
            
            // Separate recurring and non-recurring
            let nonRecurringSessions = allSessions.filter { $0.recurrenceRuleData == nil }
            let recurringSessions = allSessions.filter { $0.recurrenceRuleData != nil }
            
            // Filter non-recurring sessions in memory (repository may fetch a wider range)
            let filteredNonRecurring = nonRecurringSessions.filter { session in
                guard let startTime = session.startTime else { return false }
                return startTime >= startDate && startTime < endDate
            }
            
            // For recurring sessions, filter in memory since we need all to expand them
            // Repository fetches all recurring sessions that might have instances in range
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
    /// Filters out events that have corresponding Sessions
    func fetchFilteredEvents(from startDate: Date, to endDate: Date, excludingSessionEventIDs: Set<String>) -> [EKEvent] {
        let allEvents = eventKitService.fetchEvents(start: startDate, end: endDate)
        
        return allEvents.filter { event in
            guard let eventID = event.eventIdentifier else {
                print("[CalendarDataManager] Skipping EKEvent with no eventIdentifier: \(event.title ?? "Untitled")")
                return false
            }
            
            // Filter out events that have corresponding Sessions
            return !excludingSessionEventIDs.contains(eventID)
        }
    }
    
    // MARK: - Combined Data Fetching
    
    /// Fetches both sessions and filtered events for a date range
    /// Returns a tuple with sessions (domain models) and the event IDs that should be excluded
    func fetchCalendarData(from startDate: Date, to endDate: Date) async -> (sessions: [Session], events: [EKEvent]) {
        let sessions = await fetchSessions(from: startDate, to: endDate)
        
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
    func findSession(with id: String) async -> Session? {
        guard let sessionUUID = UUID(uuidString: id) else { return nil }
        
        do {
            return try await sessionsRepository.fetch(byId: sessionUUID)
        } catch {
            print("[CalendarDataManager] Failed to find session: \(error)")
            return nil
        }
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

 
