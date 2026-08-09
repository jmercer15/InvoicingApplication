import Foundation
import SwiftData
import Core
import Data
import Observation
import SharedUI

/// Per-window UI state. Each workspace window owns independent navigation and feature view-model caches.
@MainActor
@Observable
final class WorkspaceSceneSession {
    struct Dependencies {
        let database: AppDatabase
        let services: AppRuntime.Services
        let ndisBillingIntegrationService: any Core.NDISBillingIntegrationServiceProtocol
        let modelContext: ModelContext

        init(
            database: AppDatabase,
            services: AppRuntime.Services,
            ndisBillingIntegrationService: any Core.NDISBillingIntegrationServiceProtocol,
            modelContext: ModelContext
        ) {
            self.database = database
            self.services = services
            self.ndisBillingIntegrationService = ndisBillingIntegrationService
            self.modelContext = modelContext
        }
    }

    let id = UUID()
    let navigationState: WorkspaceSceneNavigationState
    let features: WorkspaceFeatureRegistries

    var navigationManager: AppNavigationManager { navigationState.navigationManager }

    init(_ dependencies: Dependencies) {
        let database = dependencies.database
        let services = dependencies.services
        let ndisBillingIntegrationService = dependencies.ndisBillingIntegrationService
        let modelContext = dependencies.modelContext

        self.navigationState = WorkspaceSceneNavigationState()
        let complianceValidator = NDISComplianceValidator(modelContainer: database.container)

        self.features = WorkspaceFeatureRegistries(
            .init(
                database: database,
                context: modelContext,
                services: services,
                ndisComplianceValidator: complianceValidator,
                ndisBillingService: ndisBillingIntegrationService
            )
        )
    }
}

@MainActor
@Observable
final class WorkspaceSceneNavigationState {
    let navigationManager = AppNavigationManager()
}
