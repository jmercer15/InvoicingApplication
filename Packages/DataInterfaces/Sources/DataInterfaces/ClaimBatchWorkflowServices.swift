import SwiftUI
import Foundation

/// Claim-batch workflow services for Settings UI (protocol-only surface).
@MainActor
public struct ClaimBatchWorkflowServices: Sendable {
    public let building: any ClaimBatchBuilding
    public let preflight: any ClaimBatchPreflightValidating
    public let csvExport: any ClaimBatchCSVExporting
    public let hashVerifier: any BulkClaimExportHashVerifying
    public let reconciliation: any ClaimReconciling
    public let bprfParser: any BPRFParsing

    public init(
        building: any ClaimBatchBuilding,
        preflight: any ClaimBatchPreflightValidating,
        csvExport: any ClaimBatchCSVExporting,
        hashVerifier: any BulkClaimExportHashVerifying,
        reconciliation: any ClaimReconciling,
        bprfParser: any BPRFParsing
    ) {
        self.building = building
        self.preflight = preflight
        self.csvExport = csvExport
        self.hashVerifier = hashVerifier
        self.reconciliation = reconciliation
        self.bprfParser = bprfParser
    }
}

private struct ClaimBatchWorkflowServicesKey: EnvironmentKey {
    static let defaultValue: ClaimBatchWorkflowServices? = nil
}

public extension EnvironmentValues {
    var claimBatchWorkflowServices: ClaimBatchWorkflowServices? {
        get { self[ClaimBatchWorkflowServicesKey.self] }
        set { self[ClaimBatchWorkflowServicesKey.self] = newValue }
    }
}
