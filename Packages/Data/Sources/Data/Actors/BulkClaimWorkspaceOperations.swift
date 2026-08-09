import Core
import PersistenceModels
import Foundation
import SwiftData

/// NDIS bulk-claim batch creation, validation, CSV export, and reconciliation (uses ephemeral contexts).
actor BulkClaimWorkspaceOperations: ModelActor {
    nonisolated public let modelContainer: ModelContainer
    nonisolated public let modelExecutor: any ModelExecutor
    private let bulkClaimBuilderActor: BulkClaimBuilderActor

    init(bulkClaimBuilderActor: BulkClaimBuilderActor, modelContainer: ModelContainer) {
        self.bulkClaimBuilderActor = bulkClaimBuilderActor
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    func applyClaimReconciliation(
        batchId: UUID,
        submissionStatus: BulkClaimSubmissionStatus,
        submissionRef: String?,
        notes: String?
    ) async throws -> Int {
        let service = ClaimReconciliationService(modelContext: self.modelContext)
        return try await service.applyManualReconciliation(
            batchId: batchId,
            submissionStatus: submissionStatus,
            submissionRef: submissionRef,
            notes: notes
        )
    }

    func createClaimBatch(
        fromDate: Date,
        toDate: Date,
        includeTravel: Bool,
        includeCancellations: Bool,
        claimReferenceStrategy: String
    ) async throws -> (batchId: UUID, summary: BulkClaimValidationSummary) {
        let modelContext = self.modelContext
        let batch = BulkClaimBatch(id: UUID())
        batch.createdAt = Date()
        batch.fromDate = fromDate
        batch.toDate = toDate
        batch.status = BulkClaimBatchStatus.draft.rawValue
        batch.includeTravel = includeTravel
        batch.includeCancellations = includeCancellations
        batch.claimReferenceStrategy = claimReferenceStrategy
        modelContext.insert(batch)
        try modelContext.save()

        let builtLines = try await bulkClaimBuilderActor.buildLines(batchID: batch.id)
        let validation = await BulkClaimValidationService().validateAndSummarize(lines: builtLines)
        try applyValidationLines(validation.lines, to: batch, in: modelContext)
        try modelContext.save()

        return (batchId: batch.id, summary: validation.summary)
    }

    func validateClaimBatch(batchId: UUID) async throws -> BulkClaimValidationSummary {
        let modelContext = self.modelContext
        let batch = try fetchBatch(id: batchId, in: modelContext)
        let existing = try fetchClaimLines(for: batchId, in: modelContext)

        let snapshots = existing.map { $0.snapshot() }
        let validationService = BulkClaimValidationService()
        let validatedSnapshots = await validationService.validate(lines: snapshots)

        var validRows = 0
        let snapshotsByID = Dictionary(uniqueKeysWithValues: validatedSnapshots.map { ($0.id, $0) })
        for line in existing {
            if let snap = snapshotsByID[line.id] {
                line.isValid = snap.isValid
                line.validationErrorSummary = snap.validationErrorSummary
                if snap.isValid { validRows += 1 }
            }
        }

        let summary = BulkClaimValidationSummary(
            totalRows: existing.count,
            validRows: validRows,
            invalidRows: existing.count - validRows
        )

        batch.rowCount = Int32(summary.totalRows)
        batch.errorCount = Int32(summary.invalidRows)
        if modelContext.hasChanges {
            try modelContext.save()
        }
        return summary
    }

    func summarizeClaimBatch(batchId: UUID) async throws -> BulkClaimValidationSummary {
        let modelContext = self.modelContext
        let lines = try fetchClaimLines(for: batchId, in: modelContext)
        let snapshots = lines.map { $0.snapshot() }
        return await BulkClaimValidationService().summarize(lines: snapshots)
    }

    func prepareClaimBatchCSVExport(batchId: UUID, dateString: String? = nil) async throws
        -> (data: Data, fileName: String, summary: BulkClaimValidationSummary)
    {
        let dateString = dateString ?? ImportExportTimestamp.fileSuffix()
        let modelContext = self.modelContext
        let batch = try fetchBatch(id: batchId, in: modelContext)
        let lines = try fetchClaimLines(for: batchId, in: modelContext)
        let snapshots = lines.map { $0.snapshot() }
        let summary = await BulkClaimValidationService().summarize(lines: snapshots)
        if summary.totalRows == 0 {
            throw NSError(
                domain: "BulkClaimExport",
                code: 4002,
                userInfo: [NSLocalizedDescriptionKey: "No rows available to export."]
            )
        }
        if summary.invalidRows > 0 {
            throw NSError(
                domain: "BulkClaimExport",
                code: 4003,
                userInfo: [NSLocalizedDescriptionKey: "Export blocked: \(summary.invalidRows) row(s) have validation errors."]
            )
        }
        let csvWriter = BPRCSVWriter()
        let csvData = csvWriter.csvData(lines: lines)
        let checksum = csvWriter.sha256Hex(for: csvData)
        guard BulkClaimExportHashVerifier(csvWriter: csvWriter).verify(data: csvData, expectedSHA256: checksum) else {
            throw NSError(
                domain: "BulkClaimExport",
                code: 4001,
                userInfo: [NSLocalizedDescriptionKey: "Generated export checksum failed local verification."]
            )
        }
        let fileName = "NDIS-Claims-\(dateString).csv"

        batch.exportFileName = fileName
        batch.checksumSHA256 = checksum
        batch.rowCount = Int32(lines.count)
        batch.exportedAt = Date()
        batch.status = BulkClaimBatchStatus.exported.rawValue
        if modelContext.hasChanges {
            try modelContext.save()
        }
        return (data: csvData, fileName: fileName, summary: summary)
    }

    private func fetchBatch(id: UUID, in modelContext: ModelContext) throws -> BulkClaimBatch {
        let descriptor = FetchDescriptor<BulkClaimBatch>(predicate: #Predicate { $0.id == id })
        guard let batch = try modelContext.fetch(descriptor).first else {
            throw NSError(
                domain: "ImportExportCoordinatorError",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Bulk claim batch not found for id \(id.uuidString)."]
            )
        }
        return batch
    }

    private func applyValidationLines(
        _ snapshots: [BulkClaimLineSnapshot],
        to batch: BulkClaimBatch,
        in modelContext: ModelContext
    ) throws {
        let allLines = try modelContext.fetch(FetchDescriptor<BulkClaimLine>())
        let existing = allLines.filter { $0.batch?.id == batch.id }
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        let invoiceIds = Set(snapshots.compactMap(\.invoiceId))
        let invoicesById: [UUID: Invoice] = Dictionary(
            uniqueKeysWithValues: (try modelContext.fetch(FetchDescriptor<Invoice>()))
                .filter { invoiceIds.contains($0.id) }
                .map { ($0.id, $0) }
        )

        let invoiceItemIds = Set(snapshots.compactMap(\.invoiceItemId))
        let invoiceItemsById: [UUID: InvoiceItem] = Dictionary(
            uniqueKeysWithValues: (try modelContext.fetch(FetchDescriptor<InvoiceItem>()))
                .filter { invoiceItemIds.contains($0.id) }
                .map { ($0.id, $0) }
        )

        var newEntities: [BulkClaimLine] = []
        newEntities.reserveCapacity(snapshots.count)

        for snap in snapshots {
            let entity: BulkClaimLine
            if let existingEntity = existingById[snap.id] {
                entity = existingEntity
            } else {
                let newEntity = BulkClaimLine(id: snap.id)
                modelContext.insert(newEntity)
                entity = newEntity
            }

            entity.registrationNumber = snap.registrationNumber
            entity.ndisNumber = snap.ndisNumber
            entity.supportsDeliveredFrom = snap.supportsDeliveredFrom
            entity.supportsDeliveredTo = snap.supportsDeliveredTo
            entity.supportNumber = snap.supportNumber
            entity.claimReference = snap.claimReference
            entity.quantity = snap.quantity
            entity.hours = snap.hours
            entity.unitPrice = snap.unitPrice
            entity.gstCode = snap.gstCode
            entity.authorisedBy = snap.authorisedBy
            entity.participantApproved = snap.participantApproved
            entity.inKindFundingProgram = snap.inKindFundingProgram
            entity.claimTypeCode = snap.claimTypeCode
            entity.cancellationReason = snap.cancellationReason
            entity.abnOfSupportProvider = snap.abnOfSupportProvider
            entity.draftLineId = snap.draftLineId
            entity.isValid = snap.isValid
            entity.validationErrorSummary = snap.validationErrorSummary
            entity.submissionStatus = snap.submissionStatus
            entity.submissionRef = snap.submissionRef
            entity.reconciliationNotes = snap.reconciliationNotes
            entity.reconciledAt = snap.reconciledAt
            entity.ndiaPaidAmount = snap.ndiaPaidAmount
            entity.ndiaErrorCode = snap.ndiaErrorCode
            entity.ndiaErrorMessage = snap.ndiaErrorMessage
            if let invoiceId = snap.invoiceId {
                entity.invoice = invoicesById[invoiceId]
            } else {
                entity.invoice = nil
            }
            if let invoiceItemId = snap.invoiceItemId {
                entity.invoiceItem = invoiceItemsById[invoiceItemId]
            } else {
                entity.invoiceItem = nil
            }
            entity.batch = batch
            newEntities.append(entity)
        }

        let newIds = Set(newEntities.map(\.id))
        for entity in existing where !newIds.contains(entity.id) {
            modelContext.delete(entity)
        }

        batch.rowCount = Int32(newEntities.count)
        batch.errorCount = Int32(newEntities.filter { $0.isValid == false }.count)
    }

    private func fetchClaimLines(for batchId: UUID, in modelContext: ModelContext) throws -> [BulkClaimLine] {
        let allLines = try modelContext.fetch(FetchDescriptor<BulkClaimLine>())
        return allLines.filter { $0.batch?.id == batchId }
    }
}
