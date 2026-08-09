import SwiftData
import Core
import Data
import DataInterfaces
import Feature_Settings
import os

/// Named bootstrap phases for tests and alternative compositions.
@MainActor
public enum ProductionRuntimeAssembly {
    public struct DatabasePhase: Sendable {
        let database: AppDatabase
    }

    static func makeAppRuntime(startupLog log: OSLog) async throws -> AppRuntime {
        #if DEBUG
        let databaseSignpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "LoadDatabase", signpostID: databaseSignpostID)
        #endif
        // Start the detached database load concurrently
        async let dbPhaseTask = loadDatabase()

        #if DEBUG
        let workspaceServicesSignpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "BuildWorkspaceServices", signpostID: workspaceServicesSignpostID)
        #endif
        // Do main-thread service creation (like EKEventStore) while database loads
        let independentServices = makeIndependentServices()
        #if DEBUG
        os_signpost(.end, log: log, name: "BuildWorkspaceServices", signpostID: workspaceServicesSignpostID)
        #endif

        // Await the background database load
        let dbPhase = try await dbPhaseTask
        #if DEBUG
        os_signpost(.end, log: log, name: "LoadDatabase", signpostID: databaseSignpostID)
        #endif

        try await backfillStatusTokens(modelContainer: dbPhase.database.container)

        let persistence = makePersistenceBundle(phase: dbPhase)
        let storeChangeMonitor = SwiftDataStoreChangeMonitor(modelContainer: dbPhase.database.container)
        let services = assembleWorkspaceServices(
            independent: independentServices,
            database: dbPhase.database,
            storeChangeMonitor: storeChangeMonitor
        )

        #if DEBUG
        let persistenceSignpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "CreatePersistenceBundle", signpostID: persistenceSignpostID)
        os_signpost(.end, log: log, name: "CreatePersistenceBundle", signpostID: persistenceSignpostID)
        #endif

        let database = dbPhase.database

        return AppRuntime(
            database: database,
            services: services,
            persistence: persistence,
            ndisBillingIntegrationService: makeNDISBillingIntegrationService(
                .init(database: database, services: services)
            )
        )
    }

    /// Bootstrap owns its isolation; callers await it instead of launching unowned work.
    nonisolated private static func loadDatabase() async throws -> DatabasePhase {
        let database = try await AppDatabase.bootstrap(policy: .productionSyncRequired)
        return DatabasePhase(database: database)
    }

    public struct IndependentServices {
        let calendarPreferencesStore: CalendarPreferencesStore
        let geocodingService: GeocodingService
        let swiftDataGeocodingService: SwiftDataGeocodingService
        let mmmZoneLookup: MMMZoneLookup
        let recurrence: RecurrenceRuleManager
        let cloudKitSyncMonitor: CloudKitSyncMonitor
        let eventKitSyncService: EventKitSyncService
    }

    public static func makeIndependentServices() -> IndependentServices {
        makeIndependentServices(startsLiveMonitoring: true, startsEventKitObservation: true)
    }

    private static func makeIndependentServices(
        startsLiveMonitoring: Bool,
        startsEventKitObservation: Bool
    ) -> IndependentServices {
        let calendarPreferencesStore = CalendarPreferencesStore()
        let geocodingService = GeocodingService()
        let swiftDataGeocodingService = SwiftDataGeocodingService()
        let mmmZoneLookup = MMMZoneLookup()
        let recurrence = RecurrenceRuleManager()
        let cloudKitSyncMonitor = CloudKitSyncMonitor(
            cloudKitContainerIdentifier: CloudKitConfiguration.containerIdentifier,
            startsLiveMonitoring: startsLiveMonitoring
        )
        let eventKitSyncService = EventKitSyncService(
            preferencesStore: calendarPreferencesStore,
            recurrenceRuleManager: recurrence,
            startsLiveObservation: startsEventKitObservation
        )

        return IndependentServices(
            calendarPreferencesStore: calendarPreferencesStore,
            geocodingService: geocodingService,
            swiftDataGeocodingService: swiftDataGeocodingService,
            mmmZoneLookup: mmmZoneLookup,
            recurrence: recurrence,
            cloudKitSyncMonitor: cloudKitSyncMonitor,
            eventKitSyncService: eventKitSyncService,
        )
    }

    public static func assembleWorkspaceServices(
        independent: IndependentServices,
        database: AppDatabase,
        storeChangeMonitor: SwiftDataStoreChangeMonitor
    ) -> AppRuntime.Services {
        let invoiceDigesting = InvoiceDigestActor(modelContainer: database.container)
        let referenceDataFetching = ReferenceDataWorkflowActor(modelContainer: database.container)
        let ndisCatalogueFetching = NDISVersioningActor(modelContainer: database.container)

        return AppRuntime.Services(
            calendarPreferencesStore: independent.calendarPreferencesStore,
            geocodingService: independent.geocodingService,
            swiftDataGeocodingService: independent.swiftDataGeocodingService,
            mmmZoneLookup: independent.mmmZoneLookup,
            recurrenceRuleManager: independent.recurrence,
            cloudKitSyncMonitor: independent.cloudKitSyncMonitor,
            storeChangeMonitor: storeChangeMonitor,
            eventKitSyncService: independent.eventKitSyncService,
            invoiceDigesting: invoiceDigesting,
            referenceDataFetching: referenceDataFetching,
            ndisCatalogueFetching: ndisCatalogueFetching,
        )
    }

    public static func makePersistenceBundle(phase: DatabasePhase) -> AppRuntime.Persistence {
        let context = phase.database.makeMainContext()
        context.autosaveEnabled = false

        let dataWipeService: DataWipeService = DataWipeServiceImpl(modelContext: context)
        let container = phase.database.container
        let claimBatchBuilder = ClaimBatchBuilderService(modelContext: context)
        let claimBatchWorkflow = ClaimBatchWorkflowServices(
            building: claimBatchBuilder,
            preflight: BPRPreflightValidator(),
            csvExport: BPRCSVWriter(),
            hashVerifier: BulkClaimExportHashVerifier(csvWriter: BPRCSVWriter()),
            reconciliation: ClaimReconciliationService(modelContext: context),
            bprfParser: BPRFParser()
        )
        let settingsServices = SettingsServices(
            importExportCoordinator: ImportExportCoordinator(
                dataImporterActor: DataImporterActor(modelContainer: container),
                dataExporterActor: DataExporterActor(modelContainer: container),
                dataWipeService: dataWipeService,
                bulkClaimBuilderActor: BulkClaimBuilderActor(modelContainer: container),
                modelContainer: container
            ),
            travelChargeAutomation: TravelChargeAutomationActor(modelContainer: container),
            calendarSessionWiper: SessionWipeActor(modelContainer: container),
            claimBatchWorkflow: claimBatchWorkflow,
            importExportClaimPersistence: SwiftDataImportExportClaimPersistence(modelContext: context),
            bulkClaimExportHashVerifier: BulkClaimExportHashVerifier(csvWriter: BPRCSVWriter())
        )
        let settingsPersistence = AppRuntime.SettingsPersistence(
            claimBatchPersisting: SwiftDataClaimBatchMainContextPersistence(modelContext: context),
            businessPersisting: SwiftDataBusinessMainContextPersistence(modelContext: context),
            travelChargeReviewFetching: SwiftDataTravelChargeReviewMainContextPersistence(modelContext: context),
            databaseHealthChecking: SwiftDataDatabaseHealthChecker(modelContext: context),
            clientRelationshipDeleting: SwiftDataClientRelationshipDeleter(modelContext: context)
        )

        return AppRuntime.Persistence(
            settingsContext: context,
            settingsServices: settingsServices,
            settingsPersistence: settingsPersistence
        )
    }

    private static func makeNDISBillingIntegrationService(
        _ dependencies: NDISBillingIntegrationServiceDependencies
    ) -> any Core.NDISBillingIntegrationServiceProtocol {
        NDISBillingIntegrationService(
            modelContainer: dependencies.database.container,
            geocodingService: dependencies.services.swiftDataGeocodingService,
            mmmZoneLookup: dependencies.services.mmmZoneLookup
        )
    }

    public struct NDISBillingIntegrationServiceDependencies {
        let database: AppDatabase
        let services: AppRuntime.Services

        public init(database: AppDatabase, services: AppRuntime.Services) {
            self.database = database
            self.services = services
        }
    }

    nonisolated static func backfillStatusTokens(modelContainer: ModelContainer) async throws {
        let backfillActor = BackfillModelActor(modelContainer: modelContainer)
        try await backfillActor.backfillStatusTokensIfNeeded()
    }
}
