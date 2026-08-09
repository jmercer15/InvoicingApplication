import Foundation
import SharedUI

/// Cross-feature navigation from the Activity tool window must target the main
/// workspace session — never an orphan Activity fallback `AppNavigationManager`.
@MainActor
enum ActivityCrossFeatureNavigation {
    enum Destination: Equatable, Sendable {
        case session(UUID)
        case invoice(UUID)
    }

    /// Returns the workspace navigation manager when one is available.
    static func navigationManager(
        for activeWorkspace: WorkspaceSceneSession?
    ) -> AppNavigationManager? {
        activeWorkspace?.navigationManager
    }

    static func apply(
        _ destination: Destination,
        on navigationManager: AppNavigationManager
    ) {
        switch destination {
        case .session(let id):
            navigationManager.navigateToSession(id)
        case .invoice(let id):
            navigationManager.navigateToInvoice(id)
        }
    }
}
