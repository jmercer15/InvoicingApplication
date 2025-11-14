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
            status: entity.status?.rawValue ?? nil,
            sentDate: entity.sentDate,
            currencyCode: entity.currencyCode,
            businessName: entity.businessName ?? entity.business?.name,
            businessABN: entity.businessABN ?? entity.business?.abn,
            businessEmail: entity.businessEmail ?? entity.business?.email,
            businessAddress: entity.businessAddress ?? entity.business?.address?.fullFormattedAddress,
            businessPhone: entity.businessPhone ?? entity.business?.phone,
            clientName: entity.clientName ?? entity.client?.fullName,
            clientNDISNumber: entity.clientNDISNumber ?? entity.client?.ndisNumber,
            clientEmail: entity.clientEmail ?? entity.client?.email,
            clientPhone: entity.clientPhone ?? entity.client?.phone,
            clientAddress: entity.clientAddress ?? entity.client?.address?.fullFormattedAddress,
            billingAuthority: entity.billingAuthority?.rawValue ?? entity.client?.billingAuthority?.rawValue,
            billToName: entity.billToName,
            billToEmail: entity.billToEmail,
            billToAddress: entity.billToAddress,
            payeeName: entity.payeeName ?? entity.payee?.fullName,
            payeeEmail: entity.payeeEmail ?? entity.payee?.email,
            payeePhone: entity.payeePhone ?? entity.payee?.phone,
            payeeAddress: entity.payeeAddress ?? entity.payee?.address?.fullFormattedAddress,
            bankName: entity.bankName,
            bankAccountName: entity.bankAccountName,
            bankBSB: entity.bankBSB,
            bankAccountNumber: entity.bankAccountNumber,
            clientId: entity.client?.id,
            businessId: entity.business?.id,
            payeeId: entity.payee?.id,
            sessionIds: {
                // Safely access sessions relationship to avoid lazy-loading EXC_BAD_ACCESS
                // NOTE: This mapping is called from repositories that wrap operations in MainActor.run
                // However, when entities come from @Query results, lazy-loaded relationships
                // may not be accessible and will return nil, resulting in empty sessionIds.
                // If sessions are required, fetch them separately using SessionsRepository.
                
                // Access sessions relationship - may be nil if entity is from @Query and not materialized
                guard let sessions = entity.sessions else { return [] }
                
                // Force materialization by iterating to create concrete array
                // This avoids lazy evaluation issues that could cause EXC_BAD_ACCESS
                var ids: [UUID] = []
                for session in sessions {
                    ids.append(session.id)
                }
                return ids
            }()
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

// MARK: - Public Helper Functions for Cross-Module Conversion

/// Public helper to convert InvoiceEntity to Invoice domain model
/// Use this from Feature packages to avoid Codable init(from:) conflicts
public func invoiceFromEntity(_ entity: InvoiceEntity) -> Invoice {
    return Invoice(fromEntity: entity)
}
