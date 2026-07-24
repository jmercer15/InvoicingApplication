import Observation

@MainActor
protocol WorkspaceSceneSessionReference: AnyObject {}

extension WorkspaceSceneSession: WorkspaceSceneSessionReference {}

/// App-wide transient state injected through SwiftUI scenes.
@MainActor
@Observable
public final class ApplicationWorkspaceContext {
    /// Last active workspace session. Utility windows live in separate SwiftUI scenes, so focused
    /// values cannot bridge their feature/navigation state from a workspace window.
    private var activeWorkspaceSessionReference: (any WorkspaceSceneSessionReference)?

    var activeWorkspaceSceneSession: WorkspaceSceneSession? {
        activeWorkspaceSessionReference as? WorkspaceSceneSession
    }

    public init() {}

    func activate(_ session: any WorkspaceSceneSessionReference) {
        guard activeWorkspaceSessionReference !== session else { return }
        activeWorkspaceSessionReference = session
    }

    func isActive(_ session: any WorkspaceSceneSessionReference) -> Bool {
        activeWorkspaceSessionReference === session
    }

    func release(_ session: any WorkspaceSceneSessionReference) {
        guard activeWorkspaceSessionReference === session else { return }
        activeWorkspaceSessionReference = nil
    }
}
