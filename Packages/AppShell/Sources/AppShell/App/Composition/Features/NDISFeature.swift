import SwiftData
import Data
import Feature_NDIS

@MainActor
final class NDISFeature {
    private struct Dependencies {
        let context: ModelContext
        let storeChangeMonitor: SwiftDataStoreChangeMonitor
    }

    private let dependencies: Dependencies
    private var storage: NDISContainerViewModel?

    init(context: ModelContext, storeChangeMonitor: SwiftDataStoreChangeMonitor) {
        self.dependencies = Dependencies(context: context, storeChangeMonitor: storeChangeMonitor)
    }

    func viewModel() -> NDISContainerViewModel {
        if let storage {
            return storage
        }

        let viewModel = NDISWorkspaceFactory.makeViewModel(
            .init(
                modelContext: dependencies.context,
                storeChangeMonitor: dependencies.storeChangeMonitor
            )
        )
        storage = viewModel
        return viewModel
    }
}
