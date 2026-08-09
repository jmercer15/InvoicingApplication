import SharedUI
import SwiftData
import SwiftUI
import Observation

public struct ClaimBatchesHomeView: View {
    @Bindable var viewModel: ClaimBatchesViewModel

    @State private var showNewBatchWizard = false

    public init(viewModel: ClaimBatchesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ClaimBatchesQueryList()
            .navigationTitle("Claim Batches")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    AppToolbarPrimaryCreateButton(
                        "New Batch",
                        systemImage: "plus.rectangle.on.rectangle",
                        help: "Create a new NDIS claim batch"
                    ) {
                        showNewBatchWizard = true
                    }
                }
            }
            .sheet(isPresented: $showNewBatchWizard) {
                ClaimBatchBuildWizardContainer(viewModel: viewModel)
            }
            .navigationDestination(for: UUID.self) { batchId in
                ClaimBatchDetailView(batchId: batchId, viewModel: viewModel)
            }
        }
    }
}
