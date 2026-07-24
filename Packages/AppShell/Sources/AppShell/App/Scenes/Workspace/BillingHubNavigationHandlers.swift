import SharedUI
import Foundation

/// App-owned routing bridge used by feature views that surface related entities.
/// Feature packages emit stable UUIDs; AppShell owns tab/path mutation.
struct WorkspaceEntityNavigationHandlers {
    let openInvoice: (UUID) -> Void
    let openSession: (UUID) -> Void
    let openClient: (UUID) -> Void
    let openPayee: (UUID) -> Void
    let openPlanManager: (UUID) -> Void
    let openNDISItem: (UUID) -> Void
}

@MainActor
func makeWorkspaceEntityNavigationHandlers(
    navigationManager: AppNavigationManager
) -> WorkspaceEntityNavigationHandlers {
    WorkspaceEntityNavigationHandlers(
        openInvoice: { navigationManager.navigateToInvoice($0) },
        openSession: { navigationManager.navigateToSession($0) },
        openClient: { navigationManager.navigateToClient($0) },
        openPayee: { navigationManager.navigateToPayee($0) },
        openPlanManager: { navigationManager.navigateToPlanManager($0) },
        openNDISItem: { navigationManager.navigateToNDISItem($0) }
    )
}
