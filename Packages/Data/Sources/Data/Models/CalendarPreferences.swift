import Foundation

/// Calendar synchronization preferences
public struct CalendarPreferences {
    
    /// Sync direction options
    public enum SyncDirection: String, CaseIterable {
        case bidirectional = "bidirectional"
        case calendarToApp = "calendarToApp"
        case appToCalendar = "appToCalendar"
    }
    
    /// Conflict resolution policy
    public enum ConflictResolutionPolicy: String, CaseIterable {
        case prompt = "prompt"
        case preferApp = "preferApp"
        case preferCalendar = "preferCalendar"
        case localWins = "localWins"
        case remoteWins = "remoteWins"
    }
}
