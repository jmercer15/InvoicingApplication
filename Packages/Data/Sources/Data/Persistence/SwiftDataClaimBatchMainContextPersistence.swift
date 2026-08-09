import Core
import PersistenceModels
import DataInterfaces
import Foundation
import SwiftData

@MainActor
public final class SwiftDataClaimBatchMainContextPersistence: ClaimBatchPersisting {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchBatch(id: UUID) throws -> BulkClaimBatch? {
        var descriptor = FetchDescriptor<BulkClaimBatch>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    public func fetchLines(forBatch batchId: UUID) throws -> [BulkClaimLine] {
        let descriptor = FetchDescriptor<BulkClaimLine>(
            predicate: #Predicate { $0.batch?.id == batchId }
        )
        return try modelContext.fetch(descriptor)
    }

    public func fetchWizardReferenceData() throws -> ClaimBatchWizardReferenceData {
        var clientDescriptor = FetchDescriptor<Client>(sortBy: [SortDescriptor(\.fullName)])
        clientDescriptor.propertiesToFetch = [\.fullName, \.planManagementType]
        let clients = try modelContext.fetch(clientDescriptor).map(ClientSnapshot.init)

        let readyStatus = "ready"
        let lockedStatus = "locked"
        let predicate = #Predicate<BillableDraft> {
            $0.draftStatus == readyStatus || $0.draftStatus == lockedStatus
        }
        var draftDescriptor = FetchDescriptor<BillableDraft>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.computedAt, order: .reverse)]
        )
        draftDescriptor.propertiesToFetch = [\.draftStatus, \.computedAt, \.clientId]
        let drafts = try modelContext.fetch(draftDescriptor).map(BillableDraftSnapshot.init)

        return ClaimBatchWizardReferenceData(clients: clients, unbilledDrafts: drafts)
    }

    public func draftId(containingClaimableLineId lineId: UUID) throws -> UUID? {
        var descriptor = FetchDescriptor<ClaimableLine>(
            predicate: #Predicate<ClaimableLine> { $0.id == lineId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.draft?.id
    }

    public func insertBatch(_ snapshot: BulkClaimBatchSnapshot, lines snapshots: [BulkClaimLineSnapshot]) throws -> BulkClaimBatch {
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

    public func markSubmitted(batch: BulkClaimBatch) throws {
        batch.submittedAt = Date()
        try modelContext.save()
    }

    public func saveValidationChanges() throws {
        try modelContext.save()
    }

    public func markExported(batch: BulkClaimBatch, fileName: String, checksumSHA256: String, lineCount: Int) throws {
        batch.exportFileName = fileName
        batch.exportedAt = Date()
        batch.checksumSHA256 = checksumSHA256
        batch.rowCount = Int32(lineCount)
        try modelContext.save()
    }
}
