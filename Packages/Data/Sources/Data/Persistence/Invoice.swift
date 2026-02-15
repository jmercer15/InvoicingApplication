//
//  InvoiceEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class InvoiceEntity {
    #Index<InvoiceEntity>([\.issueDate], [\.dueDate], [\.totalAmount], [\.paidDate], [\.sentDate])
    
    @Attribute(.unique) public var invoiceNumber: String
    public var id: UUID
    public var totalAmount: Double = 0.0
    public var taxRate: Double = 0.0
    public var creditApplied: Double = 0.0
    public var discount: Double = 0.0
    public var date: Date = Date() // Non-optional with default
    public var dueDate: Date? // Optional - can be set later
    public var issueDate: Date = Date() // Non-optional with default
    public var notes: String?
    public var paidDate: Date?
    public var paymentTerms: String?
    public var status: InvoiceStatus = InvoiceStatus.reviewDraft
    public var sentDate: Date?
    public var currencyCode: String = "AUD"
    public var templateId: UUID?
    
    // Business Information (snapshot from BusinessEntity)
    public var businessName: String? = nil
    public var businessABN: String?
    public var businessEmail: String?
    @Relationship(deleteRule: .cascade) public var businessAddress: AddressEntity?
    public var businessPhone: String?
    
    // Client Information (snapshot from ClientEntity)
    public var clientName: String?
    public var clientNDISNumber: String?
    public var clientEmail: String?
    public var clientPhone: String?
    @Relationship(deleteRule: .cascade) public var clientAddress: AddressEntity?
    
    // Billing Information (snapshot from billing authority)
    public var billingAuthority: BillingAuthority? // "Client", "Parent/Guardian"
    public var billToName: String?
    public var billToEmail: String?
    @Relationship(deleteRule: .cascade) public var billToAddress: AddressEntity?
    
    // Payee Information (snapshot from PayeeEntity when billing to Parent/Guardian)
    public var payeeName: String?
    public var payeeEmail: String?
    public var payeePhone: String?
    @Relationship(deleteRule: .cascade) public var payeeAddress: AddressEntity?
    
    // Payment Details (snapshot from BusinessEntity)
    public var bankName: String?
    public var bankAccountName: String?
    public var bankBSB: String?
    public var bankAccountNumber: String?
    

    @Relationship(deleteRule: .cascade, inverse: \InvoiceItemEntity.invoice) public var items: [InvoiceItemEntity] = []
    @Relationship(deleteRule: .nullify) public var payee: PayeeEntity?
    @Relationship(deleteRule: .nullify, inverse: \ClientEntity.invoices) public var client: ClientEntity?
    @Relationship(deleteRule: .nullify, inverse: \SessionEntity.invoice) public var sessions: [SessionEntity]?
    @Relationship(deleteRule: .nullify) public var business: BusinessEntity?
    
    public init(id: UUID, invoiceNumber: String) {
        self.id = id
        self.invoiceNumber = invoiceNumber
    }
    
    // MARK: - Computed Properties
    
    /// Sorted array of invoice items by position
    public var itemsArray: [InvoiceItemEntity] {
        items.sorted { $0.position < $1.position }
    }
    
    /// Calculated subtotal from line items
    public var subtotal: Double {
        itemsArray.reduce(0) { $0 + ($1.rate * $1.quantity) }
    }
    
    /// Calculated discount amount
    public var discountAmount: Double {
        subtotal * (discount / 100.0)
    }
    
    /// Calculated tax amount after discount
    public var taxAmount: Double {
        let subtotalAfterDiscount = subtotal * (1.0 - (discount / 100.0))
        return subtotalAfterDiscount * (taxRate / 100.0)
    }
    
    /// Calculated total amount
    public var calculatedTotal: Double {
        subtotal - discountAmount + taxAmount - creditApplied
    }
    
    /// Formatted invoice number for display
    var formattedInvoiceNumber: String {
        invoiceNumber.isEmpty ? "Draft" : invoiceNumber
    }
    
    /// Formatted total amount for display
    var formattedTotal: String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = currencyCode
        return nf.string(from: NSNumber(value: calculatedTotal)) ?? String(format: "%.2f", calculatedTotal)
    }
    
    /// Check if invoice is valid for saving
    public var isValid: Bool {
        !invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        client != nil &&
        calculatedTotal >= 0
    }
    
    /// Check if invoice is overdue
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date() && !status.isSettled
    }
    
    /// Days until due (negative if overdue)
    var daysUntilDue: Int? {
        guard let dueDate = dueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day
    }
    
    // MARK: - Snapshot Methods
    
    /// Snapshot all related entity data into the invoice's own properties
    public func snapshotRelatedData() {
        // Snapshot business information
        if let business = business {
            businessName = business.name
            businessABN = business.abn
            businessEmail = business.email
            if let sourceAddress = business.address {
                let snapshotAddress = AddressEntity()
                snapshotAddress.streetName = sourceAddress.streetName
                snapshotAddress.city = sourceAddress.city
                snapshotAddress.state = sourceAddress.state
                snapshotAddress.postcode = sourceAddress.postcode
                snapshotAddress.country = sourceAddress.country
                snapshotAddress.invoice = self
                businessAddress = snapshotAddress
            }
            businessPhone = business.phone
        }
        
        // Snapshot client information
        if let client = client {
            clientName = client.fullName
            clientNDISNumber = client.ndisNumber
            clientEmail = client.email
            clientPhone = client.phone
            if let sourceAddress = client.address {
                let snapshotAddress = AddressEntity()
                snapshotAddress.streetName = sourceAddress.streetName
                snapshotAddress.city = sourceAddress.city
                snapshotAddress.state = sourceAddress.state
                snapshotAddress.postcode = sourceAddress.postcode
                snapshotAddress.country = sourceAddress.country
                snapshotAddress.invoice = self
                clientAddress = snapshotAddress
            }
        }
        
        // Snapshot billing information based on billing authority
        if let client = client {
            billingAuthority = client.billingAuthority
            
            switch client.billingAuthority {
            case .parentGuardian:
                if let payee = client.payee {
                    billToName = payee.fullName
                    billToEmail = payee.email
                    if let sourceAddress = payee.address {
                        let snapshotAddress = AddressEntity()
                        snapshotAddress.streetName = sourceAddress.streetName
                        snapshotAddress.city = sourceAddress.city
                        snapshotAddress.state = sourceAddress.state
                        snapshotAddress.postcode = sourceAddress.postcode
                        snapshotAddress.country = sourceAddress.country
                        snapshotAddress.invoice = self
                        billToAddress = snapshotAddress
                    }
                    
                    // Also snapshot payee details
                    payeeName = payee.fullName
                    payeeEmail = payee.email
                    payeePhone = payee.phone
                    
                    if let sourceAddress = payee.address {
                         let snapshotAddress = AddressEntity()
                         snapshotAddress.streetName = sourceAddress.streetName
                         snapshotAddress.city = sourceAddress.city
                         snapshotAddress.state = sourceAddress.state
                         snapshotAddress.postcode = sourceAddress.postcode
                         snapshotAddress.country = sourceAddress.country
                         snapshotAddress.invoice = self
                         payeeAddress = snapshotAddress
                    }
                }
            case .client:
                billToName = client.fullName
                billToEmail = client.email
                if let sourceAddress = client.address {
                    let snapshotAddress = AddressEntity()
                    snapshotAddress.streetName = sourceAddress.streetName
                    snapshotAddress.city = sourceAddress.city
                    snapshotAddress.state = sourceAddress.state
                    snapshotAddress.postcode = sourceAddress.postcode
                    snapshotAddress.country = sourceAddress.country
                    snapshotAddress.invoice = self
                    billToAddress = snapshotAddress
                }
            default:
                break
            }
        }
        
        // Also snapshot payee data directly from payee relationship if it exists
        // This handles cases where payee is set directly on the invoice
        if let directPayee = payee {
            if payeeName == nil { payeeName = directPayee.fullName }
            if payeeEmail == nil { payeeEmail = directPayee.email }
            if payeePhone == nil { payeePhone = directPayee.phone }
            if payeeAddress == nil { 
                if let sourceAddress = directPayee.address {
                    let snapshotAddress = AddressEntity()
                    snapshotAddress.streetName = sourceAddress.streetName
                    snapshotAddress.city = sourceAddress.city
                    snapshotAddress.state = sourceAddress.state
                    snapshotAddress.postcode = sourceAddress.postcode
                    snapshotAddress.country = sourceAddress.country
                    snapshotAddress.invoice = self
                    payeeAddress = snapshotAddress
                }
            }
            
            // If billing authority suggests parent/guardian but billTo fields aren't set, populate them
            if (billingAuthority == .parentGuardian || billingAuthority == nil) && billToName == nil {
                billToName = directPayee.fullName
                billToEmail = directPayee.email
                
                if let sourceAddress = directPayee.address {
                    let snapshotAddress = AddressEntity()
                    snapshotAddress.streetName = sourceAddress.streetName
                    snapshotAddress.city = sourceAddress.city
                    snapshotAddress.state = sourceAddress.state
                    snapshotAddress.postcode = sourceAddress.postcode
                    snapshotAddress.country = sourceAddress.country
                    snapshotAddress.invoice = self
                    billToAddress = snapshotAddress
                }
            }
        }
        
        // Snapshot payment details
        if let business = business {
            bankName = business.bankName
            bankAccountName = business.bankAccountName
            bankBSB = business.bankBSB
            bankAccountNumber = business.bankAccountNumber
        }
    }
}
