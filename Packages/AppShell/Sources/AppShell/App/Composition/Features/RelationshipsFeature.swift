import SwiftData
import Data
import Feature_Clients

@MainActor
final class RelationshipsFeature {
    private struct Dependencies {
        let context: ModelContext
        let storeChangeMonitor: SwiftDataStoreChangeMonitor
    }

    private let dependencies: Dependencies
    private var storage: RelationshipsContainerViewModel?

    init(context: ModelContext, storeChangeMonitor: SwiftDataStoreChangeMonitor) {
        self.dependencies = Dependencies(context: context, storeChangeMonitor: storeChangeMonitor)
    }

    func viewModel() -> RelationshipsContainerViewModel {
        if let storage {
            return storage
        }

        let viewModel = RelationshipsWorkspaceFactory.makeViewModel(
            .init(
                modelContext: dependencies.context,
                storeChangeMonitor: dependencies.storeChangeMonitor
            )
        )
        storage = viewModel
        return viewModel
    }
}
