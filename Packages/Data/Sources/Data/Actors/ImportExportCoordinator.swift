import Foundation
import Core
import SwiftData
import os

/// Settings-facing facade composed of catalog import/export operations, bulk-claim workflows, and data wipe.
///
/// `ImportExportCatalogOperations` and `BulkClaimWorkspaceOperations` isolate responsibilities while this type preserves the stable public API for settings import/export UI.
public actor ImportExportCoordinator {
    private let catalog: ImportExportCatalogOperations
    private let bulkClaims: BulkClaimWorkspaceOperations
    private let dataWipeService: DataWipeService
    private let logger = Logger(subsystem: "com.invoicing.import-export", category: "Coordinator")

    public init(
        dataImporterActor: DataImporterActor,
        dataExporterActor: DataExporterActor,
        dataWipeService: DataWipeService,
        bulkClaimBuilderActor: BulkClaimBuilderActor,
        modelContainer: ModelContainer
    ) {
        self.catalog = ImportExportCatalogOperations(
            dataImporterActor: dataImporterActor,
            dataExporterActor: dataExporterActor
        )
        self.bulkClaims = BulkClaimWorkspaceOperations(
            bulkClaimBuilderActor: bulkClaimBuilderActor,
            modelContainer: modelContainer
        )
        self.dataWipeService = dataWipeService
    }

    public func fetchAvailableEffectiveDates() async throws -> [Date] {
        try await catalog.fetchAvailableEffectiveDates()
    }

    public func importNDISItemsFromCSV(url: URL, fileName: String) async throws -> ImportResult {
        try await catalog.importNDISItemsFromCSV(url: url, fileName: fileName)
    }

    public func importNDISItemsFromExcel(url: URL, fileName: String) async throws -> ImportResult {
        try await catalog.importNDISItemsFromExcel(url: url, fileName: fileName)
    }

    public func importSpecificData(source: ImportSource, data: Data, fileName: String) async throws -> ImportResult {
        try await catalog.importSpecificData(source: source, data: data, fileName: fileName)
    }

    public func importFromFile(url: URL, source: ImportSource) async throws -> ImportResult {
        try await runWithDiagnostics("importFromFile", payload: "\(source.description) | \(url.lastPathComponent)") {
            try await catalog.importSpecificDataFromFile(url: url, source: source)
        }
    }

    public func importAllData(url: URL) async throws -> ImportResult {
        try await importFromFile(url: url, source: .allData)
    }

    public func importAllData() async throws -> [ImportResult] {
        try await catalog.importAllData()
    }

    public func importAllData(fileData: Data, fileName: String) async throws -> ImportResult {
        try await runWithDiagnostics("importAllDataFromData", payload: fileName) {
            try await catalog.importAllData(fileData: fileData, fileName: fileName)
        }
    }

    public func export(source: ImportSource, dateString: String? = nil) async throws -> (data: Data, fileName: String) {
        try await runWithDiagnostics("export", payload: source.description) {
            try await catalog.export(source: source, dateString: dateString)
        }
    }

    public func exportAllData(dateString: String? = nil) async throws -> (data: Data, fileName: String) {
        try await runWithDiagnostics("exportAllData", payload: nil) {
            try await catalog.exportAllData(dateString: dateString)
        }
    }

    public func recalculateCurrentStatus() async throws -> (updated: Int, total: Int) {
        try await catalog.recalculateCurrentStatus()
    }

    public func clearAllNDISItems() async throws -> (deletedItems: Int, deletedPrices: Int) {
        try await catalog.clearAllNDISItems()
    }

    public func wipeAllData() async throws -> (totalDeleted: Int, deletedByEntity: [String: Int]) {
        try await dataWipeService.wipeAllData()
    }

    public func applyClaimReconciliation(
        batchId: UUID,
        submissionStatus: BulkClaimSubmissionStatus,
        submissionRef: String?,
        notes: String?
    ) async throws -> Int {
        try await bulkClaims.applyClaimReconciliation(
            batchId: batchId,
            submissionStatus: submissionStatus,
            submissionRef: submissionRef,
            notes: notes
        )
    }

    public func createClaimBatch(
        fromDate: Date,
        toDate: Date,
        includeTravel: Bool,
        includeCancellations: Bool,
        claimReferenceStrategy: String
    ) async throws -> (batchId: UUID, summary: BulkClaimValidationSummary) {
        try await bulkClaims.createClaimBatch(
            fromDate: fromDate,
            toDate: toDate,
            includeTravel: includeTravel,
            includeCancellations: includeCancellations,
            claimReferenceStrategy: claimReferenceStrategy
        )
    }

    public func validateClaimBatch(batchId: UUID) async throws -> BulkClaimValidationSummary {
        try await bulkClaims.validateClaimBatch(batchId: batchId)
    }

    public func summarizeClaimBatch(batchId: UUID) async throws -> BulkClaimValidationSummary {
        try await bulkClaims.summarizeClaimBatch(batchId: batchId)
    }

    public func prepareClaimBatchCSVExport(batchId: UUID, dateString: String? = nil) async throws
        -> (data: Data, fileName: String, summary: BulkClaimValidationSummary)
    {
        try await bulkClaims.prepareClaimBatchCSVExport(batchId: batchId, dateString: dateString)
    }

    private func runWithDiagnostics<T>(
        _ operation: String,
        payload: String?,
        _ execute: () async throws -> T
    ) async throws -> T {
        let startedAt = Date()
        if let payload {
            logger.info("Starting \(operation, privacy: .public) for \(payload, privacy: .public)")
        } else {
            logger.info("Starting \(operation, privacy: .public)")
        }
        do {
            let result = try await execute()
            let elapsed = Int(Date().timeIntervalSince(startedAt) * 1000)
            logger.info("Completed \(operation, privacy: .public) in \(elapsed, privacy: .public) ms")
            return result
        } catch {
            let elapsed = Int(Date().timeIntervalSince(startedAt) * 1000)
            logger.error("Failed \(operation, privacy: .public) after \(elapsed, privacy: .public) ms: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
