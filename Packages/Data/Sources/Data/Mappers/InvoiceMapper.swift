import Foundation
import Core

/// Maps between `Invoice` domain model and `InvoiceEntity` persistence model.
public struct InvoiceMapper: ModelMapper {
    public typealias DomainModel = Invoice
    public typealias PersistenceEntity = InvoiceEntity
    
    private let addressMapper = AddressMapper()
    
    public init() {}
    
    public func mapToDomain(_ entity: InvoiceEntity) -> Invoice {
        Invoice(
            id: entity.id,
            invoiceNumber: entity.invoiceNumber,
            totalAmount: entity.totalAmount,
            taxRate: entity.taxRate,
            creditApplied: entity.creditApplied,
            discount: entity.discount,
            date: entity.date,
            dueDate: entity.dueDate,
            issueDate: entity.issueDate,
            notes: entity.notes,
            paidDate: entity.paidDate,
            paymentTerms: entity.paymentTerms,
            status: entity.status.rawValue,
            sentDate: entity.sentDate,
            currencyCode: entity.currencyCode,
            businessName: entity.businessName,
            businessABN: entity.businessABN,
            businessEmail: entity.businessEmail,
            businessAddress: entity.businessAddress.map { addressMapper.mapToDomain($0) },
            businessPhone: entity.businessPhone,
            clientName: entity.clientName,
            clientNDISNumber: entity.clientNDISNumber,
            clientEmail: entity.clientEmail,
            clientPhone: entity.clientPhone,
            clientAddress: entity.clientAddress.map { addressMapper.mapToDomain($0) },
            billingAuthority: entity.billingAuthority?.rawValue,
            billToName: entity.billToName,
            billToEmail: entity.billToEmail,
            billToAddress: entity.billToAddress.map { addressMapper.mapToDomain($0) },
            payeeName: entity.payeeName,
            payeeEmail: entity.payeeEmail,
            payeePhone: entity.payeePhone,
            payeeAddress: entity.payeeAddress.map { addressMapper.mapToDomain($0) },
            bankName: entity.bankName,
            bankAccountName: entity.bankAccountName,
            bankBSB: entity.bankBSB,
            bankAccountNumber: entity.bankAccountNumber,
            clientId: entity.client?.id,
            businessId: entity.business?.id,
            payeeId: entity.payee?.id,
            templateId: entity.templateId,
            sessionIds: entity.sessions?.map { $0.id } ?? []
        )
    }
    
    public func mapToEntity(_ domain: Invoice) -> InvoiceEntity {
        let entity = InvoiceEntity(id: domain.id, invoiceNumber: domain.invoiceNumber)
        updateEntityProperties(entity, from: domain)
        return entity
    }
    
    public func updateEntity(_ entity: inout InvoiceEntity, from domain: Invoice) {
        updateEntityProperties(entity, from: domain)
    }
    
    private func updateEntityProperties(_ entity: InvoiceEntity, from domain: Invoice) {
        entity.totalAmount = domain.totalAmount
        entity.taxRate = domain.taxRate
        entity.creditApplied = domain.creditApplied
        entity.discount = domain.discount
        entity.date = domain.date
        entity.dueDate = domain.dueDate
        entity.issueDate = domain.issueDate
        entity.notes = domain.notes
        entity.paidDate = domain.paidDate
        entity.paymentTerms = domain.paymentTerms
        entity.status = InvoiceStatus(normalized: domain.status) ?? .reviewDraft
        entity.sentDate = domain.sentDate
        entity.currencyCode = domain.currencyCode
        entity.templateId = domain.templateId
        
        // Snapshot fields
        entity.businessName = domain.businessName
        entity.businessABN = domain.businessABN
        entity.businessEmail = domain.businessEmail
        entity.businessPhone = domain.businessPhone
        entity.clientName = domain.clientName
        entity.clientNDISNumber = domain.clientNDISNumber
        entity.clientEmail = domain.clientEmail
        entity.clientPhone = domain.clientPhone
        entity.billingAuthority = domain.billingAuthority.flatMap { BillingAuthority(rawValue: $0) }
        entity.billToName = domain.billToName
        entity.billToEmail = domain.billToEmail
        entity.payeeName = domain.payeeName
        entity.payeeEmail = domain.payeeEmail
        entity.payeePhone = domain.payeePhone
        entity.bankName = domain.bankName
        entity.bankAccountName = domain.bankAccountName
        entity.bankBSB = domain.bankBSB
        entity.bankAccountNumber = domain.bankAccountNumber
        
        // Note: Relationship addresses and linked entities handled separately
    }
}
