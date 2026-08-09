import Core
import Foundation
import Observation

/// Queues navigation requested by App Intents until the active workspace scene consumes it.
///
/// `@MainActor`-isolated and `Sendable` for `AppDependencyManager` registration; all reads and writes
/// occur on the main actor.
@MainActor
@Observable
public final class WorkspaceIntentDeliveryCenter: Sendable {
    nonisolated public static let shared = WorkspaceIntentDeliveryCenter()

    public enum PendingNavigation: Sendable, Equatable {
        case selectTab(AppTab)
        case openClient(UUID)
    }

    public private(set) var pendingNavigation: PendingNavigation?

    public nonisolated init() {}

    public func enqueue(_ navigation: PendingNavigation) {
        pendingNavigation = navigation
    }

    public func consumePending() -> PendingNavigation? {
        defer { pendingNavigation = nil }
        return pendingNavigation
    }
}
