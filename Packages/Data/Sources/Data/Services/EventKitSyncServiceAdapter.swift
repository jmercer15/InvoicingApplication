import Foundation
import EventKit
import SwiftData
import Core

/// Adapter that makes EventKitSyncService conform to the Core SyncService protocol
@MainActor
public class EventKitSyncServiceAdapter: @preconcurrency SyncService {
    private let eventKitService: EventKitSyncService

    private let unitOfWork: UnitOfWorkService
    private static let syncTagFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    public init(unitOfWork: UnitOfWorkService, eventKitService: EventKitSyncService = EventKitSyncService.shared) {
        self.eventKitService = eventKitService
        self.unitOfWork = unitOfWork
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
        // Use UnitOfWork for sync operations
        eventKitService.sync(session: session, unitOfWork: unitOfWork)
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
    
    public func updateSessionFromRemote(session: Session, remoteEvent: CalendarEvent) async throws -> Session {
        let normalizedTitle = remoteEvent.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let syncedTitle = normalizedTitle.isEmpty ? session.title : normalizedTitle
        let remoteEventIdentifier = remoteEvent.id.split(separator: "|", maxSplits: 1).first.map(String.init) ?? remoteEvent.id

        return Session(
            id: session.id,
            title: syncedTitle,
            startTime: remoteEvent.startDate,
            endTime: remoteEvent.endDate,
            isAllDay: remoteEvent.isAllDay,
            location: remoteEvent.location,
            notes: remoteEvent.notes,
            status: session.status,
            isTravel: session.isTravel,
            isDetached: session.isDetached,
            occurrenceDate: session.occurrenceDate,
            clientId: session.clientId,
            clientServiceId: session.clientServiceId,
            addressId: session.addressId,
            groupID: session.groupID,
            groupedPosition: session.groupedPosition,
            eventIdentifier: remoteEventIdentifier,
            eventExternalIdentifier: session.eventExternalIdentifier,
            calendarIdentifier: remoteEvent.calendarIdentifier,
            lastModifiedDate: remoteEvent.lastModifiedDate,
            lastSyncTag: Self.syncTagFormatter.string(from: remoteEvent.lastModifiedDate ?? Date()),
            recurrenceRuleData: session.recurrenceRuleData,
            attendeesCount: session.attendeesCount,
            derivedFromEKEventID: session.derivedFromEKEventID,
            googleColorId: session.googleColorId,
            sessionLatitude: session.sessionLatitude,
            sessionLongitude: session.sessionLongitude,
            assignedServiceName: session.assignedServiceName,
            assignedRate: session.assignedRate,
            travelDistanceKM: session.travelDistanceKM,
            travelTimeMinutes: session.travelTimeMinutes,
            travelTollsAmount: session.travelTollsAmount
        )
    }
    
    private func normalizedLocation(for event: EKEvent) -> String? {
        EventKitLocationParser.preferredLocation(from: event)
    }
    
    public func handleExternalChanges() async throws {
        await eventKitService.fetchAvailableCalendars()
        NotificationCenter.default.post(name: .eventKitExternalChangesDetected, object: nil)
    }
}
