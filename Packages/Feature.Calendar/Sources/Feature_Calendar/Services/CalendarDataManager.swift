//
//  CalendarDataManager.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Refactoring Initiative
//
import Foundation
import EventKit
import Core
import Observation

/// Responsible for fetching raw data from SwiftData queries and EventKit.
/// Extracted from CalendarViewModel for better separation of concerns and testability
/// Uses `@Query`-provided sessions (SwiftData entities) and fetches EventKit events.
@Observable
@MainActor
public class CalendarDataManager {
    
    private let eventKitService: any CalendarEventService
    
    public init(eventKitService: any CalendarEventService) {
        self.eventKitService = eventKitService
    }
    
    // MARK: - EventKit Data Fetching
    
    /// Fetches events from EventKit for the specified date range
    /// Filters out events that have corresponding Sessions
    func fetchFilteredEvents(from startDate: Date, to endDate: Date, excludingSessionEventIDs: Set<String>) async -> [EKEvent] {
        let allEvents = await eventKitService.fetchEvents(start: startDate, end: endDate)
        
        return allEvents.filter { event in
            let eventID = event.eventIdentifier ?? event.calendarItemExternalIdentifier
            guard let eventID, !eventID.isEmpty else {
                // Some EventKit instances may not have a stable identifier materialized.
                // Keep them visible in the calendar (we just can't exclude via session linkage).
                print("[CalendarDataManager] EKEvent has no stable identifier (eventIdentifier/external). Keeping: \(event.title ?? "Untitled")")
                return true
            }
            
            // Filter out events that have corresponding Sessions
            return !excludingSessionEventIDs.contains(eventID)
        }
    }
    
    // MARK: - Combined Data Fetching
    
    /// Uses the provided sessions (e.g. from SwiftUI @Query) and fetches only EventKit events for the range.
    func fetchCalendarData(from startDate: Date, to endDate: Date, sessions: [Session]) async -> (sessions: [Session], events: [EKEvent]) {
        let derivedEventIDs = Set(sessions.compactMap { $0.derivedFromEKEventID })
        let sessionEventIDs = Set(sessions.compactMap { $0.eventIdentifier })
        let externalEventIDs = Set(sessions.compactMap { $0.eventExternalIdentifier })
        let excludingEventIDs = derivedEventIDs.union(sessionEventIDs).union(externalEventIDs)

        let events = await fetchFilteredEvents(
            from: startDate,
            to: endDate,
            excludingSessionEventIDs: excludingEventIDs
        )

        print("[CalendarDataManager] Using \(sessions.count) sessions (from query) and \(events.count) events for range \(startDate) to \(endDate)")

        return (sessions: sessions, events: events)
    }
}

 
