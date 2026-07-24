//
//  InvoiceSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

// MARK: - InvoiceSnapshot

public struct InvoiceSnapshot: Sendable, Equatable, Hashable {
    public let invoiceNumber: String
    public let id: UUID
    public let totalAmount: Double
    public let taxRate: Double
    public let creditApplied: Double
    public let discount: Double
    public let date: Date
    public let dueDate: Date?
    public let issueDate: Date
    public let notes: String?
    public let paidDate: Date?
    public let paymentTerms: String?
    public let effectiveStatus: InvoiceStatus
    public let sentDate: Date?
    public let currencyCode: String
    public let isNDIAUploaded: Bool
    public let ndiaUploadDate: Date?
    public let isBulkClaimed: Bool
    public let businessName: String?
    public let businessABN: String?
    public let businessEmail: String?
    public let businessAddressSnapshot: AddressSnapshot?
    public let businessPhone: String?
    public let clientName: String?
    public let clientNDISNumber: String?
    public let clientEmail: String?
    public let clientPhone: String?
    public let clientAddressSnapshot: AddressSnapshot?
    public let billingAuthority: BillingAuthority?
    public let billToName: String?
    public let billToEmail: String?
    public let billToAddressSnapshot: AddressSnapshot?
    public let payeeName: String?
    public let payeeEmail: String?
    public let payeePhone: String?
    public let payeeAddressSnapshot: AddressSnapshot?
    public let bankName: String?
    public let bankAccountName: String?
    public let bankBSB: String?
    public let bankAccountNumber: String?
    public let invoiceEditorStateData: Data?
    public let invoiceEditorRevision: Int
    public let itemSnapshots: [InvoiceItemSnapshot]
    public let clientId: UUID?
    public let payeeId: UUID?
    public let businessId: UUID?
    public let sessionIds: [UUID]

    public init(_ invoice: Invoice) {
        self.init(
            invoiceNumber: invoice.invoiceNumber,
            id: invoice.id,
            totalAmount: invoice.totalAmount,
            taxRate: invoice.taxRate,
            creditApplied: invoice.creditApplied,
            discount: invoice.discount,
            date: invoice.date,
            dueDate: invoice.dueDate,
            issueDate: invoice.issueDate,
            notes: invoice.notes,
            paidDate: invoice.paidDate,
            paymentTerms: invoice.paymentTerms,
            effectiveStatus: invoice.effectiveStatus,
            sentDate: invoice.sentDate,
            currencyCode: invoice.currencyCode,
            isNDIAUploaded: invoice.isNDIAUploaded,
            ndiaUploadDate: invoice.ndiaUploadDate,
            isBulkClaimed: invoice.isBulkClaimed,
            businessName: invoice.businessName,
            businessABN: invoice.businessABN,
            businessEmail: invoice.businessEmail,
            businessAddressSnapshot: invoice.businessAddressSnapshot,
            businessPhone: invoice.businessPhone,
            clientName: invoice.clientName,
            clientNDISNumber: invoice.clientNDISNumber,
            clientEmail: invoice.clientEmail,
            clientPhone: invoice.clientPhone,
            clientAddressSnapshot: invoice.clientAddressSnapshot,
            billingAuthority: invoice.billingAuthority,
            billToName: invoice.billToName,
            billToEmail: invoice.billToEmail,
            billToAddressSnapshot: invoice.billToAddressSnapshot,
            payeeName: invoice.payeeName,
            payeeEmail: invoice.payeeEmail,
            payeePhone: invoice.payeePhone,
            payeeAddressSnapshot: invoice.payeeAddressSnapshot,
            bankName: invoice.bankName,
            bankAccountName: invoice.bankAccountName,
            bankBSB: invoice.bankBSB,
            bankAccountNumber: invoice.bankAccountNumber,
            invoiceEditorStateData: invoice.invoiceEditorStateData,
            invoiceEditorRevision: invoice.invoiceEditorRevision,
            itemSnapshots: invoice.itemsArray.map(InvoiceItemSnapshot.init),
            clientId: invoice.client?.id,
            payeeId: invoice.payee?.id,
            businessId: invoice.business?.id,
            sessionIds: invoice.sessions?.map(\.id) ?? []
        )
    }

    public init(
        invoiceNumber: String,
        id: UUID,
        totalAmount: Double,
        taxRate: Double,
        creditApplied: Double,
        discount: Double,
        date: Date,
        dueDate: Date?,
        issueDate: Date,
        notes: String?,
        paidDate: Date?,
        paymentTerms: String?,
        effectiveStatus: InvoiceStatus,
        sentDate: Date?,
        currencyCode: String,
        isNDIAUploaded: Bool,
        ndiaUploadDate: Date?,
        isBulkClaimed: Bool,
        businessName: String?,
        businessABN: String?,
        businessEmail: String?,
        businessAddressSnapshot: AddressSnapshot?,
        businessPhone: String?,
        clientName: String?,
        clientNDISNumber: String?,
        clientEmail: String?,
        clientPhone: String?,
        clientAddressSnapshot: AddressSnapshot?,
        billingAuthority: BillingAuthority?,
        billToName: String?,
        billToEmail: String?,
        billToAddressSnapshot: AddressSnapshot?,
        payeeName: String?,
        payeeEmail: String?,
        payeePhone: String?,
        payeeAddressSnapshot: AddressSnapshot?,
        bankName: String?,
        bankAccountName: String?,
        bankBSB: String?,
        bankAccountNumber: String?,
        invoiceEditorStateData: Data?,
        invoiceEditorRevision: Int,
        itemSnapshots: [InvoiceItemSnapshot],
        clientId: UUID?,
        payeeId: UUID?,
        businessId: UUID?,
        sessionIds: [UUID]
    ) {
        self.invoiceNumber = invoiceNumber
        self.id = id
        self.totalAmount = totalAmount
        self.taxRate = taxRate
        self.creditApplied = creditApplied
        self.discount = discount
        self.date = date
        self.dueDate = dueDate
        self.issueDate = issueDate
        self.notes = notes
        self.paidDate = paidDate
        self.paymentTerms = paymentTerms
        self.effectiveStatus = effectiveStatus
        self.sentDate = sentDate
        self.currencyCode = currencyCode
        self.isNDIAUploaded = isNDIAUploaded
        self.ndiaUploadDate = ndiaUploadDate
        self.isBulkClaimed = isBulkClaimed
        self.businessName = businessName
        self.businessABN = businessABN
        self.businessEmail = businessEmail
        self.businessAddressSnapshot = businessAddressSnapshot
        self.businessPhone = businessPhone
        self.clientName = clientName
        self.clientNDISNumber = clientNDISNumber
        self.clientEmail = clientEmail
        self.clientPhone = clientPhone
        self.clientAddressSnapshot = clientAddressSnapshot
        self.billingAuthority = billingAuthority
        self.billToName = billToName
        self.billToEmail = billToEmail
        self.billToAddressSnapshot = billToAddressSnapshot
        self.payeeName = payeeName
        self.payeeEmail = payeeEmail
        self.payeePhone = payeePhone
        self.payeeAddressSnapshot = payeeAddressSnapshot
        self.bankName = bankName
        self.bankAccountName = bankAccountName
        self.bankBSB = bankBSB
        self.bankAccountNumber = bankAccountNumber
        self.invoiceEditorStateData = invoiceEditorStateData
        self.invoiceEditorRevision = invoiceEditorRevision
        self.itemSnapshots = itemSnapshots
        self.clientId = clientId
        self.payeeId = payeeId
        self.businessId = businessId
        self.sessionIds = sessionIds
    }
}
