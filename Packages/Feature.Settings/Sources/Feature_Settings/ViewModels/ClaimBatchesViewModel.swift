import Core
import Data
import Foundation
import SwiftData
import SwiftUI
import Observation

@Observable
@MainActor
public final class ClaimBatchesViewModel {
    public var errorMessage: String?

    private let persistence: any ClaimBatchMainContextPersisting
    private let modelContext: ModelContext
    private let claimBatchBuilder: ClaimBatchBuilderService
    private let preflightValidator: BPRPreflightValidator
    private let csvWriter: BPRCSVWriter
    private let hashVerifier: BulkClaimExportHashVerifier
    private let reconciliationService: ClaimReconciliationService
    private let bprfParser: BPRFParser

    public init(
        modelContext: ModelContext,
        modelContainer: ModelContainer,
        claimBatchBuilder: ClaimBatchBuilderService,
        preflightValidator: BPRPreflightValidator,
        csvWriter: BPRCSVWriter,
        hashVerifier: BulkClaimExportHashVerifier,
        reconciliationService: ClaimReconciliationService,
        bprfParser: BPRFParser
    ) {
        self.modelContext = modelContext
        self.persistence = SwiftDataClaimBatchMainContextPersistence(modelContext: modelContext)
        self.claimBatchBuilder = claimBatchBuilder
        self.preflightValidator = preflightValidator
        self.csvWriter = csvWriter
        self.hashVerifier = hashVerifier
        self.reconciliationService = reconciliationService
        self.bprfParser = bprfParser
    }

    public func fetchLines(forBatch batchId: UUID) async -> [BulkClaimLine] {
        do {
            let descriptor = FetchDescriptor<BulkClaimLine>(
                predicate: #Predicate { $0.batch?.id == batchId }
            )
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch lines for batch: \(error)")
            return []
        }
    }

    /// Fallback when `BulkClaimLine.claimableLines` is not populated; resolves the parent billable draft for a claimable line id.
    public func draftId(containingClaimableLineId lineId: UUID) async throws -> UUID? {
        try persistence.draftId(containingClaimableLineId: lineId)
    }

    public func createBatch(from drafts: [BillableDraft], fromDate: Date, toDate: Date) async throws -> BulkClaimBatch {
        let draftIDs = drafts.map(\.id)
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

    /// Returns (csvData, suggestedFileName, checksumSHA256) for the view to present save panel and then call `markExported`.
    public func prepareExport(lines: [BulkClaimLine]) throws -> (data: Data, fileName: String, checksumSHA256: String) {
        let data = csvWriter.csvData(lines: lines)
        let checksum = hashVerifier.hash(for: data)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "BPR_Export_\(formatter.string(from: Date())).csv"
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
