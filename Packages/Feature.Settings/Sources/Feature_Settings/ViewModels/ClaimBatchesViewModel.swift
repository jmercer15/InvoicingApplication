import Core
import DataInterfaces
import Foundation
import PersistenceModels
import SwiftData
import SwiftUI
import Observation

@Observable
@MainActor
public final class ClaimBatchesViewModel {
    public var errorMessage: String?

    private let persistence: any ClaimBatchPersisting
    private let claimBatchBuilder: any ClaimBatchBuilding
    private let preflightValidator: any ClaimBatchPreflightValidating
    private let csvWriter: any ClaimBatchCSVExporting
    private let hashVerifier: any BulkClaimExportHashVerifying
    private let reconciliationService: any ClaimReconciling
    private let bprfParser: any BPRFParsing

    public init(
        persistence: any ClaimBatchPersisting,
        claimBatchBuilder: any ClaimBatchBuilding,
        preflightValidator: any ClaimBatchPreflightValidating,
        csvWriter: any ClaimBatchCSVExporting,
        hashVerifier: any BulkClaimExportHashVerifying,
        reconciliationService: any ClaimReconciling,
        bprfParser: any BPRFParsing
    ) {
        self.persistence = persistence
        self.claimBatchBuilder = claimBatchBuilder
        self.preflightValidator = preflightValidator
        self.csvWriter = csvWriter
        self.hashVerifier = hashVerifier
        self.reconciliationService = reconciliationService
        self.bprfParser = bprfParser
    }

    public func fetchBatch(id: UUID) throws -> BulkClaimBatch? {
        try persistence.fetchBatch(id: id)
    }

    public func fetchLines(forBatch batchId: UUID) async -> [BulkClaimLine] {
        do {
            return try persistence.fetchLines(forBatch: batchId)
        } catch {
            print("Failed to fetch lines for batch: \(error)")
            return []
        }
    }

    public func fetchWizardReferenceData() throws -> ClaimBatchWizardReferenceData {
        try persistence.fetchWizardReferenceData()
    }

    public func draftId(containingClaimableLineId lineId: UUID) async throws -> UUID? {
        try persistence.draftId(containingClaimableLineId: lineId)
    }

    public func createBatch(fromDraftIDs draftIDs: [UUID], fromDate: Date, toDate: Date) async throws -> BulkClaimBatch {
        let (batchSnapshot, linesSnapshot) = try await claimBatchBuilder.buildBatch(
            fromDraftIDs: draftIDs,
            fromDate: fromDate,
            toDate: toDate,
            claimReferenceStrategy: "invoice_number"
        )

        let validated = await preflightValidator.validate(lines: linesSnapshot)

        return try persistence.insertBatch(batchSnapshot, lines: validated.lines)
    }

    public func markSubmitted(batch: BulkClaimBatch) async throws {
        try persistence.markSubmitted(batch: batch)
    }

    public func runPreflight(lines: [BulkClaimLine]) async throws -> BulkClaimValidationResult {
        let result = await preflightValidator.validate(lines: lines)
        try persistence.saveValidationChanges()
        return result
    }

    public func prepareExport(lines: [BulkClaimLine]) throws -> (data: Data, fileName: String, checksumSHA256: String) {
        let data = csvWriter.csvData(lines: lines)
        let checksum = hashVerifier.hash(for: data)
        let fileName = csvWriter.suggestedFileName(at: Date())
        return (data, fileName, checksum)
    }

    public func markExported(batch: BulkClaimBatch, fileName: String, checksumSHA256: String, lineCount: Int) async throws {
        try persistence.markExported(
            batch: batch,
            fileName: fileName,
            checksumSHA256: checksumSHA256,
            lineCount: lineCount
        )
    }

    nonisolated public func parseBPRF(data: Data) throws -> [BPRFResultLine] {
        try bprfParser.parse(data: data)
    }

    public func importBPRF(batchId: UUID, data: Data) async throws -> (updatedLineCount: Int, unmatchedReferences: [String]) {
        let results = try bprfParser.parse(data: data)
        return try await reconciliationService.applyBPRFResults(batchId: batchId, results: results)
    }
}
