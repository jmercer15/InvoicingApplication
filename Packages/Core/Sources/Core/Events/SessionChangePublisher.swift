import Foundation
import Combine

/// Publisher for session change events across features.
/// Used to coordinate refresh between Calendar, Billing Hub, and Invoices side effects.
@MainActor
public final class SessionChangePublisher: ObservableObject {
    public static let shared = SessionChangePublisher()

    /// Published when a specific session changes.
    public let sessionChanged = PassthroughSubject<UUID, Never>()

    /// Published when any session change requires a full refresh.
    public let sessionsRefreshNeeded = PassthroughSubject<Void, Never>()

    private init() {}

    /// Notify that a specific session has changed.
    public func notifyChange(sessionId: UUID) {
        sessionChanged.send(sessionId)
        sessionsRefreshNeeded.send()
    }

    /// Notify that sessions need to be refreshed (for batch operations).
    public func notifyRefreshNeeded() {
        sessionsRefreshNeeded.send()
    }
}
