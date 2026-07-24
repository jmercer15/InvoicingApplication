import CloudKit
import Core
import Foundation
import os
import SwiftData
import Observation

// MARK: - Sync State

public enum CloudKitSyncState: Equatable, Sendable {
    case idle
    case importing
    case exporting
    case error(String)
    case persistentError(String)

    public var isActive: Bool {
        switch self {
        case .importing, .exporting:
            return true
        default:
            return false
        }
    }

    public var isError: Bool {
        switch self {
        case .error, .persistentError:
            return true
        default:
            return false
        }
    }

    public var displayText: String {
        switch self {
        case .idle:
            return "Idle"
        case .importing:
            return "Importing"
        case .exporting:
            return "Exporting"
        case let .error(message):
            return message
        case let .persistentError(message):
            return message
        }
    }
}

// MARK: - CloudKit Event Types

private enum CloudKitEventType: Int {
    case setup = 0
    case `import` = 1
    case export = 2

    var label: String {
        switch self {
        case .setup: return "setup"
        case .import: return "import"
        case .export: return "export"
        }
    }
}

// MARK: - CloudKitSyncMonitor

/// Observes CloudKit sync events from `NSPersistentCloudKitContainer` and surfaces
/// current state to SwiftUI views.
///
/// Instantiate this once at app composition and inject it into the environment (e.g. `.environment(monitor)`).
/// so any view can display sync status without coupling to the persistence layer.
@Observable
@MainActor
public final class CloudKitSyncMonitor {

    // MARK: - Published State

    public private(set) var syncState: CloudKitSyncState = .idle
    public private(set) var lastSyncDate: Date?
    public private(set) var lastError: CloudKitSyncError?
    public private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    /// Whether the user has explicitly dismissed the last error banner.
    public var isErrorDismissed: Bool = false

    // MARK: - Private

    private let observationBag = ObservationBag()
    private let container: CKContainer

    /// Consecutive error counter for persistent-error detection.
    private var consecutiveErrorCount: Int = 0
    /// Number of consecutive errors before escalating to `.persistentError`.
    private let persistentErrorThreshold: Int = 3
    /// Coalesces rapid `checkAccountStatus` triggers (init + notifications + manual refresh).
    private var accountStatusTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        cloudKitContainerIdentifier: String = CloudKitConfiguration.containerIdentifier,
        historyCoordinator _: Any? = nil
    ) {
        container = CKContainer(identifier: cloudKitContainerIdentifier)
        scheduleAccountStatusCheck()
        startObserving()
    }

    // MARK: - Public API

    /// Manually trigger an account status refresh (e.g. after app becomes active).
    public func refreshAccountStatus() {
        scheduleAccountStatusCheck()
    }

    /// Clears the last error and resets state to idle.
    public func dismissError() {
        lastError = nil
        isErrorDismissed = true
        if syncState.isError {
            syncState = .idle
        }
    }

    // MARK: - Private Helpers

    private func startObserving() {
        // CloudKit container event changes (import/export/setup lifecycle)
        let eventName = NSNotification.Name("NSPersistentCloudKitContainerEventChangedNotification")
        let obs = NotificationCenter.default.addObserver(
            forName: eventName,
            object: nil,
            queue: nil  // Background queue — parse snapshot here, then hop to MainActor.
        ) { [weak self] notification in
            guard let event = notification.userInfo?["event"] else { return }
            let snapshot = CloudKitEventSnapshot(event: event)
            Task { @MainActor [weak self] in
                self?.apply(snapshot: snapshot)
            }
        }
        observationBag.add(obs)

        // iCloud account status changes
        let accountObs = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.CKAccountChanged,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleAccountStatusCheck()
            }
        }
        observationBag.add(accountObs)

        // Remote store changes are handled by SwiftData+CloudKit merges.
    }

    private func apply(snapshot: CloudKitEventSnapshot) {
        let eventType = CloudKitEventType(rawValue: snapshot.type)

        if let endDate = snapshot.endDate {
            // Event has finished
            if let errorMessage = snapshot.errorMessage {
                consecutiveErrorCount += 1
                let error = CloudKitSyncError(
                    message: errorMessage,
                    eventType: eventType?.label ?? "unknown",
                    date: endDate
                )
                lastError = error
                isErrorDismissed = false

                if consecutiveErrorCount >= persistentErrorThreshold {
                    syncState = .persistentError(errorMessage)
                    Logger.data.error("[CloudKitSync] Persistent sync error (\(self.consecutiveErrorCount) consecutive failures, type=\(eventType?.label ?? "?")): \(errorMessage)")
                } else {
                    syncState = .error(errorMessage)
                    Logger.data.error("[CloudKitSync] Sync error (type=\(eventType?.label ?? "?")): \(errorMessage)")
                }
            } else if snapshot.succeeded {
                consecutiveErrorCount = 0
                lastSyncDate = endDate
                syncState = .idle
                Logger.data.info("[CloudKitSync] Sync succeeded (type=\(eventType?.label ?? "?")) at \(endDate)")
            }
        } else {
            // Event is starting
            switch eventType {
            case .import: syncState = .importing
            case .export: syncState = .exporting
            default: break
            }
        }
    }

    private func scheduleAccountStatusCheck() {
        accountStatusTask?.cancel()
        accountStatusTask = Task { @MainActor in
            await checkAccountStatus()
        }
    }

    private func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            accountStatus = status
            Logger.data.info("[CloudKitSync] iCloud account status: \(status.rawValue)")
        } catch {
            Logger.data.error("[CloudKitSync] Could not check account status: \(error)")
            accountStatus = .couldNotDetermine
        }
    }
}

// MARK: - CloudKitSyncError

/// A structured representation of the last CloudKit sync error, surfaced to the UI.
public struct CloudKitSyncError: Equatable, Sendable, Identifiable {
    public var id: Date { date }
    public let message: String
    public let eventType: String
    public let date: Date
}

// MARK: - CloudKitEventSnapshot

private struct CloudKitEventSnapshot {
    let type: Int
    let endDate: Date?
    let succeeded: Bool
    let errorMessage: String?

    init(event: Any) {
        let mirror = Mirror(reflecting: event)

        type = Self.intValue(named: "type", in: mirror)
        endDate = Self.dateValue(named: "endDate", in: mirror)
        succeeded = Self.boolValue(named: "succeeded", in: mirror, default: false)
        errorMessage = Self.errorDescription(named: "error", in: mirror)
    }

    private static func intValue(named name: String, in mirror: Mirror) -> Int {
        guard let value = mirror.children.first(where: { $0.label == name })?.value else {
            return 0
        }
        if let intValue = value as? Int {
            return intValue
        }
        if let rawRepresentable = value as? any RawRepresentable,
           let rawInt = rawRepresentable.rawValue as? Int {
            return rawInt
        }
        return 0
    }

    private static func dateValue(named name: String, in mirror: Mirror) -> Date? {
        guard let value = mirror.children.first(where: { $0.label == name })?.value else {
            return nil
        }
        if let date = value as? Date {
            return date
        }
        if let optional = value as? Date? {
            return optional
        }
        return nil
    }

    private static func boolValue(named name: String, in mirror: Mirror, default fallback: Bool) -> Bool {
        guard let value = mirror.children.first(where: { $0.label == name })?.value else {
            return fallback
        }
        return value as? Bool ?? fallback
    }

    private static func errorDescription(named name: String, in mirror: Mirror) -> String? {
        guard let value = mirror.children.first(where: { $0.label == name })?.value else {
            return nil
        }
        if let error = value as? Error {
            return error.localizedDescription
        }
        if let optionalError = value as? Error?,
           let error = optionalError {
            return error.localizedDescription
        }
        return nil
    }
}

// MARK: - CKAccountStatus + Display

extension CKAccountStatus {
    public var displayText: String {
        switch self {
        case .available: return "iCloud Connected"
        case .noAccount: return "No iCloud Account"
        case .restricted: return "iCloud Restricted"
        case .couldNotDetermine: return "Checking iCloud…"
        case .temporarilyUnavailable: return "iCloud Temporarily Unavailable"
        @unknown default: return "Unknown"
        }
    }

    public var isAvailable: Bool { self == .available }
}

// MARK: - ObservationBag

private final class ObservationBag {
    private var observations: [NSObjectProtocol] = []

    func add(_ observation: NSObjectProtocol) {
        observations.append(observation)
    }

    deinit {
        for observation in observations {
            NotificationCenter.default.removeObserver(observation)
        }
    }
}

