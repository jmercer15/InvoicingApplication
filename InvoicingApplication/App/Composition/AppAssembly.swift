import Foundation
import SwiftData
import Core
import Data
import SharedUI
import Feature_Calendar
import Feature_BillingHub
import Feature_Clients
import Feature_Invoices
import Feature_InvoiceTemplateEditor
import Feature_NDIS
import Feature_Settings

/// Main dependency injection container for the application
public class AppAssembly: ObservableObject, AppAssemblyProviding {
    
    // MARK: - Core Dependencies
    
    /// Model container for SwiftData
    public let modelContainer: ModelContainer
    /// Shared model context for all repositories (created on main thread)
    private let modelContext: ModelContext
    
    /// Unit of Work Service
    @MainActor
    public lazy var unitOfWork: UnitOfWorkService = SwiftDataUnitOfWork(modelContext: modelContext, modelContainer: modelContainer)
    
    // MARK: - Data Layer
    
    /// Enable repository monitoring (performance logging)
    private let enableMonitoring: Bool
    private let enableIntegrityChecks: Bool
    
    /// Repository implementations
    @MainActor public lazy var sessionsRepository: SessionsRepository = {
        var base: any SessionsRepository = SessionsRepositorySwiftData(modelContext: modelContext)
        if enableIntegrityChecks {
            base = SessionsIntegrityDecorator(wrapped: base)
        }
        if enableMonitoring {
            base = SessionsMonitoringDecorator(wrapped: base)
        }
        return base
    }()
    
    @MainActor public lazy var invoicesRepository: InvoicesRepository = InvoicesRepositorySwiftData(modelContext: modelContext)
    
    @MainActor public lazy var clientsRepository: ClientsRepository = {
        var base: any ClientsRepository = ClientsRepositorySwiftData(modelContext: modelContext)
        if enableIntegrityChecks {
            base = ClientsIntegrityDecorator(wrapped: base)
        }
        if enableMonitoring {
            base = ClientsMonitoringDecorator(wrapped: base)
        }
        return base
    }()
    
    @MainActor public lazy var clientServicesRepository: ClientServicesRepository = ClientServicesRepositorySwiftData(modelContext: modelContext)
    @MainActor public lazy var ndisItemsRepository: NDISItemRepository = NDISItemRepositorySwiftData(modelContext: modelContext)
    @MainActor public lazy var payeesRepository: PayeeRepository = PayeeRepositorySwiftData(modelContext: modelContext)
    @MainActor public lazy var businessRepository: BusinessRepository = BusinessRepositorySwiftData(modelContext: modelContext)
    @MainActor public lazy var planManagersRepository: PlanManagerRepository = PlanManagerRepositorySwiftData(modelContext: modelContext)
    @MainActor public lazy var addressRepository: AddressRepository = AddressRepositorySwiftData(modelContext: modelContext)
    @MainActor public lazy var travelChargeRepository: TravelChargeRepository = TravelChargeRepositorySwiftData(modelContext: modelContext)
    @MainActor public lazy var serviceAgreementRepository: ServiceAgreementRepository = ServiceAgreementRepositorySwiftData(modelContext: modelContext)
    @MainActor public lazy var supportLogRepository: SupportLogRepository = SupportLogRepositorySwiftData(modelContext: modelContext)
    @MainActor public lazy var bulkClaimRepository: BulkClaimRepository = BulkClaimRepositorySwiftData(modelContext: modelContext)

    @MainActor public lazy var ndisComplianceValidator: NDISComplianceValidator = NDISComplianceValidator(
        businessRepository: businessRepository,
        invoicesRepository: invoicesRepository,
        sessionsRepository: sessionsRepository,
        serviceAgreementRepository: serviceAgreementRepository,
        supportLogRepository: supportLogRepository
    )
    /// External services
    public lazy var syncService: SyncService = EventKitSyncServiceAdapter(unitOfWork: unitOfWork)
    
    // MARK: - Domain Services
    
    /// Session Domain Service
    public lazy var sessionDomainService: SessionDomainServiceProtocol = SessionDomainService(
        unitOfWork: unitOfWork,
        syncService: syncService
    )

    public lazy var invoiceDomainService: InvoiceDomainServiceProtocol = InvoiceDomainService(unitOfWork: unitOfWork)
    
    public lazy var ndisDomainService: NDISBillingDomainServiceProtocol = NDISBillingDomainService(unitOfWork: unitOfWork)
    
    // MARK: - Use Cases

    /// Data import/export use cases
    public lazy var importAllData: ImportAllData = ImportAllData(importer: UnifiedImportServiceAdapter(modelContainer: modelContainer))
    public lazy var exportAllData: ExportAllData = ExportAllData(exporter: UnifiedExportServiceAdapter(modelContainer: modelContainer))
    
    // MARK: - Feature ViewModels

    @MainActor private lazy var calendarContainerViewModel: CalendarContainerViewModel = CalendarContainerViewModel(
        unitOfWork: unitOfWork,
        sessionDomainService: sessionDomainService
    )

    @MainActor private lazy var billingHubViewModel: BillingHubViewModel = BillingHubViewModel(
        sessionsRepository: sessionsRepository,
        invoicesRepository: invoicesRepository,
        clientsRepository: clientsRepository,
        clientServicesRepository: clientServicesRepository,
        travelChargeRepository: travelChargeRepository,
        ndisBillingIntegrationService: ndisBillingService,
        complianceValidator: ndisComplianceValidator,
        supportLogRepository: supportLogRepository
    )

    @MainActor private lazy var relationshipsContainerViewModel: RelationshipsContainerViewModel = RelationshipsContainerViewModel(
        unitOfWork: unitOfWork,
        navigationManager: AppNavigationManager.shared
    )

    @MainActor private lazy var settingsViewModel: SettingsViewModel = SettingsViewModel(
        syncService: syncService,
        importAllData: importAllData,
        exportAllData: exportAllData
    )

    @MainActor private lazy var settingsWorkspaceViewModel: SettingsWorkspaceViewModel = SettingsWorkspaceViewModel(
        unitOfWork: unitOfWork,
        dataImporterActor: dataImporterActor,
        dataExporterActor: dataExporterActor
    )

    @MainActor private lazy var ndisContainerViewModel: NDISContainerViewModel = NDISContainerViewModel(unitOfWork: unitOfWork)

    @MainActor
    private lazy var templateEditorWorkspaceViewModel: TemplateEditorWorkspaceViewModel = {
        let editorViewModel = InvoiceTemplateEditorViewModel(templateManager: templateManager)
        return TemplateEditorWorkspaceViewModel(
            templateManager: templateManager,
            editorViewModel: editorViewModel
        )
    }()
    
    /// Calendar feature
    func makeCalendarViewModel() -> CalendarViewModel {
        CalendarViewModel(
            unitOfWork: unitOfWork,
            sessionDomainService: sessionDomainService,
            eventKitService: EventKitSyncService.shared
        )
    }
    
    /// Calendar Container ViewModel factory
    func makeCalendarContainerViewModel() -> CalendarContainerViewModel {
        calendarContainerViewModel
    }
    
    /// Billing Hub feature
    func makeBillingHubViewModel() -> BillingHubViewModel {
        billingHubViewModel
    }
    
    /// Clients feature
    func makeClientsViewModel() -> ClientsViewModel {
        ClientsViewModel(
            unitOfWork: unitOfWork
        )
    }
    
    /// Client Detail ViewModel factory
    func makeClientDetailViewModel(client: Client, isCreating: Bool) -> ClientDetailViewModel {
        ClientDetailViewModel(
            client: client,
            unitOfWork: unitOfWork,
            isCreating: isCreating
        )
    }
    
    /// Invoices feature
    @MainActor
    private lazy var invoicesContainerViewModel: InvoicesContainerViewModel = InvoicesContainerViewModel(
        invoicesRepository: invoicesRepository,
        clientServicesRepository: clientServicesRepository,
        clientsRepository: clientsRepository,
        payeesRepository: payeesRepository,
        planManagersRepository: planManagersRepository,
        sharingService: sharingService,
        complianceValidator: ndisComplianceValidator
    )

    @MainActor
    func makeInvoicesViewModel() -> InvoicesContainerViewModel {
        invoicesContainerViewModel
    }
    
    /// Relationships feature
    func makeRelationshipsViewModel() -> RelationshipsContainerViewModel {
        relationshipsContainerViewModel
    }
    
    /// Payee Detail ViewModel factory
    func makePayeeDetailViewModel(payee: Payee, isCreating: Bool) -> PayeeDetailViewModel {
        PayeeDetailViewModel(
            payee: payee,
            unitOfWork: unitOfWork,
            isCreating: isCreating
        )
    }
    
    /// Plan Manager Detail ViewModel factory
    func makePlanManagerDetailViewModel(planManager: PlanManager, isCreating: Bool) -> PlanManagerDetailViewModel {
        PlanManagerDetailViewModel(
            planManager: planManager,
            unitOfWork: unitOfWork,
            isCreating: isCreating
        )
    }
    
    /// Settings feature
    @MainActor
    func makeSettingsViewModel() -> SettingsViewModel {
        settingsViewModel
    }

    @MainActor
    func makeSettingsWorkspaceViewModel() -> SettingsWorkspaceViewModel {
        settingsWorkspaceViewModel
    }
    
    @MainActor
    func makeImportExportViewModel() -> ImportExportViewModel {
        ImportExportViewModel(
            unitOfWork: unitOfWork,
            dataImporterActor: makeDataImporterActor(),
            dataExporterActor: makeDataExporterActor()
        )
    }

    func makeCalendarSettingsViewModel() -> CalendarSettingsViewModel {
        CalendarSettingsViewModel(unitOfWork: unitOfWork)
    }

    func makeTravelChargeAutomationViewModel() -> TravelChargeAutomationViewModel {
        TravelChargeAutomationViewModel(unitOfWork: unitOfWork)
    }

    func makeTravelChargeReviewViewModel() -> TravelChargeReviewViewModel {
        TravelChargeReviewViewModel(unitOfWork: unitOfWork)
    }

    func makeCompanyViewModel() -> CompanyViewModel {
        CompanyViewModel(
            unitOfWork: unitOfWork,
            geocodingService: GeocodingService.shared
        )
    }
    
    /// Template Editor feature
    func makeTemplateEditorWorkspace() -> TemplateEditorWorkspaceViewModel {
        templateEditorWorkspaceViewModel
    }
    
    /// NDIS Billing Integration Service
    public lazy var ndisBillingService: NDISBillingIntegrationService = {
        let billingService = NDISBillingService(unitOfWork: unitOfWork, modelContext: modelContext)
        return NDISBillingIntegrationService(
            invoicesRepository: invoicesRepository,
            clientsRepository: clientsRepository,
            businessRepository: businessRepository,
            clientServicesRepository: clientServicesRepository,
            ndisItemsRepository: ndisItemsRepository,
            billingService: billingService,
            unitOfWork: unitOfWork
        )
    }()
    
    /// NDIS Container ViewModel factory
    func makeNDISContainerViewModel() -> NDISContainerViewModel {
        ndisContainerViewModel
    }
    
    /// Template Manager for template operations
    public lazy var templateManager: TemplateManager = TemplateManager()
    
    /// Template Data Service for preview data
    public lazy var templateDataService: TemplateDataService = TemplateDataService(
        invoicesRepository: invoicesRepository,
        clientsRepository: clientsRepository,
        businessRepository: businessRepository,
        payeeRepository: payeesRepository
    )
    
    /// Invoice Sharing Service for PDF export
    public lazy var sharingService: InvoiceSharingService = InvoiceSharingService(
        templateManager: templateManager,
        templateDataService: templateDataService
    )
    
    @MainActor private lazy var dataExporterActor: DataExporterActor = DataExporterActor(modelContainer: modelContainer)

    @MainActor private lazy var dataImporterActor: DataImporterActor = DataImporterActor(modelContainer: modelContainer)

    /// Data Exporter Actor factory
    @MainActor
    public func makeDataExporterActor() -> DataExporterActor {
        dataExporterActor
    }
    
    /// Data Importer Actor factory
    @MainActor
    public func makeDataImporterActor() -> DataImporterActor {
        dataImporterActor
    }
    
    // MARK: - Initialization
    
    /// Initializes the AppAssembly with a pre-configured ModelContainer
    /// - Parameter modelContainer: The SwiftData container managed by BackgroundPersistenceActor
    public init(modelContainer: ModelContainer, enableMonitoring: Bool = false, enableIntegrityChecks: Bool = true) {
        self.modelContainer = modelContainer
        self.enableMonitoring = enableMonitoring
        self.enableIntegrityChecks = enableIntegrityChecks
        
        // Create a single shared ModelContext on the main thread
        // Note: usage of this context is strictly for the UI/MainActor bound repositories
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false // Ensure we control commits explicitly via UnitOfWork
        self.modelContext = context
    }
}

// MARK: - Adapter Implementations

/// Adapter to bridge existing UnifiedImportService to Core protocol
private final class UnifiedImportServiceAdapter: DataImporter, @unchecked Sendable {
    private let actor: DataImporterActor

    init(modelContainer: ModelContainer) {
        self.actor = DataImporterActor(modelContainer: modelContainer)
    }

    func importAllData() async throws -> Core.ImportResult {
        let results = try await actor.importAllData()

        var importedCounts: [String: Int] = [:]
        var errors: [String] = []

        for result in results {
            let sourceName = result.source
            importedCounts["\(sourceName)Successful"] = result.successful
            importedCounts["\(sourceName)Failed"] = result.failed

            if result.failed > 0 || !result.messages.isEmpty {
                var components: [String] = []
                if result.failed > 0 {
                    components.append("Failed: \(result.failed)")
                }
                if !result.messages.isEmpty {
                    components.append(result.messages.joined(separator: " | "))
                }
                errors.append("\(sourceName): \(components.joined(separator: " — "))")
            }
        }

        let success = errors.isEmpty
        return ImportResult(
            success: success,
            importedCounts: importedCounts,
            errors: errors
        )
    }
}

/// Adapter to bridge existing export functionality to Core protocol
private final class UnifiedExportServiceAdapter: DataExporter, @unchecked Sendable {
    private let actor: DataExporterActor

    init(modelContainer: ModelContainer) {
        self.actor = DataExporterActor(modelContainer: modelContainer)
    }

    func exportAllData() async throws -> Core.ExportResult {
        let (data, filename) = try await actor.exportToFile(format: .json)
        let fileURL = try Self.persistExport(data: data, fileName: filename)
        let exportedCounts = try Self.entityCounts(fromJSONData: data)

        return ExportResult(
            success: true,
            filePath: fileURL.path,
            exportedCounts: exportedCounts,
            errors: []
        )
    }

    private static func persistExport(data: Data, fileName: String) throws -> URL {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let destination = documentsDirectory.appendingPathComponent(fileName)
        try data.write(to: destination, options: [.atomic])
        return destination
    }

    private static func entityCounts(fromJSONData data: Data) throws -> [String: Int] {
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = jsonObject as? [String: Any] else {
            return [:]
        }

        var counts: [String: Int] = [:]
        for (key, value) in dictionary {
            if let array = value as? [Any] {
                counts[key] = array.count
            }
        }
        return counts
    }
}
