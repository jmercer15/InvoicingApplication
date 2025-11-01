import Foundation
import EventKit
import SwiftData
import Core

/// Adapter that makes EventKitSyncService conform to the Core SyncService protocol
@MainActor
public class EventKitSyncServiceAdapter: @preconcurrency SyncService {
    private let eventKitService: EventKitSyncService
    
    public init(eventKitService: EventKitSyncService = EventKitSyncService.shared) {
        self.eventKitService = eventKitService
    }
    
    // MARK: - SyncService Protocol Conformance
    
    public var accessGranted: Bool {
        eventKitService.accessGranted
    }
    
    public var syncEnabled: Bool {
        get { eventKitService.syncEnabled }
        set { eventKitService.syncEnabled = newValue }
    }
    
    public var lastSyncDate: Date? {
        eventKitService.lastSyncDate
    }
    
    public var syncStatus: Core.SyncStatus {
        switch eventKitService.syncStatus {
        case .idle:
            return .idle
        case .syncing:
            return .syncing
        case .error:
            return .error
        case .disabled:
            return .disabled
        }
    }
    
    public var availableCalendars: [CalendarInfo] {
        eventKitService.availableCalendars.map { calendar in
            CalendarInfo(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                color: "0.5,0.5,0.5", // Default gray color
                isEnabled: calendar.allowsContentModifications
            )
        }
    }
    
    public var monitoredCalendarIdentifiers: Set<String> {
        eventKitService.monitoredCalendarIdentifiers
    }
    
    public func requestAccess() async throws -> Bool {
        return await eventKitService.requestAccess()
    }
    
    public func setSyncEnabled(_ enabled: Bool) async {
        eventKitService.syncEnabled = enabled
    }
    
    public func sync(session: Session) async throws {
        // Convert domain Session to SessionEntity for the existing service
        // This is a temporary bridge - in a full implementation, you'd want to
        // refactor the EventKitSyncService to work with domain models directly
        let sessionEntity = SessionEntity(id: session.id)
        sessionEntity.update(from: session)
        
        // Create a temporary ModelContext for the sync operation
        // In a real implementation, this would be injected
        let modelContainer = ModelContainerHelper.createModelContainerSafely() ?? {
            do {
                let schema = Schema([SessionEntity.self])
                let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()
        let modelContext = ModelContext(modelContainer)
        
        eventKitService.sync(session: sessionEntity, modelContext: modelContext)
    }
    
    public func delete(syncIdentifier: String) async throws {
        eventKitService.delete(syncIdentifier: syncIdentifier)
    }
    
    public func update(session: Session) async throws {
        try await sync(session: session)
    }
    
    public func fetchEvents(start: Date, end: Date) async throws -> [CalendarEvent] {
        let ekEvents = eventKitService.fetchEvents(start: start, end: end)
        return ekEvents.map { event in
            CalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location,
                notes: event.notes,
                calendarIdentifier: event.calendar.calendarIdentifier,
                lastModifiedDate: event.lastModifiedDate
            )
        }
    }
    
    public func updateSessionFromRemote(session: Session, remoteEvent: CalendarEvent) async throws -> Session {
        // Convert CalendarEvent back to EKEvent for the existing service
        // This is a temporary bridge - in a full implementation, you'd want to
        // refactor the EventKitSyncService to work with domain models directly
        
        // For now, return the original session as this is a complex operation
        // that would require significant refactoring of the existing service
        return session
    }
    
    public func handleExternalChanges() async throws {
        // The existing service handles external changes via notifications
        // This method is provided for protocol conformance
        // In a real implementation, you might want to trigger a refresh here
    }
}

