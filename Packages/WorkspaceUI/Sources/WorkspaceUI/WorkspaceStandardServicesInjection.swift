import SwiftUI
import Core
import Data

public struct WorkspaceStandardServicesDependencies {
    public let geocodingService: any GeocodingServiceProtocol
    public let swiftDataGeocodingService: any SwiftDataGeocodingServiceProtocol
    public let eventKitSyncService: EventKitSyncService
    public let calendarPreferencesStore: CalendarPreferencesStore
    public let mmmZoneLookup: any MMMZoneLookupProtocol
    public let recurrenceRuleManager: RecurrenceRuleManager
    public let ndisBillingIntegrationService: (any NDISBillingIntegrationServiceProtocol)?

    public init(
        geocodingService: any GeocodingServiceProtocol,
        swiftDataGeocodingService: any SwiftDataGeocodingServiceProtocol,
        eventKitSyncService: EventKitSyncService,
        calendarPreferencesStore: CalendarPreferencesStore,
        mmmZoneLookup: any MMMZoneLookupProtocol,
        recurrenceRuleManager: RecurrenceRuleManager,
        ndisBillingIntegrationService: (any NDISBillingIntegrationServiceProtocol)? = nil
    ) {
        self.geocodingService = geocodingService
        self.swiftDataGeocodingService = swiftDataGeocodingService
        self.eventKitSyncService = eventKitSyncService
        self.calendarPreferencesStore = calendarPreferencesStore
        self.mmmZoneLookup = mmmZoneLookup
        self.recurrenceRuleManager = recurrenceRuleManager
        self.ndisBillingIntegrationService = ndisBillingIntegrationService
    }
}

extension View {
    /// Applies the standard workspace `EnvironmentValues` keys used across app scenes (workspace, settings, inspector, activity).
    @available(*, deprecated, message: "Prefer AppShell's withAppDependencies for bridge-based setup.")
    public func workspaceStandardServicesEnvironment(
        geocodingService: any GeocodingServiceProtocol,
        swiftDataGeocodingService: any SwiftDataGeocodingServiceProtocol,
        eventKitSyncService: EventKitSyncService,
        calendarPreferencesStore: CalendarPreferencesStore,
        mmmZoneLookup: any MMMZoneLookupProtocol,
        recurrenceRuleManager: RecurrenceRuleManager,
        ndisBillingIntegrationService: (any NDISBillingIntegrationServiceProtocol)? = nil
    ) -> some View {
        self.workspaceStandardServicesEnvironment(
            WorkspaceStandardServicesDependencies(
                geocodingService: geocodingService,
                swiftDataGeocodingService: swiftDataGeocodingService,
                eventKitSyncService: eventKitSyncService,
                calendarPreferencesStore: calendarPreferencesStore,
                mmmZoneLookup: mmmZoneLookup,
                recurrenceRuleManager: recurrenceRuleManager,
                ndisBillingIntegrationService: ndisBillingIntegrationService
            )
        )
    }

    public func workspaceStandardServicesEnvironment(
        _ dependencies: WorkspaceStandardServicesDependencies
    ) -> some View {
        self
            .environment(\.geocodingService, dependencies.geocodingService)
            .environment(\.swiftDataGeocodingService, dependencies.swiftDataGeocodingService)
            .environment(\.eventKitSyncService, dependencies.eventKitSyncService)
            .environment(\.calendarPreferencesStore, dependencies.calendarPreferencesStore)
            .environment(\.mmmZoneLookup, dependencies.mmmZoneLookup)
            .environment(\.recurrenceRuleManager, dependencies.recurrenceRuleManager)
            .environment(\.ndisBillingIntegrationService, dependencies.ndisBillingIntegrationService)
    }
}
