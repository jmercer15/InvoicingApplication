import Core
import SharedUI

@MainActor
enum WorkspaceExternalNavigation {
    static func apply(
        _ navigation: WorkspaceIntentDeliveryCenter.PendingNavigation,
        using navigationManager: AppNavigationManager
    ) {
        switch navigation {
        case .selectTab(let tab):
            navigationManager.selectTab(tab)
        case .openClient(let clientID):
            navigationManager.navigateToClient(clientID)
        }
    }
}
