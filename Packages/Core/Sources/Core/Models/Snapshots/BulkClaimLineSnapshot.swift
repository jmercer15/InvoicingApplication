//
//  BulkClaimLineSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

// MARK: - BulkClaimLineSnapshot

public struct BulkClaimLineSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let registrationNumber: String
    public let ndisNumber: String
    public let supportsDeliveredFrom: Date
    public let supportsDeliveredTo: Date
    public let supportNumber: String
    public let claimReference: String?
    public let quantity: Double?
    public let hours: String?
    public let unitPrice: Double
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
    public let ndiaPaidAmount: Double?
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
        quantity: Double? = nil,
        hours: String? = nil,
        unitPrice: Double,
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
        ndiaPaidAmount: Double? = nil,
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

    public init(_ line: BulkClaimLine) {
        self.id = line.id
        self.registrationNumber = line.registrationNumber
        self.ndisNumber = line.ndisNumber
        self.supportsDeliveredFrom = line.supportsDeliveredFrom
        self.supportsDeliveredTo = line.supportsDeliveredTo
        self.supportNumber = line.supportNumber
        self.claimReference = line.claimReference
        self.quantity = line.quantity
        self.hours = line.hours
        self.unitPrice = line.unitPrice
        self.gstCode = line.gstCode
        self.authorisedBy = line.authorisedBy
        self.participantApproved = line.participantApproved
        self.inKindFundingProgram = line.inKindFundingProgram
        self.claimTypeCode = line.claimTypeCode
        self.cancellationReason = line.cancellationReason
        self.abnOfSupportProvider = line.abnOfSupportProvider
        self.draftLineId = line.draftLineId
        self.isValid = line.isValid
        self.validationErrorSummary = line.validationErrorSummary
        self.submissionStatus = line.submissionStatus
        self.submissionRef = line.submissionRef
        self.reconciliationNotes = line.reconciliationNotes
        self.reconciledAt = line.reconciledAt
        self.ndiaPaidAmount = line.ndiaPaidAmount
        self.ndiaErrorCode = line.ndiaErrorCode
        self.ndiaErrorMessage = line.ndiaErrorMessage
        self.batchId = line.batch?.id
        self.invoiceId = line.invoice?.id
        self.invoiceItemId = line.invoiceItem?.id
    }
}

