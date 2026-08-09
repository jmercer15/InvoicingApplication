import SwiftData
import Core
import Data
import Feature_BillingHub
import Feature_Calendar
import Feature_Clients
import Feature_Invoices
import Feature_NDIS
import InvoiceTableLayoutEditor

/// Strangler facade over workspace-scoped feature VMs. Owns concrete feature wrappers directly and
/// exposes stable feature outputs to scene consumers.
///
/// Lifetime: one instance per [`WorkspaceSceneSession`].
@MainActor
final class WorkspaceFeatureRegistries {
    public struct Dependencies {
        public let database: AppDatabase
        public let context: ModelContext
        public let services: AppRuntime.Services
        public let ndisComplianceValidator: NDISComplianceValidator
        public let ndisBillingService: any NDISBillingIntegrationServiceProtocol

        public init(
            database: AppDatabase,
            context: ModelContext,
            services: AppRuntime.Services,
            ndisComplianceValidator: NDISComplianceValidator,
            ndisBillingService: any NDISBillingIntegrationServiceProtocol
        ) {
            self.database = database
            self.context = context
            self.services = services
            self.ndisComplianceValidator = ndisComplianceValidator
            self.ndisBillingService = ndisBillingService
        }
    }

    private let calendarFeature: CalendarFeature
    private let billingHubFeature: BillingHubFeature
    private let relationshipsFeature: RelationshipsFeature
    private let ndisFeature: NDISFeature
    private let invoicesFeature: InvoicesFeature

    init(_ dependencies: Dependencies) {
        let calendarFeature = CalendarFeature(context: dependencies.context, services: dependencies.services)
        self.calendarFeature = calendarFeature
        self.billingHubFeature = BillingHubFeature(
            context: dependencies.context,
            database: dependencies.database,
            ndisBillingService: dependencies.ndisBillingService,
            complianceValidator: dependencies.ndisComplianceValidator,
            storeChangeMonitor: dependencies.services.storeChangeMonitor
        )
        self.relationshipsFeature = RelationshipsFeature(
            context: dependencies.context,
            relationshipDeleter: SwiftDataClientRelationshipDeleter(modelContext: dependencies.context),
            storeChangeMonitor: dependencies.services.storeChangeMonitor
        )
        self.ndisFeature = NDISFeature(
            catalogueFetching: dependencies.services.ndisCatalogueFetching,
            storeChangeMonitor: dependencies.services.storeChangeMonitor
        )
        self.invoicesFeature = InvoicesFeature(
            context: dependencies.context,
            storeChangeMonitor: dependencies.services.storeChangeMonitor
        )
    }

    func calendarViewModel() -> CalendarViewModel { calendarFeature.viewModel() }
    func billingHubViewModel() -> BillingHubViewModel {
        let hub = billingHubFeature.viewModel()
        // Prefer live editor draft PDFs when that invoice is open in Invoices.
        if hub.invoiceEditorSession == nil {
            hub.invoiceEditorSession = invoicesFeature.viewModel().editorSession
        }
        return hub
    }
    func relationshipsViewModel() -> RelationshipsContainerViewModel { relationshipsFeature.viewModel() }
    func ndisCatalogueViewModel() -> NDISContainerViewModel { ndisFeature.viewModel() }
    func invoicesViewModel() -> InvoicesContainerViewModel { invoicesFeature.viewModel() }

    var calendar: CalendarViewModel { calendarViewModel() }
    var billingHub: BillingHubViewModel { billingHubViewModel() }
    var relationships: RelationshipsContainerViewModel { relationshipsViewModel() }
    var ndisCatalogue: NDISContainerViewModel { ndisCatalogueViewModel() }
    var invoices: InvoicesContainerViewModel { invoicesViewModel() }
}
