//
//  BulkClaimLineSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation

// MARK: - BulkClaimLineSnapshot

public struct BulkClaimLineSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let registrationNumber: String
    public let ndisNumber: String
    public let supportsDeliveredFrom: Date
    public let supportsDeliveredTo: Date
    public let supportNumber: String
    public let claimReference: String?
    public let quantity: Decimal?
    public let hours: String?
    public let unitPrice: Decimal
    public let gstCode: String
    public let authorisedBy: String?
    public let participantApproved: String?
    public let inKindFundingProgram: String?
    public let claimTypeCode: String?
    public let cancellationReason: String?
    public let abnOfSupportProvider: String?
    public let draftLineId: UUID?
    public let isValid: Bool
    public let validationErrorSummary: String?
    public let submissionStatus: String?
    public let submissionRef: String?
    public let reconciliationNotes: String?
    public let reconciledAt: Date?
    public let ndiaPaidAmount: Decimal?
    public let ndiaErrorCode: String?
    public let ndiaErrorMessage: String?
    public let batchId: UUID?
    public let invoiceId: UUID?
    public let invoiceItemId: UUID?

    public init(
        id: UUID,
        registrationNumber: String,
        ndisNumber: String,
        supportsDeliveredFrom: Date,
        supportsDeliveredTo: Date,
        supportNumber: String,
        claimReference: String? = nil,
        quantity: Decimal? = nil,
        hours: String? = nil,
        unitPrice: Decimal,
        gstCode: String,
        authorisedBy: String? = nil,
        participantApproved: String? = nil,
        inKindFundingProgram: String? = nil,
        claimTypeCode: String? = nil,
        cancellationReason: String? = nil,
        abnOfSupportProvider: String? = nil,
        draftLineId: UUID? = nil,
        isValid: Bool = true,
        validationErrorSummary: String? = nil,
        submissionStatus: String? = nil,
        submissionRef: String? = nil,
        reconciliationNotes: String? = nil,
        reconciledAt: Date? = nil,
        ndiaPaidAmount: Decimal? = nil,
        ndiaErrorCode: String? = nil,
        ndiaErrorMessage: String? = nil,
        batchId: UUID? = nil,
        invoiceId: UUID? = nil,
        invoiceItemId: UUID? = nil
    ) {
        self.id = id
        self.registrationNumber = registrationNumber
        self.ndisNumber = ndisNumber
        self.supportsDeliveredFrom = supportsDeliveredFrom
        self.supportsDeliveredTo = supportsDeliveredTo
        self.supportNumber = supportNumber
        self.claimReference = claimReference
        self.quantity = quantity
        self.hours = hours
        self.unitPrice = unitPrice
        self.gstCode = gstCode
        self.authorisedBy = authorisedBy
        self.participantApproved = participantApproved
        self.inKindFundingProgram = inKindFundingProgram
        self.claimTypeCode = claimTypeCode
        self.cancellationReason = cancellationReason
        self.abnOfSupportProvider = abnOfSupportProvider
        self.draftLineId = draftLineId
        self.isValid = isValid
        self.validationErrorSummary = validationErrorSummary
        self.submissionStatus = submissionStatus
        self.submissionRef = submissionRef
        self.reconciliationNotes = reconciliationNotes
        self.reconciledAt = reconciledAt
        self.ndiaPaidAmount = ndiaPaidAmount
        self.ndiaErrorCode = ndiaErrorCode
        self.ndiaErrorMessage = ndiaErrorMessage
        self.batchId = batchId
        self.invoiceId = invoiceId
        self.invoiceItemId = invoiceItemId
    }

}

