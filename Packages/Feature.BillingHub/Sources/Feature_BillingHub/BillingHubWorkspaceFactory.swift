import SwiftData
import Core
import Data

@MainActor
public enum BillingHubWorkspaceFactory {
    public struct Dependencies {
        public let modelContext: ModelContext
        public let modelContainer: ModelContainer
        public let ndisBillingIntegrationService: any NDISBillingIntegrationServiceProtocol
        public let complianceValidator: NDISComplianceValidator
        public let storeChangeMonitor: SwiftDataStoreChangeMonitor?

        public init(
            modelContext: ModelContext,
            modelContainer: ModelContainer,
            ndisBillingIntegrationService: any NDISBillingIntegrationServiceProtocol,
            complianceValidator: NDISComplianceValidator,
            storeChangeMonitor: SwiftDataStoreChangeMonitor? = nil
        ) {
            self.modelContext = modelContext
            self.modelContainer = modelContainer
            self.ndisBillingIntegrationService = ndisBillingIntegrationService
            self.complianceValidator = complianceValidator
            self.storeChangeMonitor = storeChangeMonitor
        }
    }

    public static func makeViewModel(
        _ dependencies: Dependencies
    ) -> BillingHubViewModel {
        BillingHubViewModel(
            modelContext: dependencies.modelContext,
            modelContainer: dependencies.modelContainer,
            ndisBillingIntegrationService: dependencies.ndisBillingIntegrationService,
            complianceValidator: dependencies.complianceValidator,
            storeChangeMonitor: dependencies.storeChangeMonitor
        )
    }
}
