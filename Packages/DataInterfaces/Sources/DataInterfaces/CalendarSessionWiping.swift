import Foundation

/// Deletes all persisted sessions (Settings calendar reset).
public protocol CalendarSessionWiping: Sendable {
    func wipeAllSessions() async throws
}
