import SwiftUI
import Core
import Data

// MARK: - Geocoding

private enum GeocodingServiceEnvironmentKey: EnvironmentKey {
    static var defaultValue: (any GeocodingServiceProtocol)? { nil }
}

extension EnvironmentValues {
    /// Core address geocoding actor (MapKit). Injected at scene roots alongside `ModelContainer`.
    public var geocodingService: (any GeocodingServiceProtocol)? {
        get { self[GeocodingServiceEnvironmentKey.self] }
        set { self[GeocodingServiceEnvironmentKey.self] = newValue }
    }
}

// MARK: - SwiftData-backed geocoding (persisted coordinates)

private enum SwiftDataGeocodingServiceEnvironmentKey: EnvironmentKey {
    static var defaultValue: (any SwiftDataGeocodingServiceProtocol)? { nil }
}

extension EnvironmentValues {
    /// Geocoding helper that reads/writes coordinates on SwiftData models (NDIS / billing flows).
    ///
    /// **Injection:** The app creates one instance in `AppSession.bootstrap()` and passes it
    /// through `workspaceStandardServicesEnvironment`. Features that are not under that modifier (e.g. isolated
    /// previews) should use `WorkspacePreviewServices.makeSwiftDataGeocodingService()` instead of ad-hoc `init()`.
    /// `NDISBillingIntegrationService` and similar services receive the same instance from the app root.
    public var swiftDataGeocodingService: (any SwiftDataGeocodingServiceProtocol)? {
        get { self[SwiftDataGeocodingServiceEnvironmentKey.self] }
        set { self[SwiftDataGeocodingServiceEnvironmentKey.self] = newValue }
    }
}

// MARK: - Calendar / EventKit

private enum EventKitSyncServiceEnvironmentKey: EnvironmentKey {
    static var defaultValue: EventKitSyncService? { nil }
}

extension EnvironmentValues {
    public var eventKitSyncService: EventKitSyncService? {
        get { self[EventKitSyncServiceEnvironmentKey.self] }
        set { self[EventKitSyncServiceEnvironmentKey.self] = newValue }
    }
}

private enum CalendarPreferencesStoreEnvironmentKey: EnvironmentKey {
    static var defaultValue: CalendarPreferencesStore? { nil }
}

extension EnvironmentValues {
    public var calendarPreferencesStore: CalendarPreferencesStore? {
        get { self[CalendarPreferencesStoreEnvironmentKey.self] }
        set { self[CalendarPreferencesStoreEnvironmentKey.self] = newValue }
    }
}

// MARK: - NDIS / travel automation shared lookups

private enum MMMZoneLookupEnvironmentKey: EnvironmentKey {
    static var defaultValue: (any MMMZoneLookupProtocol)? { nil }
}

extension EnvironmentValues {
    public var mmmZoneLookup: (any MMMZoneLookupProtocol)? {
        get { self[MMMZoneLookupEnvironmentKey.self] }
        set { self[MMMZoneLookupEnvironmentKey.self] = newValue }
    }
}

private enum RecurrenceRuleManagerEnvironmentKey: EnvironmentKey {
    static var defaultValue: RecurrenceRuleManager? { nil }
}

extension EnvironmentValues {
    public var recurrenceRuleManager: RecurrenceRuleManager? {
        get { self[RecurrenceRuleManagerEnvironmentKey.self] }
        set { self[RecurrenceRuleManagerEnvironmentKey.self] = newValue }
    }
}

// MARK: - NDIS billing (app-injected integration)

private enum NDISBillingIntegrationServiceEnvironmentKey: EnvironmentKey {
    static var defaultValue: (any NDISBillingIntegrationServiceProtocol)? { nil }
}

extension EnvironmentValues {
    public var ndisBillingIntegrationService: (any NDISBillingIntegrationServiceProtocol)? {
        get { self[NDISBillingIntegrationServiceEnvironmentKey.self] }
        set { self[NDISBillingIntegrationServiceEnvironmentKey.self] = newValue }
    }
}
