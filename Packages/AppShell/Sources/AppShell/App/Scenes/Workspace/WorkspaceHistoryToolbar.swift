import SwiftUI
import SharedUI

struct WorkspaceHistoryToolbar: ToolbarContent {
    let canNavigateBack: Bool
    let canNavigateForward: Bool
    let navigateBack: () -> Void
    let navigateForward: () -> Void

    var body: some ToolbarContent {
        AppToolbarHistoryNavigation(
            canNavigateBack: canNavigateBack,
            canNavigateForward: canNavigateForward,
            navigateBack: navigateBack,
            navigateForward: navigateForward
        )
    }
}
