import Foundation

/// Protocol for calendar synchronization operations
@MainActor
public protocol SyncService: Sendable {
    /// Check if access is granted
    var accessGranted: Bool { get }
    
    /// Check if sync is enabled
    var syncEnabled: Bool { get }
    
    /// Last sync date
    var lastSyncDate: Date? { get }
    
    /// Sync status
    var syncStatus: SyncStatus { get }
    
    /// Available calendars
    var availableCalendars: [CalendarInfo] { get }
    
    /// Monitored calendar identifiers
    var monitoredCalendarIdentifiers: Set<String> { get }
    
    /// Request calendar access
    func requestAccess() async throws -> Bool
    
    /// Enable/disable sync
    func setSyncEnabled(_ enabled: Bool) async
    
    /// Sync a session to calendar
    func sync(session: SessionSnapshot) async throws
    
    /// Delete session from calendar
    func delete(syncIdentifier: String) async throws
    
    /// Update session in calendar
    func update(session: SessionSnapshot) async throws
    
    /// Fetch events from calendar
    func fetchEvents(start: Date, end: Date) async throws -> [CalendarEvent]
    
    /// Update session from remote event
    func updateSessionFromRemote(session: SessionSnapshot, remoteEvent: CalendarEvent) async throws -> SessionSnapshot
    
    /// Handle external changes
    func handleExternalChanges() async throws
}

/// Calendar sync status
public enum SyncStatus: String, CaseIterable, Sendable {
    case idle = "idle"
    case syncing = "syncing"
    case error = "error"
    case disabled = "disabled"
    
    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .syncing: return "Syncing"
        case .error: return "Error"
        case .disabled: return "Disabled"
        }
    }
    
    public var description: String {
        return displayName
    }
}

/// Calendar information
public struct CalendarInfo: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let color: String?
    public let isEnabled: Bool
    
    public init(id: String, title: String, color: String? = nil, isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.color = color
        self.isEnabled = isEnabled
    }
}

/// Calendar event information
public struct CalendarEvent: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let location: String?
    public let notes: String?
    public let calendarIdentifier: String
    public let lastModifiedDate: Date?
    
    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        calendarIdentifier: String,
        lastModifiedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.calendarIdentifier = calendarIdentifier
        self.lastModifiedDate = lastModifiedDate
    }
}

// MARK: - Type Alias for Naming Consistency

/// Type alias for consistent naming convention across protocols.
public typealias SyncServiceProtocol = SyncService
