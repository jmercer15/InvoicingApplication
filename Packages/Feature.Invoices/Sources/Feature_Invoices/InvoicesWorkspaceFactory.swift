import SwiftData
import DataInterfaces

@MainActor
public enum InvoicesWorkspaceFactory {
    public struct Dependencies {
        public let modelContext: ModelContext
        public let storeChangeMonitor: (any StoreChangeMonitoring)?

        public init(
            modelContext: ModelContext,
            storeChangeMonitor: (any StoreChangeMonitoring)? = nil
        ) {
            self.modelContext = modelContext
            self.storeChangeMonitor = storeChangeMonitor
        }
    }

    public static func makeViewModel(_ dependencies: Dependencies) -> InvoicesContainerViewModel {
        return InvoicesContainerViewModel(
            modelContext: dependencies.modelContext,
            storeChangeMonitor: dependencies.storeChangeMonitor
        )
    }
}
