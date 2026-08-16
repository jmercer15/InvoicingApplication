import SwiftUI
import Core
import SharedUI

struct TravelChargeReviewContainer: View {
    let viewModel: TravelChargeReviewViewModel

    var body: some View {
        DeferredSheetContent(
            minWidth: StyleGuide.Dimensions.settingsSheetLargeMinWidth,
            minHeight: StyleGuide.Dimensions.settingsTravelReviewMinHeight
        ) {
            TravelChargeReviewView(viewModel: viewModel)
        }
    }
}
