import SharedUI
import SwiftUI
import Observation

public struct ClaimBatchesContainerView: View {
    @Bindable var viewModel: ClaimBatchesViewModel

    public init(viewModel: ClaimBatchesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ClaimBatchesHomeView(viewModel: viewModel)
    }
}
