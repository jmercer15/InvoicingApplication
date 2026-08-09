import Foundation

/// Calendar synchronization preferences
public struct CalendarPreferences {
    /// Sync direction options
    public enum SyncDirection: String, CaseIterable, Codable, Sendable {
        case bidirectional = "bidirectional"
        case calendarToApp = "calendarToApp"
        case appToCalendar = "appToCalendar"

        public var displayName: String {
            switch self {
            case .bidirectional:
                return "Bidirectional"
            case .calendarToApp:
                return "Calendar to App Only"
            case .appToCalendar:
                return "App to Calendar Only"
            }
        }
    }

    /// Conflict resolution policy
    public enum ConflictResolutionPolicy: String, CaseIterable, Codable, Sendable {
        case prompt = "prompt"
        case preferApp = "preferApp"
        case preferCalendar = "preferCalendar"
        case localWins = "localWins"
        case remoteWins = "remoteWins"

        public var displayName: String {
            switch self {
            case .prompt:
                return "Prompt User"
            case .preferApp, .localWins:
                return "Prefer App Data"
            case .preferCalendar, .remoteWins:
                return "Prefer Calendar Data"
            }
        }
    }
}
