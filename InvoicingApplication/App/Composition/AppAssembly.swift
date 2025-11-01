import Foundation
import SwiftData
import Core
import Data
import Feature_Calendar
import Feature_BillingHub
import Feature_Clients
import Feature_Invoices
import Feature_InvoiceTemplateEditor
import Feature_Settings

/// Main dependency injection container for the application
@MainActor
public class AppAssembly: ObservableObject {
    
    // MARK: - Core Dependencies
    
    /// Model container for SwiftData
    public let modelContainer: ModelContainer
    public var modelContext: ModelContext { ModelContext(modelContainer) }
    
    // MARK: - Data Layer
    
    /// Repository implementations
    public lazy var sessionsRepository: SessionsRepository = SessionsRepositorySwiftData(modelContext: modelContext)
    public lazy var invoicesRepository: InvoicesRepository = InvoicesRepositorySwiftData(modelContext: modelContext)
    public lazy var clientsRepository: ClientsRepository = ClientsRepositorySwiftData(modelContext: modelContext)
    
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
        let calendarDataManager = CalendarDataManager(context: modelContext, eventKitService: eventKitService)
        return CalendarViewModel(
            context: modelContext,
            eventKitService: eventKitService,
            dataManager: calendarDataManager
        )
    }
    
    /// Billing Hub feature
    func makeBillingHubViewModel() -> BillingHubViewModel {
        BillingHubViewModel(modelContext: modelContext)
    }
    
    /// Clients feature
    func makeClientsViewModel() -> ClientsViewModel {
        ClientsViewModel(
            clientsRepository: clientsRepository
        )
    }
    
    /// Invoices feature
    func makeInvoicesViewModel() -> InvoicesContainerViewModel {
        InvoicesContainerViewModel(context: modelContext)
    }
    
    /// Settings feature
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            syncService: syncService,
            importAllData: importAllData,
            exportAllData: exportAllData
        )
    }
    
    // MARK: - Initialization
    
    public init() {
        // Create model container with all entities
        self.modelContainer = ModelContainerHelper.createModelContainerSafely() ?? {
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
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()
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
