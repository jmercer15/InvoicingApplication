import SwiftUI
import Core
import SharedUI

struct ClaimBatchBuildWizardContainer: View {
    @Bindable var viewModel: ClaimBatchesViewModel
    let initialDraftIds: Set<UUID>?

    init(viewModel: ClaimBatchesViewModel, initialDraftIds: Set<UUID>? = nil) {
        self.viewModel = viewModel
        self.initialDraftIds = initialDraftIds
    }

    var body: some View {
        DeferredSheetContent(
            minWidth: StyleGuide.Dimensions.settingsSheetMinWidth,
            minHeight: StyleGuide.Dimensions.settingsSheetMinHeight
        ) {
            ClaimBatchBuildWizardView(viewModel: viewModel, initialDraftIds: initialDraftIds)
        }
    }
}
