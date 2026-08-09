import SwiftData
import Data
import Feature_Clients

@MainActor
final class RelationshipsFeature {
    private struct Dependencies {
        let relationshipDeleter: any ClientRelationshipDeleting
        let storeChangeMonitor: SwiftDataStoreChangeMonitor
    }

    private let dependencies: Dependencies
    private var storage: RelationshipsContainerViewModel?

    init(
        context: ModelContext,
        relationshipDeleter: any ClientRelationshipDeleting,
        storeChangeMonitor: SwiftDataStoreChangeMonitor
    ) {
        self.dependencies = Dependencies(
            relationshipDeleter: relationshipDeleter,
            storeChangeMonitor: storeChangeMonitor
        )
    }

    func viewModel() -> RelationshipsContainerViewModel {
        if let storage {
            return storage
        }

        let viewModel = RelationshipsWorkspaceFactory.makeViewModel(
            .init(
                relationshipDeleter: dependencies.relationshipDeleter,
                storeChangeMonitor: dependencies.storeChangeMonitor
            )
        )
        dependencies.storeChangeMonitor.onRevisionChange { _ in
            AppShortcutParameterRefresh.refreshClientParameters()
        }
        storage = viewModel
        return viewModel
    }
}

import DataInterfaces
