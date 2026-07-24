import SwiftData
import Data

@MainActor
public enum RelationshipsWorkspaceFactory {
    public struct Dependencies {
        public let modelContext: ModelContext
        public let storeChangeMonitor: SwiftDataStoreChangeMonitor?

        public init(
            modelContext: ModelContext,
            storeChangeMonitor: SwiftDataStoreChangeMonitor? = nil
        ) {
            self.modelContext = modelContext
            self.storeChangeMonitor = storeChangeMonitor
        }
    }

    public static func makeViewModel(
        _ dependencies: Dependencies
    ) -> RelationshipsContainerViewModel {
        RelationshipsContainerViewModel(
            modelContext: dependencies.modelContext,
            storeChangeMonitor: dependencies.storeChangeMonitor
        )
    }
}
