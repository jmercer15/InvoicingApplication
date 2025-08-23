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
    @Attribute(.unique) var invoiceNumber: String
    public var id: UUID
    var totalAmount: Double = 0.0
    var taxRate: Double = 0.0
    var creditApplied: Double = 0.0
    var discount: Double = 0.0
    var date: Date = Date() // Non-optional with default
    var dueDate: Date? // Optional - can be set later
    var invoiceID: Int32? = 0
    var issueDate: Date = Date() // Non-optional with default
    var notes: String?
    var paidDate: Date?
    var paymentTerms: String?
    var status: String?
    var sentDate: Date?
    var currencyCode: String = "AUD"
    
    // Business Information (snapshot from BusinessEntity)
    var businessName: String?
    var businessABN: String?
    var businessEmail: String?
    var businessAddress: String?
    var businessPhone: String?
    
    // Client Information (snapshot from ClientEntity)
    var clientName: String?
    var clientNDISNumber: String?
    var clientEmail: String?
    var clientPhone: String?
    var clientAddress: String?
    
    // Billing Information (snapshot from billing authority)
    var billingAuthority: String? // "Client", "Parent/Guardian"
    var billToName: String?
    var billToEmail: String?
    var billToAddress: String?
    
    // Payee Information (snapshot from PayeeEntity when billing to Parent/Guardian)
    var payeeName: String?
    var payeeEmail: String?
    var payeePhone: String?
    var payeeAddress: String?
    
    // Payment Details (snapshot from BusinessEntity)
    var bankName: String?
    var bankAccountName: String?
    var bankBSB: String?
    var bankAccountNumber: String?
    

    @Relationship(deleteRule: .cascade) var items: [InvoiceItemEntity]?
    @Relationship(deleteRule: .nullify) var payee: PayeeEntity?
    @Relationship(deleteRule: .nullify) var client: ClientEntity?
    @Relationship(deleteRule: .nullify) var sessions: [SessionEntity]?
    @Relationship(deleteRule: .nullify) var business: BusinessEntity?
    
    public init(id: UUID, invoiceNumber: String) {
        self.id = id
        self.invoiceNumber = invoiceNumber
    }
    
    // MARK: - Computed Properties
    
    /// Sorted array of invoice items by position
    var itemsArray: [InvoiceItemEntity] {
        (items ?? []).sorted { $0.position < $1.position }
    }
    
    /// Calculated subtotal from line items
    var subtotal: Double {
        itemsArray.reduce(0) { $0 + ($1.rate * $1.quantity) }
    }
    
    /// Calculated discount amount
    var discountAmount: Double {
        subtotal * (discount / 100.0)
    }
    
    /// Calculated tax amount after discount
    var taxAmount: Double {
        let subtotalAfterDiscount = subtotal * (1.0 - (discount / 100.0))
        return subtotalAfterDiscount * (taxRate / 100.0)
    }
    
    /// Calculated total amount
    var calculatedTotal: Double {
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
    var isValid: Bool {
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
    func snapshotRelatedData() {
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


