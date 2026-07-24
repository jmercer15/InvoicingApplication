import Core
import Data
import Foundation
import SwiftData

@MainActor
protocol ClaimBatchMainContextPersisting {
    func draftId(containingClaimableLineId lineId: UUID) throws -> UUID?
    func insertBatch(_ snapshot: BulkClaimBatchSnapshot, lines: [BulkClaimLineSnapshot]) throws -> BulkClaimBatch
    func markSubmitted(batch: BulkClaimBatch) throws
    func saveValidationChanges() throws
    func markExported(batch: BulkClaimBatch, fileName: String, checksumSHA256: String, lineCount: Int) throws
}

@MainActor
struct SwiftDataClaimBatchMainContextPersistence: ClaimBatchMainContextPersisting {
    let modelContext: ModelContext

    func draftId(containingClaimableLineId lineId: UUID) throws -> UUID? {
        var descriptor = FetchDescriptor<ClaimableLine>(
            predicate: #Predicate<ClaimableLine> { $0.id == lineId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.draft?.id
    }

    func insertBatch(_ snapshot: BulkClaimBatchSnapshot, lines snapshots: [BulkClaimLineSnapshot]) throws -> BulkClaimBatch {
        let batch = BulkClaimBatch(id: snapshot.id)
        batch.createdAt = snapshot.createdAt
        batch.fromDate = snapshot.fromDate
        batch.toDate = snapshot.toDate
        batch.status = snapshot.status
        batch.includeTravel = snapshot.includeTravel
        batch.includeCancellations = snapshot.includeCancellations
        batch.claimReferenceStrategy = snapshot.claimReferenceStrategy
        batch.exportFileName = snapshot.exportFileName
        batch.exportedAt = snapshot.exportedAt
        batch.submittedAt = snapshot.submittedAt
        batch.rowCount = snapshot.rowCount
        batch.errorCount = snapshot.errorCount
        batch.checksumSHA256 = snapshot.checksumSHA256
        batch.notes = snapshot.notes

        modelContext.insert(batch)

        for snapshot in snapshots {
            let line = BulkClaimLine(id: snapshot.id)
            line.registrationNumber = snapshot.registrationNumber
            line.ndisNumber = snapshot.ndisNumber
            line.supportsDeliveredFrom = snapshot.supportsDeliveredFrom
            line.supportsDeliveredTo = snapshot.supportsDeliveredTo
            line.supportNumber = snapshot.supportNumber
            line.claimReference = snapshot.claimReference
            line.quantity = snapshot.quantity
            line.hours = snapshot.hours
            line.unitPrice = snapshot.unitPrice
            line.gstCode = snapshot.gstCode
            line.authorisedBy = snapshot.authorisedBy
            line.participantApproved = snapshot.participantApproved
            line.inKindFundingProgram = snapshot.inKindFundingProgram
            line.claimTypeCode = snapshot.claimTypeCode
            line.cancellationReason = snapshot.cancellationReason
            line.abnOfSupportProvider = snapshot.abnOfSupportProvider
            line.draftLineId = snapshot.draftLineId
            line.isValid = snapshot.isValid
            line.validationErrorSummary = snapshot.validationErrorSummary
            line.submissionStatus = snapshot.submissionStatus
            line.submissionRef = snapshot.submissionRef
            line.reconciliationNotes = snapshot.reconciliationNotes
            line.reconciledAt = snapshot.reconciledAt
            line.ndiaPaidAmount = snapshot.ndiaPaidAmount
            line.ndiaErrorCode = snapshot.ndiaErrorCode
            line.ndiaErrorMessage = snapshot.ndiaErrorMessage
            line.batch = batch
            modelContext.insert(line)
        }

        try modelContext.save()
        return batch
    }

    func markSubmitted(batch: BulkClaimBatch) throws {
        batch.submittedAt = Date()
        try modelContext.save()
    }

    func saveValidationChanges() throws {
        try modelContext.save()
    }

    func markExported(batch: BulkClaimBatch, fileName: String, checksumSHA256: String, lineCount: Int) throws {
        batch.exportFileName = fileName
        batch.exportedAt = Date()
        batch.checksumSHA256 = checksumSHA256
        batch.rowCount = Int32(lineCount)
        try modelContext.save()
    }
}
