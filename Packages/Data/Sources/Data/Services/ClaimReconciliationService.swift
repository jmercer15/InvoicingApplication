import Core
import Foundation
import SwiftData

/// Applies BPRF import results to a batch and optionally updates session billing status for paid/accepted lines.
public struct ClaimReconciliationService: Sendable {
    private let modelContainer: ModelContainer

    public init(
        modelContext: ModelContext
    ) {
        self.modelContainer = modelContext.container
    }

    /// Applies BPRF results to the batch and updates session billing status for paid/accepted lines.
    public func applyBPRFResults(batchId: UUID, results: [BPRFResultLine]) async throws -> (updatedLineCount: Int, unmatchedReferences: [String]) {
        let modelContext = ModelContext(modelContainer)
        let batchID = batchId
        let lineDescriptor = FetchDescriptor<BulkClaimLine>(predicate: #Predicate { $0.batch?.id == batchID })
        let lines = try modelContext.fetch(lineDescriptor)
        let resultByRef = Dictionary(uniqueKeysWithValues: results.map { ($0.claimReference, $0) })
        var refsSeen = Set<String>()
        var updated = 0

        for line in lines {
            let ref = line.claimReference ?? line.id.uuidString
            guard let result = resultByRef[ref] else { continue }
            refsSeen.insert(ref)
            updated += 1
            line.submissionStatus = result.submissionStatus
            line.submissionRef = nil
            line.reconciliationNotes = nil
            line.reconciledAt = Date()
            line.ndiaPaidAmount = result.paidAmount.flatMap { NSDecimalNumber(decimal: $0).doubleValue }
            line.ndiaErrorCode = result.errorCode
            line.ndiaErrorMessage = result.errorMessage
        }

        var unmatched: [String] = lines.compactMap { line in
            let ref = line.claimReference ?? line.id.uuidString
            return (resultByRef[ref] == nil && !ref.isEmpty) ? ref : nil
        }
        for result in results where !refsSeen.contains(result.claimReference) {
            unmatched.append(result.claimReference)
        }

        let acceptedStatuses = ["accepted", "paid", "reconciled"]
        for line in lines {
            guard let status = line.submissionStatus?.lowercased(),
                  acceptedStatuses.contains(status),
                  let draftLineId = line.draftLineId else { continue }
            let lineID = draftLineId
            let draftId = try modelContext.fetch(
                FetchDescriptor<ClaimableLine>(predicate: #Predicate { $0.id == lineID })
            ).first?.draft?.id
            guard let draftId else { continue }
            let draftID = draftId
            guard let draft = try modelContext.fetch(
                FetchDescriptor<BillableDraft>(predicate: #Predicate { $0.id == draftID })
            ).first else { continue }
            let sessionId = draft.sessionId
            let sessionID = sessionId
            if let session = try modelContext.fetch(
                FetchDescriptor<Session>(predicate: #Predicate { $0.id == sessionID })
            ).first {
                session.status = SessionStatus(normalized: BillingStatus.readyToSend.rawValue) ?? session.status
            }
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }
        return (updated, unmatched)
    }

    /// Applies a manual reconciliation status update to all lines in a batch.
    public func applyManualReconciliation(
        batchId: UUID,
        submissionStatus: BulkClaimSubmissionStatus,
        submissionRef: String?,
        notes: String?
    ) async throws -> Int {
        let modelContext = ModelContext(modelContainer)
        let batchID = batchId
        let lineDescriptor = FetchDescriptor<BulkClaimLine>(predicate: #Predicate { $0.batch?.id == batchID })
        let lines = try modelContext.fetch(lineDescriptor)
        let reconciledAt = submissionStatus == .reconciled ? Date() : nil

        for line in lines {
            line.submissionStatus = submissionStatus.rawValue
            line.submissionRef = submissionRef
            line.reconciliationNotes = notes
            line.reconciledAt = reconciledAt
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }
        return lines.count
    }
}
