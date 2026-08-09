import Core
import PersistenceModels
import Foundation

/// Preflight validation for BPR export: reuses BulkClaimValidationService and adds duplicate claim reference check.
@MainActor
public final class BPRPreflightValidator: Sendable {
    private let validationService: BulkClaimValidationService

    public init(validationService: BulkClaimValidationService = BulkClaimValidationService()) {
        self.validationService = validationService
    }

    /// Validates lines for BPR export; marks duplicates and invalid rows.
    public func validate(lines: [BulkClaimLineSnapshot]) async -> BulkClaimValidationResult {
        var validated = await validationService.validate(lines: lines)
        let refCounts = Dictionary(grouping: validated, by: { $0.claimReference ?? $0.id.uuidString })
            .mapValues(\.count)
            
        validated = validated.map { line in
            let ref = line.claimReference ?? line.id.uuidString
            let count = refCounts[ref] ?? 0
            
            if count > 1 {
                let existingErrors = line.validationErrorSummary ?? ""
                let newErrors = [existingErrors, "Duplicate claim reference"]
                    .compactMap { $0.isEmpty ? nil : $0 }
                    .joined(separator: "; ")
                
                return BulkClaimLineSnapshot(
                    id: line.id,
                    registrationNumber: line.registrationNumber,
                    ndisNumber: line.ndisNumber,
                    supportsDeliveredFrom: line.supportsDeliveredFrom,
                    supportsDeliveredTo: line.supportsDeliveredTo,
                    supportNumber: line.supportNumber,
                    claimReference: line.claimReference,
                    quantity: line.quantity,
                    hours: line.hours,
                    unitPrice: line.unitPrice,
                    gstCode: line.gstCode,
                    authorisedBy: line.authorisedBy,
                    participantApproved: line.participantApproved,
                    inKindFundingProgram: line.inKindFundingProgram,
                    claimTypeCode: line.claimTypeCode,
                    cancellationReason: line.cancellationReason,
                    abnOfSupportProvider: line.abnOfSupportProvider,
                    draftLineId: line.draftLineId,
                    isValid: false,
                    validationErrorSummary: newErrors,
                    submissionStatus: line.submissionStatus,
                    submissionRef: line.submissionRef,
                    reconciliationNotes: line.reconciliationNotes,
                    reconciledAt: line.reconciledAt,
                    ndiaPaidAmount: line.ndiaPaidAmount,
                    ndiaErrorCode: line.ndiaErrorCode,
                    ndiaErrorMessage: line.ndiaErrorMessage,
                    batchId: line.batchId,
                    invoiceId: line.invoiceId,
                    invoiceItemId: line.invoiceItemId
                )
            }
            return line
        }
        let summary = await validationService.summarize(lines: validated)
        return BulkClaimValidationResult(lines: validated, summary: summary)
    }

    /// Entity-first overload for SwiftData-backed callers.
    public func validate(lines: [BulkClaimLine]) async -> BulkClaimValidationResult {
        let snapshots = lines.map { $0.snapshot() }
        let result = await validate(lines: snapshots)

        // Write the results back to the entities in place
        let resultsByLineID = Dictionary(uniqueKeysWithValues: result.lines.map { ($0.id, $0) })
        for line in lines {
            if let resultLine = resultsByLineID[line.id] {
                line.isValid = resultLine.isValid
                line.validationErrorSummary = resultLine.validationErrorSummary
            }
        }

        return result
    }
}
