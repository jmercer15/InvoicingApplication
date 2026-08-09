import SwiftData
import Core
import DataInterfaces
import InvoiceTableLayoutEditor

@MainActor
public enum BillingHubWorkspaceFactory {
    public struct Dependencies {
        public let modelContext: ModelContext
        public let modelContainer: ModelContainer
        public let ndisBillingIntegrationService: any NDISBillingIntegrationServiceProtocol
        public let complianceValidator: any ComplianceValidating
        public let storeChangeMonitor: (any StoreChangeMonitoring)?
        public let invoiceEditorSession: InvoiceEditorSession?

        public init(
            modelContext: ModelContext,
            modelContainer: ModelContainer,
            ndisBillingIntegrationService: any NDISBillingIntegrationServiceProtocol,
            complianceValidator: any ComplianceValidating,
            storeChangeMonitor: (any StoreChangeMonitoring)? = nil,
            invoiceEditorSession: InvoiceEditorSession? = nil
        ) {
            self.modelContext = modelContext
            self.modelContainer = modelContainer
            self.ndisBillingIntegrationService = ndisBillingIntegrationService
            self.complianceValidator = complianceValidator
            self.storeChangeMonitor = storeChangeMonitor
            self.invoiceEditorSession = invoiceEditorSession
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
            storeChangeMonitor: dependencies.storeChangeMonitor,
            invoiceEditorSession: dependencies.invoiceEditorSession
        )
    }
}
