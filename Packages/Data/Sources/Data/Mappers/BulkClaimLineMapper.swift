import Foundation
import Core

public struct BulkClaimLineMapper: ModelMapper {
    public typealias DomainModel = BulkClaimLine
    public typealias PersistenceEntity = BulkClaimLineEntity

    public init() {}

    public func mapToDomain(_ entity: BulkClaimLineEntity) -> BulkClaimLine {
        BulkClaimLine(
            id: entity.id,
            batchId: entity.batch?.id ?? UUID(),
            registrationNumber: entity.registrationNumber,
            ndisNumber: entity.ndisNumber,
            supportsDeliveredFrom: entity.supportsDeliveredFrom,
            supportsDeliveredTo: entity.supportsDeliveredTo,
            supportNumber: entity.supportNumber,
            claimReference: entity.claimReference,
            quantity: entity.quantity,
            hours: entity.hours,
            unitPrice: entity.unitPrice,
            gstCode: entity.gstCode,
            authorisedBy: entity.authorisedBy,
            participantApproved: entity.participantApproved,
            inKindFundingProgram: entity.inKindFundingProgram,
            claimTypeCode: entity.claimTypeCode,
            cancellationReason: entity.cancellationReason,
            abnOfSupportProvider: entity.abnOfSupportProvider,
            invoiceId: entity.invoice?.id,
            invoiceItemId: entity.invoiceItem?.id,
            isValid: entity.isValid,
            validationErrorSummary: entity.validationErrorSummary,
            submissionStatus: entity.submissionStatus,
            submissionRef: entity.submissionRef,
            reconciliationNotes: entity.reconciliationNotes,
            reconciledAt: entity.reconciledAt
        )
    }

    public func mapToEntity(_ domain: BulkClaimLine) -> BulkClaimLineEntity {
        let entity = BulkClaimLineEntity(id: domain.id)
        updateEntityProperties(entity, from: domain)
        return entity
    }

    public func updateEntity(_ entity: inout BulkClaimLineEntity, from domain: BulkClaimLine) {
        updateEntityProperties(entity, from: domain)
    }

    private func updateEntityProperties(_ entity: BulkClaimLineEntity, from domain: BulkClaimLine) {
        entity.registrationNumber = domain.registrationNumber
        entity.ndisNumber = domain.ndisNumber
        entity.supportsDeliveredFrom = domain.supportsDeliveredFrom
        entity.supportsDeliveredTo = domain.supportsDeliveredTo
        entity.supportNumber = domain.supportNumber
        entity.claimReference = domain.claimReference
        entity.quantity = domain.quantity
        entity.hours = domain.hours
        entity.unitPrice = domain.unitPrice
        entity.gstCode = domain.gstCode
        entity.authorisedBy = domain.authorisedBy
        entity.participantApproved = domain.participantApproved
        entity.inKindFundingProgram = domain.inKindFundingProgram
        entity.claimTypeCode = domain.claimTypeCode
        entity.cancellationReason = domain.cancellationReason
        entity.abnOfSupportProvider = domain.abnOfSupportProvider
        entity.isValid = domain.isValid
        entity.validationErrorSummary = domain.validationErrorSummary
        entity.submissionStatus = domain.submissionStatus
        entity.submissionRef = domain.submissionRef
        entity.reconciliationNotes = domain.reconciliationNotes
        entity.reconciledAt = domain.reconciledAt
    }
}
