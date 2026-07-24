import Observation

/// Tracks which utility tool windows are currently on screen.
///
/// Separate from `ApplicationWorkspaceContext` so workspace windows can react to standalone
/// inspector / activity visibility without coupling layout state into app-wide context.
@MainActor
@Observable
public final class ToolWindowPresenceRegistry {
    public var inspectorStandaloneOpen = false
    public var activityMonitorOpen = false

    public init() {}

    public func setInspectorStandaloneOpen(_ isOpen: Bool) {
        inspectorStandaloneOpen = isOpen
    }

    public func setActivityMonitorOpen(_ isOpen: Bool) {
        activityMonitorOpen = isOpen
    }
}
