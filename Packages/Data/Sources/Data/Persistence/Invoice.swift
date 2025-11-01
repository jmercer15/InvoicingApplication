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
    @Attribute(.unique) public var invoiceNumber: String
    public var id: UUID
    public var totalAmount: Double = 0.0
    public var taxRate: Double = 0.0
    public var creditApplied: Double = 0.0
    public var discount: Double = 0.0
    public var date: Date = Date() // Non-optional with default
    public var dueDate: Date? // Optional - can be set later
    public var invoiceID: Int32? = 0
    public var issueDate: Date = Date() // Non-optional with default
    public var notes: String?
    public var paidDate: Date?
    public var paymentTerms: String?
    public var status: String?
    public var sentDate: Date?
    public var currencyCode: String = "AUD"
    public var billingOrder: Int32 = 0
    
    // Business Information (snapshot from BusinessEntity)
    public var businessName: String? = nil
    public var businessABN: String?
    public var businessEmail: String?
    public var businessAddress: String?
    public var businessPhone: String?
    
    // Client Information (snapshot from ClientEntity)
    public var clientName: String?
    public var clientNDISNumber: String?
    public var clientEmail: String?
    public var clientPhone: String?
    public var clientAddress: String?
    
    // Billing Information (snapshot from billing authority)
    public var billingAuthority: String? // "Client", "Parent/Guardian"
    public var billToName: String?
    public var billToEmail: String?
    public var billToAddress: String?
    
    // Payee Information (snapshot from PayeeEntity when billing to Parent/Guardian)
    public var payeeName: String?
    public var payeeEmail: String?
    public var payeePhone: String?
    public var payeeAddress: String?
    
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
        return dueDate < Date() && status != "Paid"
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
            businessAddress = business.address?.fullFormattedAddress
            businessPhone = business.phone
        }
        
        // Snapshot client information
        if let client = client {
            clientName = client.fullName
            clientNDISNumber = client.ndisNumber
            clientEmail = client.email
            clientPhone = client.phone
            clientAddress = client.address?.fullFormattedAddress
        }
        
        // Snapshot billing information based on billing authority
        if let client = client {
            billingAuthority = client.billingAuthority
            
            switch client.billingAuthority {
            case "Parent/Guardian":
                if let payee = client.payee {
                    billToName = payee.fullName
                    billToEmail = payee.email
                    billToAddress = payee.address?.fullFormattedAddress
                    
                    // Also snapshot payee details
                    payeeName = payee.fullName
                    payeeEmail = payee.email
                    payeePhone = payee.phone
                    payeeAddress = payee.address?.fullFormattedAddress
                }
            case "Client":
                billToName = client.fullName
                billToEmail = client.email
                billToAddress = client.address?.fullFormattedAddress
            default:
                break
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

