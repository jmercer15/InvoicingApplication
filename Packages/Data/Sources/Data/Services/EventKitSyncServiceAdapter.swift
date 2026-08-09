import Foundation
import EventKit
import SwiftData
import Core
import PersistenceModels

/// Adapter that makes EventKitSyncService conform to the Core SyncService protocol
@MainActor
public class EventKitSyncServiceAdapter: SyncService {
    private let eventKitService: EventKitSyncService
    private let modelContext: ModelContext

    public init(modelContext: ModelContext, eventKitService: EventKitSyncService) {
        self.eventKitService = eventKitService
        self.modelContext = modelContext
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
    
    public func sync(session: SessionSnapshot) async throws {
        eventKitService.sync(snapshot: session, modelContext: modelContext)
    }
    
    public func delete(syncIdentifier: String) async throws {
        eventKitService.delete(syncIdentifier: syncIdentifier)
    }
    
    public func update(session: SessionSnapshot) async throws {
        try await sync(session: session)
    }
    
    public func fetchEvents(start: Date, end: Date) async throws -> [CalendarEvent] {
        let ekEvents = await eventKitService.fetchEvents(start: start, end: end)
        return ekEvents.map { event in
            let baseIdentifier = event.eventIdentifier ?? UUID().uuidString
            let occurrenceAnchor = (event.occurrenceDate ?? event.startDate).timeIntervalSinceReferenceDate
            return CalendarEvent(
                id: "\(baseIdentifier)|\(occurrenceAnchor)",
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                location: normalizedLocation(for: event),
                notes: event.notes,
                calendarIdentifier: event.calendar.calendarIdentifier,
                lastModifiedDate: event.lastModifiedDate
            )
        }
    }
    
    public func updateSessionFromRemote(session: SessionSnapshot, remoteEvent: CalendarEvent) async throws -> SessionSnapshot {
        let normalizedTitle = remoteEvent.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let syncedTitle = normalizedTitle.isEmpty ? session.title : normalizedTitle

        return SessionSnapshot(
            id: session.id,
            title: syncedTitle,
            startTime: remoteEvent.startDate,
            endTime: remoteEvent.endDate,
            isAllDay: remoteEvent.isAllDay,
            location: remoteEvent.location,
            notes: remoteEvent.notes,
            status: session.status,
            isTravel: session.isTravel,
            groupID: session.groupID,
            groupedPosition: session.groupedPosition,
            sessionLatitude: session.sessionLatitude,
            sessionLongitude: session.sessionLongitude,
            travelDistanceKM: remoteEvent.title.lowercased().contains("travel") ? session.travelDistanceKM : nil,
            travelTimeMinutes: remoteEvent.title.lowercased().contains("travel") ? session.travelTimeMinutes : nil,
            travelTollsAmount: session.travelTollsAmount,
            recurrenceRuleData: session.recurrenceRuleData,
            clientId: session.clientId,
            clientServiceId: session.clientServiceId,
            addressId: session.addressId,
            ndisItemNumber: session.ndisItemNumber,
            claimType: session.claimType,
            attendeesCount: session.attendeesCount,
            travelCharges: session.travelCharges
        )
    }
    
    private func normalizedLocation(for event: EKEvent) -> String? {
        EventKitLocationParser.preferredLocation(from: event)
    }
    
    public func handleExternalChanges() async throws {
        // Run direct sync refresh. Re-broadcasting external-change notifications
        // here can create loops in feature-level observers.
        await eventKitService.handleExternalChangesWithContext(modelContext)
        await eventKitService.fetchAvailableCalendars()
    }
}
