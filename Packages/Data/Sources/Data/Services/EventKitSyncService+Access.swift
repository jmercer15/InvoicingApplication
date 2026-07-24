import Foundation
@preconcurrency import EventKit
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
        print("[EventKitSyncService] Initial authorization status: \(status)")
        if #available(iOS 17.0, macOS 14.0, *), status == .writeOnly {
            print("[EventKitSyncService] Write-only Calendar access detected. Full access is required for sync and recurrence management.")
        }
        let isAuthorized = canPerformReadWriteEventOperations()
        print("[EventKitSyncService] Is authorized: \(isAuthorized)")
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
        print("[EventKitSyncService] Requesting calendar access...")
        return await withCheckedContinuation { continuation in
            if #available(iOS 17.0, macOS 14.0, *) {
                print("[EventKitSyncService] Using requestFullAccessToEvents (iOS 17+/macOS 14+)")
                eventStore.requestFullAccessToEvents { [weak self] granted, error in
                    print("[EventKitSyncService] Full access request result: granted=\(granted), error=\(error?.localizedDescription ?? "none")")
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
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                print("[EventKitSyncService] Using requestAccess(to: .event) (legacy OS)")
                eventStore.requestAccess(to: .event) { [weak self] granted, error in
                    print("[EventKitSyncService] Basic access request result: granted=\(granted), error=\(error?.localizedDescription ?? "none")")
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
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    // MARK: - Calendar CRUD

    /// Fetch all writable calendars from EventKit and publish them.
    public func fetchAvailableCalendars() async {
        print("[EventKitSyncService] Fetching available calendars...")
        let allCalendars = eventStore.calendars(for: .event)
        print("[EventKitSyncService] Total calendars found: \(allCalendars.count)")
        let calendars = allCalendars.filter { $0.allowsContentModifications }
        print("[EventKitSyncService] Writable calendars found: \(calendars.count)")

        await MainActor.run {
            self.availableCalendars = calendars
            if calendars.isEmpty {
                print("[EventKitSyncService] No writable calendars found")
                self.error = NSError(
                    domain: "EventKitSyncService",
                    code: 100,
                    userInfo: [NSLocalizedDescriptionKey: "No writable calendars found. Please check your calendar accounts and permissions."]
                )
            } else {
                print("[EventKitSyncService] Successfully loaded \(calendars.count) writable calendars")
                self.error = nil
            }
        }
    }

    /// Create a new calendar with the given title and colour.
    public func createCalendar(title: String, color: CGColor?) async throws {
        let defaultSourceType = eventStore.defaultCalendarForNewEvents?.source?.sourceType
        let defaultSourceId = eventStore.defaultCalendarForNewEvents?.source?.sourceIdentifier

        try await Task.detached(priority: .userInitiated) {
            let bgStore = EKEventStore()
            let newCalendar = EKCalendar(for: .event, eventStore: bgStore)
            newCalendar.title = title
            if let color = color {
                newCalendar.cgColor = color
            }

            let sources = bgStore.sources
            let resolvedSource = sources.first { $0.sourceIdentifier == defaultSourceId }
                ?? sources.first { $0.sourceType == defaultSourceType }
                ?? sources.first { [.local, .calDAV, .exchange, .subscribed, .mobileMe].contains($0.sourceType) }

            newCalendar.source = resolvedSource
            try bgStore.saveCalendar(newCalendar, commit: true)
        }.value

        await fetchAvailableCalendars()
    }

    /// Convenience alias used by views that hold a reference to `availableCalendars`.
    public func getCalendars() -> [EKCalendar] {
        availableCalendars
    }
}
