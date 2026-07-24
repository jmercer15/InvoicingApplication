import SwiftData
import Data
import Feature_Invoices

@MainActor
final class InvoicesFeature {
    private struct Dependencies {
        let context: ModelContext
        let storeChangeMonitor: SwiftDataStoreChangeMonitor?
    }

    private let dependencies: Dependencies
    private var storage: InvoicesContainerViewModel?

    init(
        context: ModelContext,
        storeChangeMonitor: SwiftDataStoreChangeMonitor?
    ) {
        self.dependencies = Dependencies(
            context: context,
            storeChangeMonitor: storeChangeMonitor
        )
    }

    func viewModel() -> InvoicesContainerViewModel {
        if let storage {
            return storage
        }

        let viewModel = InvoicesWorkspaceFactory.makeViewModel(
            .init(
                modelContext: dependencies.context,
                storeChangeMonitor: dependencies.storeChangeMonitor
            )
        )
        storage = viewModel
        return viewModel
    }
}
