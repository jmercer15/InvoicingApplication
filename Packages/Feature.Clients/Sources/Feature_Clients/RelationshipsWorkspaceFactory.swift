import SwiftData
import DataInterfaces

@MainActor
public enum RelationshipsWorkspaceFactory {
    public struct Dependencies {
        public let relationshipDeleter: any ClientRelationshipDeleting
        public let storeChangeMonitor: (any StoreChangeMonitoring)?

        public init(
            relationshipDeleter: any ClientRelationshipDeleting,
            storeChangeMonitor: (any StoreChangeMonitoring)? = nil
        ) {
            self.relationshipDeleter = relationshipDeleter
            self.storeChangeMonitor = storeChangeMonitor
        }
    }

    public static func makeViewModel(
        _ dependencies: Dependencies
    ) -> RelationshipsContainerViewModel {
        RelationshipsContainerViewModel(
            relationshipDeleter: dependencies.relationshipDeleter,
            storeChangeMonitor: dependencies.storeChangeMonitor
        )
    }
}
