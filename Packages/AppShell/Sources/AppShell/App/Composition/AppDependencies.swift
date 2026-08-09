import SwiftData
import Core
import Data
import DataInterfaces

/// App-wide dependency graph injected from the scene root.
///
/// This is the IceCubes-style “single injection point” for the app: we inject one value and derive
/// per-scene scopes (workspace vs settings) from it.
@Observable
@MainActor
public final class AppDependencies {
    public let runtime: AppRuntime
    public let workspace: WorkspaceDependencies
    public let settings: SettingsDependencies

    public init(runtime: AppRuntime) {
        self.runtime = runtime
        self.workspace = WorkspaceDependencies(runtime: runtime)
        self.settings = SettingsDependencies(runtime: runtime)
    }
}

@Observable
@MainActor
public final class WorkspaceDependencies {
    public let geocodingService: any GeocodingServiceProtocol
    public let swiftDataGeocodingService: any SwiftDataGeocodingServiceProtocol
    public let invoiceDigesting: any InvoiceDigesting
    public let referenceDataFetching: any ReferenceDataFetching
    public let ndisCatalogueFetching: any NDISCatalogueFetching
    public let eventKitSyncService: EventKitSyncService
    public let calendarPreferencesStore: CalendarPreferencesStore
    public let mmmZoneLookup: any MMMZoneLookupProtocol
    public let recurrenceRuleManager: RecurrenceRuleManager
    public let ndisBillingIntegrationService: any NDISBillingIntegrationServiceProtocol

    public let cloudKitSyncMonitor: CloudKitSyncMonitor

    init(runtime: AppRuntime) {
        self.geocodingService = runtime.services.geocodingService
        self.swiftDataGeocodingService = runtime.services.swiftDataGeocodingService
        self.invoiceDigesting = runtime.services.invoiceDigesting
        self.referenceDataFetching = runtime.services.referenceDataFetching
        self.ndisCatalogueFetching = runtime.services.ndisCatalogueFetching
        self.eventKitSyncService = runtime.services.eventKitSyncService
        self.calendarPreferencesStore = runtime.services.calendarPreferencesStore
        self.mmmZoneLookup = runtime.services.mmmZoneLookup
        self.recurrenceRuleManager = runtime.services.recurrenceRuleManager
        self.ndisBillingIntegrationService = runtime.ndisBillingIntegrationService
        self.cloudKitSyncMonitor = runtime.cloudKitSyncMonitor
    }
}

@Observable
@MainActor
public final class SettingsDependencies {
    public let modelContext: ModelContext
    public let settingsServices: SettingsServices

    public let geocodingService: any GeocodingServiceProtocol
    public let eventKitSyncService: EventKitSyncService
    public let calendarPreferencesStore: CalendarPreferencesStore
    public let mmmZoneLookup: any MMMZoneLookupProtocol
    public let recurrenceRuleManager: RecurrenceRuleManager

    public let referenceDataFetching: any ReferenceDataFetching
    public let claimBatchPersisting: any ClaimBatchPersisting
    public let businessPersisting: any BusinessPersisting
    public let travelChargeReviewFetching: any TravelChargeReviewFetching
    public let databaseHealthChecking: any DatabaseHealthChecking

    init(runtime: AppRuntime) {
        self.modelContext = runtime.settingsContext
        self.settingsServices = runtime.settingsServices
        self.geocodingService = runtime.services.geocodingService
        self.eventKitSyncService = runtime.services.eventKitSyncService
        self.calendarPreferencesStore = runtime.services.calendarPreferencesStore
        self.mmmZoneLookup = runtime.services.mmmZoneLookup
        self.recurrenceRuleManager = runtime.services.recurrenceRuleManager
        self.referenceDataFetching = runtime.services.referenceDataFetching
        self.claimBatchPersisting = runtime.settingsPersistence.claimBatchPersisting
        self.businessPersisting = runtime.settingsPersistence.businessPersisting
        self.travelChargeReviewFetching = runtime.settingsPersistence.travelChargeReviewFetching
        self.databaseHealthChecking = runtime.settingsPersistence.databaseHealthChecking
    }
}
