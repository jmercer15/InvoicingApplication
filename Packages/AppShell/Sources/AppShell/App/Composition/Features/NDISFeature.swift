import SwiftData
import DataInterfaces
import Feature_NDIS

@MainActor
final class NDISFeature {
    private struct Dependencies {
        let catalogueFetching: any NDISCatalogueFetching
        let storeChangeMonitor: any StoreChangeMonitoring
    }

    private let dependencies: Dependencies
    private var storage: NDISContainerViewModel?

    init(
        catalogueFetching: any NDISCatalogueFetching,
        storeChangeMonitor: any StoreChangeMonitoring
    ) {
        self.dependencies = Dependencies(
            catalogueFetching: catalogueFetching,
            storeChangeMonitor: storeChangeMonitor
        )
    }

    func viewModel() -> NDISContainerViewModel {
        if let storage {
            return storage
        }

        let viewModel = NDISWorkspaceFactory.makeViewModel(
            .init(
                catalogueFetching: dependencies.catalogueFetching,
                storeChangeMonitor: dependencies.storeChangeMonitor
            )
        )
        storage = viewModel
        return viewModel
    }
}
