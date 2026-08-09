import PersistenceModels
import SwiftUI
import SwiftData
import Feature_Invoices
import Feature_Clients
import Feature_NDIS
import SharedUI

struct InspectorPlaceholderView: View {
    let features: WorkspaceFeatureRegistries
    let navigationManager: AppNavigationManager

    var body: some View {
        SmartInspectorResolverView(
            features: features,
            navigationManager: navigationManager
        )
            .frame(
                minWidth: StyleGuide.Dimensions.workspaceInspectorPlaceholderMinWidth,
                minHeight: StyleGuide.Dimensions.workspaceInspectorPlaceholderMinHeight
            )
    }
}
