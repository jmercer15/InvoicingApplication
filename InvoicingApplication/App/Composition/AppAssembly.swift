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
@MainActor
public class AppAssembly: ObservableObject {
    
    // MARK: - Core Dependencies
    
    /// Model container for SwiftData
    public let modelContainer: ModelContainer
    /// Shared model context for all repositories (created on main thread)
    public let modelContext: ModelContext
    
    // MARK: - Data Layer
    
    /// Repository implementations
    public lazy var sessionsRepository: SessionsRepository = SessionsRepositorySwiftData(modelContext: modelContext)
    public lazy var invoicesRepository: InvoicesRepository = InvoicesRepositorySwiftData(modelContext: modelContext)
    public lazy var clientsRepository: ClientsRepository = ClientsRepositorySwiftData(modelContext: modelContext)
    public lazy var clientServicesRepository: ClientServicesRepository = ClientServicesRepositorySwiftData(modelContext: modelContext)
    public lazy var ndisItemsRepository: NDISItemRepository = NDISItemRepositorySwiftData(modelContext: modelContext)
    public lazy var payeesRepository: PayeeRepository = PayeeRepositorySwiftData(modelContext: modelContext)
    public lazy var planManagersRepository: PlanManagerRepository = PlanManagerRepositorySwiftData(modelContext: modelContext)
    public lazy var addressRepository: AddressRepository = AddressRepositorySwiftData(modelContext: modelContext)
    
    /// External services
    public lazy var syncService: SyncService = EventKitSyncServiceAdapter()
    
    // MARK: - Use Cases
    
    /// Session use cases
    public lazy var fetchSessions: FetchSessions = FetchSessions(repository: sessionsRepository)
    public lazy var createOrUpdateSession: CreateOrUpdateSession = CreateOrUpdateSession(
        repository: sessionsRepository,
        syncService: syncService
    )
    public lazy var groupSessions: GroupSessions = GroupSessions(repository: sessionsRepository)
    
    /// Invoice use cases
    public lazy var fetchInvoices: FetchInvoices = FetchInvoices(repository: invoicesRepository)
    public lazy var createInvoiceFromSessions: CreateInvoiceFromSessions = CreateInvoiceFromSessions(
        invoicesRepository: invoicesRepository,
        sessionsRepository: sessionsRepository,
        clientsRepository: clientsRepository
    )
    public lazy var updateInvoiceStatus: UpdateInvoiceStatus = UpdateInvoiceStatus(repository: invoicesRepository)
    
    /// Data import/export use cases
    public lazy var importAllData: ImportAllData = ImportAllData(importer: UnifiedImportServiceAdapter(modelContainer: modelContainer))
    public lazy var exportAllData: ExportAllData = ExportAllData(exporter: UnifiedExportServiceAdapter(modelContainer: modelContainer))
    
    // MARK: - Feature ViewModels
    
    /// Calendar feature
    func makeCalendarViewModel() -> CalendarViewModel {
        let eventKitService = EventKitSyncService.shared
        let calendarDataManager = CalendarDataManager(sessionsRepository: sessionsRepository, eventKitService: eventKitService)
        return CalendarViewModel(
            sessionsRepository: sessionsRepository,
            clientsRepository: clientsRepository,
            clientServicesRepository: clientServicesRepository,
            eventKitService: eventKitService,
            dataManager: calendarDataManager,
            modelContext: modelContext, // Needed for EventKit external changes handling
            addressRepository: addressRepository
        )
    }
    
    /// Calendar Container ViewModel factory
    func makeCalendarContainerViewModel() -> CalendarContainerViewModel {
        let eventKitService = EventKitSyncService.shared
        return CalendarContainerViewModel(
            sessionsRepository: sessionsRepository,
            clientsRepository: clientsRepository,
            clientServicesRepository: clientServicesRepository,
            addressRepository: addressRepository,
            modelContext: modelContext // Needed for EventKit external changes handling
        )
    }
    
    /// Billing Hub feature
    func makeBillingHubViewModel() -> BillingHubViewModel {
        BillingHubViewModel(
            sessionsRepository: sessionsRepository,
            invoicesRepository: invoicesRepository,
            clientsRepository: clientsRepository
        )
    }
    
    /// Clients feature
    func makeClientsViewModel() -> ClientsViewModel {
        ClientsViewModel(
            clientsRepository: clientsRepository
        )
    }
    
    /// Client Detail ViewModel factory
    func makeClientDetailViewModel(client: Client, isCreating: Bool) -> ClientDetailViewModel {
        ClientDetailViewModel(
            client: client,
            clientsRepository: clientsRepository,
            clientServicesRepository: clientServicesRepository,
            invoicesRepository: invoicesRepository,
            ndisItemsRepository: ndisItemsRepository,
            payeesRepository: payeesRepository,
            planManagersRepository: planManagersRepository,
            modelContext: modelContext,
            isCreating: isCreating
        )
    }
    
    /// Invoices feature
    func makeInvoicesViewModel() -> InvoicesContainerViewModel {
        InvoicesContainerViewModel(
            invoicesRepository: invoicesRepository,
            clientServicesRepository: clientServicesRepository,
            clientsRepository: clientsRepository
        )
    }
    
    /// Relationships feature
    func makeRelationshipsViewModel() -> RelationshipsContainerViewModel {
        RelationshipsContainerViewModel(
            clientsRepository: clientsRepository,
            payeesRepository: payeesRepository,
            planManagersRepository: planManagersRepository,
            navigationManager: AppNavigationManager.shared
        )
    }
    
    /// Payee Detail ViewModel factory
    func makePayeeDetailViewModel(payee: Payee, isCreating: Bool) -> PayeeDetailViewModel {
        PayeeDetailViewModel(
            payee: payee,
            payeesRepository: payeesRepository,
            clientsRepository: clientsRepository,
            invoicesRepository: invoicesRepository,
            modelContext: modelContext,
            isCreating: isCreating
        )
    }
    
    /// Plan Manager Detail ViewModel factory
    func makePlanManagerDetailViewModel(planManager: PlanManager, isCreating: Bool) -> PlanManagerDetailViewModel {
        PlanManagerDetailViewModel(
            planManager: planManager,
            planManagersRepository: planManagersRepository,
            clientsRepository: clientsRepository,
            invoicesRepository: invoicesRepository,
            modelContext: modelContext,
            isCreating: isCreating
        )
    }
    
    /// Settings feature
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            syncService: syncService,
            importAllData: importAllData,
            exportAllData: exportAllData
        )
    }
    
    /// Template Editor feature
    func makeTemplateEditorWorkspace() -> TemplateEditorWorkspaceViewModel {
        let templateManager = TemplateManager()
        let editorViewModel = InvoiceTemplateEditorViewModel(templateManager: templateManager)
        return TemplateEditorWorkspaceViewModel(
            templateManager: templateManager,
            editorViewModel: editorViewModel
        )
    }
    
    /// NDIS Billing Integration Service
    public lazy var ndisBillingService: NDISBillingIntegrationService = {
        NDISBillingIntegrationService(modelContext: modelContext)
    }()
    
    /// NDIS Billing Workspace ViewModel factory
    func makeNDISBillingWorkspaceViewModel() -> NDISBillingWorkspaceViewModel {
        NDISBillingWorkspaceViewModel(
            clientsRepository: clientsRepository,
            sessionsRepository: sessionsRepository,
            invoicesRepository: invoicesRepository,
            ndisBillingService: ndisBillingService,
            modelContext: modelContext
        )
    }
    
    /// Template Data Service for preview data
    public lazy var templateDataService: TemplateDataService = TemplateDataService(
        invoicesRepository: invoicesRepository,
        clientsRepository: clientsRepository
    )
    
    // MARK: - Initialization
    
    public init() {
        // Create model container with all entities
        // Inline implementation to avoid module qualification issues
        do {
            let schema = Schema([
                ClientEntity.self,
                BusinessEntity.self,
                AddressEntity.self,
                InvoiceEntity.self,
                InvoiceItemEntity.self,
                ClientServiceEntity.self,
                PayeeEntity.self,
                PlanManagerEntity.self,
                SessionEntity.self,
                TravelChargeEntity.self,
                TravelChargeAuditLog.self,
                TravelChargeReviewItem.self,
                CreditHistoryEntryEntity.self,
                NDISItemEntity.self,
                RegionalPriceEntity.self
            ])
            
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            // Create a single shared ModelContext on the main thread
            self.modelContext = ModelContext(modelContainer)
            print("Created ModelContainer with persistent storage")
        } catch {
            print("Failed to create ModelContainer: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}

// MARK: - Adapter Implementations

/// Adapter to bridge existing UnifiedImportService to Core protocol
private final class UnifiedImportServiceAdapter: DataImporter, @unchecked Sendable {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func importAllData() async throws -> ImportResult {
        let context = ModelContext(modelContainer)
        let results = try await UnifiedImportService.importAllData(context: context)

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
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func exportAllData() async throws -> ExportResult {
        let context = ModelContext(modelContainer)
        let (data, filename) = try SwiftDataExportService.exportToFile(context: context, format: .json)
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
