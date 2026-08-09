import DataInterfaces

@MainActor
public enum NDISWorkspaceFactory {
    public struct Dependencies {
        public let catalogueFetching: any NDISCatalogueFetching
        public let storeChangeMonitor: (any StoreChangeMonitoring)?

        public init(
            catalogueFetching: any NDISCatalogueFetching,
            storeChangeMonitor: (any StoreChangeMonitoring)? = nil
        ) {
            self.catalogueFetching = catalogueFetching
            self.storeChangeMonitor = storeChangeMonitor
        }
    }

    public static func makeViewModel(
        _ dependencies: Dependencies
    ) -> NDISContainerViewModel {
        NDISContainerViewModel(
            catalogueFetching: dependencies.catalogueFetching,
            storeChangeMonitor: dependencies.storeChangeMonitor
        )
    }
}
