import os
import Foundation
import EventKit
import SwiftData
import CoreGraphics
import Core

extension EventKitSyncService {

    // MARK: - Authorization Status

    func canPerformReadWriteEventOperations() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .fullAccess
    }

    func checkInitialAccessAndFetchCalendars() {
        let status = EKEventStore.authorizationStatus(for: .event)
        Logger.calendar.debug("[EventKitSyncService] Initial authorization status: \(status.rawValue)")
        if status == .writeOnly {
            Logger.calendar.warning("[EventKitSyncService] Write-only Calendar access detected. Full access is required for sync and recurrence management.")
        }
        let isAuthorized = canPerformReadWriteEventOperations()
        Logger.calendar.debug("[EventKitSyncService] Is authorized: \(isAuthorized)")
        self.accessGranted = isAuthorized
        if isAuthorized && self.syncEnabled {
            Task { await self.fetchAvailableCalendars() }
            self.syncStatus = .idle
        } else {
            self.availableCalendars = []
            self.syncStatus = isAuthorized ? .idle : .error
        }
    }

    // MARK: - Request Access

    /// Request full-access permission to the user's calendars.
    public func requestAccess() async -> Bool {
        Logger.calendar.info("[EventKitSyncService] Requesting calendar access...")
        let session = EventKitAuthorizationSession()
        return await withTaskCancellationHandler {
            await session.wait {
                eventStore.requestFullAccessToEvents { [weak self] granted, error in
                    if let error {
                        Logger.calendar.error("[EventKitSyncService] Full access request error: \(error.localizedDescription)")
                    } else {
                        Logger.calendar.info("[EventKitSyncService] Full access request result: granted=\(granted)")
                    }
                    Task { @MainActor in
                        if granted {
                            self?.accessGranted = true
                            if self?.syncEnabled == true {
                                await self?.fetchAvailableCalendars()
                            }
                        } else {
                            self?.accessGranted = false
                            self?.availableCalendars = []
                        }
                        session.finish(granted)
                    }
                }
            }
        } onCancel: {
            Task { @MainActor in session.finish(false) }
        }
    }

    // MARK: - Calendar CRUD

    /// Fetch all writable calendars from EventKit and publish them.
    public func fetchAvailableCalendars() async {
        Logger.calendar.debug("[EventKitSyncService] Fetching available calendars...")
        let allCalendars = eventStore.calendars(for: .event)
        Logger.calendar.debug("[EventKitSyncService] Total calendars found: \(allCalendars.count)")
        let calendars = allCalendars.filter { $0.allowsContentModifications }
        Logger.calendar.debug("[EventKitSyncService] Writable calendars found: \(calendars.count)")

        self.availableCalendars = calendars
        if calendars.isEmpty {
            Logger.calendar.warning("[EventKitSyncService] No writable calendars found")
            self.error = NSError(
                domain: "EventKitSyncService",
                code: 100,
                userInfo: [NSLocalizedDescriptionKey: "No writable calendars found. Please check your calendar accounts and permissions."]
            )
        } else {
            Logger.calendar.info("[EventKitSyncService] Successfully loaded \(calendars.count) writable calendars")
            self.error = nil
        }
    }

    /// Create a new calendar with the given title and colour.
    public func createCalendar(title: String, color: CGColor?) async throws {
        let defaultSourceType = eventStore.defaultCalendarForNewEvents?.source?.sourceType
        let defaultSourceId = eventStore.defaultCalendarForNewEvents?.source?.sourceIdentifier

        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = title
        if let color {
            newCalendar.cgColor = color
        }

        let resolvedSource = eventStore.sources.first { $0.sourceIdentifier == defaultSourceId }
            ?? eventStore.sources.first { $0.sourceType == defaultSourceType }
            ?? eventStore.sources.first { [.local, .calDAV, .exchange, .subscribed, .mobileMe].contains($0.sourceType) }

        newCalendar.source = resolvedSource
        try eventStore.saveCalendar(newCalendar, commit: true)

        await fetchAvailableCalendars()
    }

    /// Convenience alias used by views that hold a reference to `availableCalendars`.
    public func getCalendars() -> [EKCalendar] {
        availableCalendars
    }
}

@MainActor
private final class EventKitAuthorizationSession {
    private var continuation: CheckedContinuation<Bool, Never>?
    private var isFinished = false

    func wait(start: () -> Void) async -> Bool {
        await withCheckedContinuation { continuation in
            guard !isFinished else {
                continuation.resume(returning: false)
                return
            }
            self.continuation = continuation
            start()
        }
    }

    func finish(_ granted: Bool) {
        guard !isFinished else { return }
        isFinished = true
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(returning: granted)
    }
}
