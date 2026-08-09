import DataInterfaces
import Foundation

/// Persistence and background actors for settings flows. Shared workspace services
/// (`geocodingService`, `eventKitSyncService`, etc.) are supplied via `EnvironmentValues`.
@MainActor
public final class SettingsServices: SettingsServicesProviding {
    public let importExportCoordinator: any ImportExportCoordinating
    public let travelChargeAutomation: any TravelChargeAutomating
    public let calendarSessionWiper: any CalendarSessionWiping
    public let claimBatchWorkflow: ClaimBatchWorkflowServices
    public let importExportClaimPersistence: any ImportExportClaimPersisting
    public let bulkClaimExportHashVerifier: any BulkClaimExportHashVerifying

    public init(
        importExportCoordinator: any ImportExportCoordinating,
        travelChargeAutomation: any TravelChargeAutomating,
        calendarSessionWiper: any CalendarSessionWiping,
        claimBatchWorkflow: ClaimBatchWorkflowServices,
        importExportClaimPersistence: any ImportExportClaimPersisting,
        bulkClaimExportHashVerifier: any BulkClaimExportHashVerifying
    ) {
        self.importExportCoordinator = importExportCoordinator
        self.travelChargeAutomation = travelChargeAutomation
        self.calendarSessionWiper = calendarSessionWiper
        self.claimBatchWorkflow = claimBatchWorkflow
        self.importExportClaimPersistence = importExportClaimPersistence
        self.bulkClaimExportHashVerifier = bulkClaimExportHashVerifier
    }
}
