import SwiftUI

/// Protocol surface for Settings-scene services wired by AppShell.
@MainActor
public protocol SettingsServicesProviding: AnyObject, Sendable {
    var importExportCoordinator: any ImportExportCoordinating { get }
    var travelChargeAutomation: any TravelChargeAutomating { get }
    var calendarSessionWiper: any CalendarSessionWiping { get }
    var claimBatchWorkflow: ClaimBatchWorkflowServices { get }
    var importExportClaimPersistence: any ImportExportClaimPersisting { get }
    var bulkClaimExportHashVerifier: any BulkClaimExportHashVerifying { get }
}

private struct SettingsServicesEnvironmentKey: EnvironmentKey {
    static let defaultValue: (any SettingsServicesProviding)? = nil
}

public extension EnvironmentValues {
    var settingsServices: (any SettingsServicesProviding)? {
        get { self[SettingsServicesEnvironmentKey.self] }
        set { self[SettingsServicesEnvironmentKey.self] = newValue }
    }
}
