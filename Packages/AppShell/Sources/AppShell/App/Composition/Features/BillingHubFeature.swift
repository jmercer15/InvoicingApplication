import SwiftData
import Core
import Data
import Feature_BillingHub

@MainActor
final class BillingHubFeature {
    private struct Dependencies {
        let context: ModelContext
        let database: AppDatabase
        let ndisBillingService: any NDISBillingIntegrationServiceProtocol
        let complianceValidator: NDISComplianceValidator
        let storeChangeMonitor: SwiftDataStoreChangeMonitor
    }

    private let dependencies: Dependencies
    private var storage: BillingHubViewModel?

    init(
        context: ModelContext,
        database: AppDatabase,
        ndisBillingService: any NDISBillingIntegrationServiceProtocol,
        complianceValidator: NDISComplianceValidator,
        storeChangeMonitor: SwiftDataStoreChangeMonitor
    ) {
        self.dependencies = Dependencies(
            context: context,
            database: database,
            ndisBillingService: ndisBillingService,
            complianceValidator: complianceValidator,
            storeChangeMonitor: storeChangeMonitor
        )
    }

    func viewModel() -> BillingHubViewModel {
        if let storage {
            return storage
        }

        let viewModel = BillingHubWorkspaceFactory.makeViewModel(
            .init(
                modelContext: dependencies.context,
                modelContainer: dependencies.database.container,
                ndisBillingIntegrationService: dependencies.ndisBillingService,
                complianceValidator: dependencies.complianceValidator,
                storeChangeMonitor: dependencies.storeChangeMonitor
            )
        )
        storage = viewModel
        return viewModel
    }
}
