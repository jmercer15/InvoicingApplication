import SwiftUI
import Core
import SharedUI

struct ReconciliationDashboardContainer: View {
    let batchId: UUID
    @Bindable var viewModel: ClaimBatchesViewModel
    var onOpenDraft: ((UUID) -> Void)?

    var body: some View {
        DeferredSheetContent(
            minWidth: StyleGuide.Dimensions.settingsSheetStandardMinWidth,
            minHeight: StyleGuide.Dimensions.settingsSheetStandardMinHeight
        ) {
            ReconciliationDashboardView(
                batchId: batchId,
                viewModel: viewModel,
                onOpenDraft: onOpenDraft
            )
        }
    }
}
