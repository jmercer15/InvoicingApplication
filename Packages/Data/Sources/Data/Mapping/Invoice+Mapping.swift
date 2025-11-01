import Foundation
import Core

extension Invoice {
    /// Convert from InvoiceEntity to domain model
    init(fromEntity entity: InvoiceEntity) {
        self.init(
            id: entity.id,
            invoiceNumber: entity.invoiceNumber,
            totalAmount: entity.totalAmount,
            taxRate: entity.taxRate,
            creditApplied: entity.creditApplied,
            discount: entity.discount,
            date: entity.date,
            dueDate: entity.dueDate,
            invoiceID: entity.invoiceID,
            issueDate: entity.issueDate,
            notes: entity.notes,
            paidDate: entity.paidDate,
            paymentTerms: entity.paymentTerms,
            status: entity.status?.rawValue,
            sentDate: entity.sentDate,
            currencyCode: entity.currencyCode,
            businessName: entity.businessName,
            businessABN: entity.businessABN,
            businessEmail: entity.businessEmail,
            businessAddress: entity.businessAddress,
            businessPhone: entity.businessPhone,
            clientName: entity.clientName,
            clientNDISNumber: entity.clientNDISNumber,
            clientEmail: entity.clientEmail,
            clientPhone: entity.clientPhone,
            clientAddress: entity.clientAddress,
            billingAuthority: entity.billingAuthority?.rawValue,
            billToName: entity.billToName,
            billToEmail: entity.billToEmail,
            billToAddress: entity.billToAddress,
            payeeName: entity.payeeName,
            payeeEmail: entity.payeeEmail,
            payeePhone: entity.payeePhone,
            payeeAddress: entity.payeeAddress,
            bankName: entity.bankName,
            bankAccountName: entity.bankAccountName,
            bankBSB: entity.bankBSB,
            bankAccountNumber: entity.bankAccountNumber,
            clientId: entity.client?.id,
            businessId: entity.business?.id,
            payeeId: entity.payee?.id,
            sessionIds: entity.sessions?.map { $0.id } ?? []
        )
    }
}

extension InvoiceItem {
    /// Convert from InvoiceItemEntity to domain model
    init(from entity: InvoiceItemEntity) {
        self.init(
            id: entity.id,
            invoiceId: entity.invoice?.id ?? UUID(),
            sessionId: entity.session?.id,
            clientServiceId: entity.clientService?.id,
            itemDescription: entity.itemDescription,
            quantity: entity.quantity,
            rate: entity.rate,
            position: entity.position
        )
    }
}

extension InvoiceEntity {
    /// Update entity from domain model
    func update(from invoice: Invoice) {
        self.invoiceNumber = invoice.invoiceNumber
        self.totalAmount = invoice.totalAmount
        self.taxRate = invoice.taxRate
        self.creditApplied = invoice.creditApplied
        self.discount = invoice.discount
        self.date = invoice.date
        self.dueDate = invoice.dueDate
        self.invoiceID = invoice.invoiceID
        self.issueDate = invoice.issueDate
        self.notes = invoice.notes
        self.paidDate = invoice.paidDate
        self.paymentTerms = invoice.paymentTerms
        self.status = invoice.status.flatMap { InvoiceStatus(rawValue: $0) }
        self.sentDate = invoice.sentDate
        self.currencyCode = invoice.currencyCode
        self.businessName = invoice.businessName
        self.businessABN = invoice.businessABN
        self.businessEmail = invoice.businessEmail
        self.businessAddress = invoice.businessAddress
        self.businessPhone = invoice.businessPhone
        self.clientName = invoice.clientName
        self.clientNDISNumber = invoice.clientNDISNumber
        self.clientEmail = invoice.clientEmail
        self.clientPhone = invoice.clientPhone
        self.clientAddress = invoice.clientAddress
        self.billingAuthority = invoice.billingAuthority.flatMap { BillingAuthority(rawValue: $0) }
        self.billToName = invoice.billToName
        self.billToEmail = invoice.billToEmail
        self.billToAddress = invoice.billToAddress
        self.payeeName = invoice.payeeName
        self.payeeEmail = invoice.payeeEmail
        self.payeePhone = invoice.payeePhone
        self.payeeAddress = invoice.payeeAddress
        self.bankName = invoice.bankName
        self.bankAccountName = invoice.bankAccountName
        self.bankBSB = invoice.bankBSB
        self.bankAccountNumber = invoice.bankAccountNumber
    }
}
