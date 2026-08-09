import Foundation
import SharedUI

/// Applies queued intent navigation to a workspace session when that session is the active window.
@MainActor
enum WorkspaceIntentNavigationDelivery {
    /// Returns whether pending navigation was consumed.
    @discardableResult
    static func applyPendingIfNeeded(
        delivery: WorkspaceIntentDeliveryCenter,
        sceneSession: WorkspaceSceneSession,
        workspaceContext: ApplicationWorkspaceContext
    ) -> Bool {
        applyPendingIfNeeded(
            delivery: delivery,
            navigationManager: sceneSession.navigationManager,
            isActiveWorkspace: workspaceContext.isActive(sceneSession)
        )
    }

    @discardableResult
    static func applyPendingIfNeeded(
        delivery: WorkspaceIntentDeliveryCenter,
        navigationManager: AppNavigationManager,
        isActiveWorkspace: Bool
    ) -> Bool {
        guard isActiveWorkspace else { return false }
        guard let pending = delivery.pendingNavigation else { return false }
        WorkspaceExternalNavigation.apply(pending, using: navigationManager)
        _ = delivery.consumePending()
        return true
    }
}
