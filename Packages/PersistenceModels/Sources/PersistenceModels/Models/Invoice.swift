//
//  Invoice.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import Core
import SwiftData


@Model public class Invoice {
    #Index<Invoice>([\.issueDate], [\.dueDate], [\.totalAmount], [\.paidDate], [\.sentDate], [\.statusToken])
    
    public var invoiceNumber: String = ""
    public var id: UUID = UUID()
    /// Keep physical keys stable so existing CloudKit-backed invoices retain their amounts.
    public var totalAmount: Decimal = 0
    public var taxRate: Decimal = 0
    public var creditApplied: Decimal = 0
    public var discount: Decimal = 0
    public var date: Date = Date() // Non-optional with default
    public var dueDate: Date? // Optional - can be set later
    public var issueDate: Date = Date() // Non-optional with default
    public var notes: String?
    public var paidDate: Date?
    public var paymentTerms: String?
    /// Optional to avoid SwiftData cast failure when store has nil (e.g. CloudKit sync). Use `effectiveStatus` for a non-optional value.
    @Attribute(originalName: "status") private var statusData: Data? = PersistenceAttributeCoder.encodeEnum(InvoiceStatus.reviewDraft)
    /// Predicate-friendly mirror of `status` (SwiftData cannot predicate over the encoded `statusData`). Backfilled on bootstrap.
    public var statusToken: String = InvoiceStatus.reviewDraft.rawValue

    public var status: InvoiceStatus? {
        get { PersistenceAttributeCoder.decodeEnum(from: statusData) }
        set {
            statusData = PersistenceAttributeCoder.encodeEnum(newValue)
            statusToken = newValue?.rawValue ?? ""
        }
    }

    /// Non-optional status for use in app code; falls back to .reviewDraft when persistence returns nil.
    public var effectiveStatus: InvoiceStatus {
        get { status ?? .reviewDraft }
        set { status = newValue }
    }
    public var sentDate: Date?
    public var currencyCode: String = "AUD"

    /// Versioned document configuration. Shared semantic fields decode through
    /// `InvoiceEditorConfiguration`; feature-owned presentation fields remain opaque here.
    /// Physical property names remain stable because CloudKit-backed stores forbid renames.
    public var invoiceEditorStateData: Data?
    public var invoiceEditorRevision: Int = 0

    public var invoiceEditorConfiguration: InvoiceEditorConfiguration {
        InvoiceEditorConfiguration(data: invoiceEditorStateData)
    }
    
    // Workflow tracking
    public var isNDIAUploaded: Bool = false
    public var ndiaUploadDate: Date?
    public var isBulkClaimed: Bool = false
    
    // Business Information (snapshot from Business)
    public var businessName: String? = nil
    public var businessABN: String?
    public var businessEmail: String?
    @Attribute(originalName: "businessAddressSnapshot") private var businessAddressSnapshotData: Data?

    public var businessAddressSnapshot: AddressSnapshot? {
        get { PersistenceAttributeCoder.decodeAddress(from: businessAddressSnapshotData) }
        set { businessAddressSnapshotData = PersistenceAttributeCoder.encodeAddress(newValue) }
    }
    /// Legacy compatibility only. New reads/writes must use `businessAddressSnapshot`.
    @Relationship(deleteRule: .cascade, inverse: \Address.invoiceBusinessAddress) public var businessAddress: Address?
    public var businessPhone: String?
    
    // Client Information (snapshot from Client)
    public var clientName: String?
    public var clientNDISNumber: String?
    public var clientEmail: String?
    public var clientPhone: String?
    @Attribute(originalName: "clientAddressSnapshot") private var clientAddressSnapshotData: Data?

    public var clientAddressSnapshot: AddressSnapshot? {
        get { PersistenceAttributeCoder.decodeAddress(from: clientAddressSnapshotData) }
        set { clientAddressSnapshotData = PersistenceAttributeCoder.encodeAddress(newValue) }
    }
    /// Legacy compatibility only. New reads/writes must use `clientAddressSnapshot`.
    @Relationship(deleteRule: .cascade, inverse: \Address.invoiceClientAddress) public var clientAddress: Address?
    
    // Billing Information (snapshot from billing authority)
    @Attribute(originalName: "billingAuthority") private var billingAuthorityData: Data?

    public var billingAuthority: BillingAuthority? { // "Client", "Parent/Guardian"
        get { PersistenceAttributeCoder.decodeEnum(from: billingAuthorityData) }
        set { billingAuthorityData = PersistenceAttributeCoder.encodeEnum(newValue) }
    }
    public var billToName: String?
    public var billToEmail: String?
    @Attribute(originalName: "billToAddressSnapshot") private var billToAddressSnapshotData: Data?

    public var billToAddressSnapshot: AddressSnapshot? {
        get { PersistenceAttributeCoder.decodeAddress(from: billToAddressSnapshotData) }
        set { billToAddressSnapshotData = PersistenceAttributeCoder.encodeAddress(newValue) }
    }
    /// Legacy compatibility only. New reads/writes must use `billToAddressSnapshot`.
    @Relationship(deleteRule: .cascade, inverse: \Address.invoiceBillToAddress) public var billToAddress: Address?
    
    // Payee Information (snapshot from Payee when billing to Parent/Guardian)
    public var payeeName: String?
    public var payeeEmail: String?
    public var payeePhone: String?
    @Attribute(originalName: "payeeAddressSnapshot") private var payeeAddressSnapshotData: Data?

    public var payeeAddressSnapshot: AddressSnapshot? {
        get { PersistenceAttributeCoder.decodeAddress(from: payeeAddressSnapshotData) }
        set { payeeAddressSnapshotData = PersistenceAttributeCoder.encodeAddress(newValue) }
    }
    /// Legacy compatibility only. New reads/writes must use `payeeAddressSnapshot`.
    @Relationship(deleteRule: .cascade, inverse: \Address.invoicePayeeAddress) public var payeeAddress: Address?
    
    // Payment Details (snapshot from Business)
    public var bankName: String?
    public var bankAccountName: String?
    public var bankBSB: String?
    public var bankAccountNumber: String?
    

    @Relationship(deleteRule: .cascade, inverse: \InvoiceItem.invoice) public var items: [InvoiceItem]?
    @Relationship(deleteRule: .nullify) public var payee: Payee?
    @Relationship(deleteRule: .nullify, inverse: \Client.invoices) public var client: Client?
    @Relationship(deleteRule: .nullify, inverse: \Session.invoice) public var sessions: [Session]?
    @Relationship(deleteRule: .nullify) public var business: Business?

    public var clientId: UUID? { client?.id }
    public var sessionIds: [UUID] { sessions?.map(\.id) ?? [] }
    @Relationship(deleteRule: .nullify) public var bulkClaimLines: [BulkClaimLine]?
    
    public init(id: UUID = UUID(), invoiceNumber: String) {
        self.id = id
        self.invoiceNumber = invoiceNumber
    }
    
    // MARK: - Computed Properties

    /// Check if invoice is overdue
    public var isOverdue: Bool {
        guard let dueDate else { return false }
        // A due date is payment-facing only after an invoice is sent. Drafts and
        // invoices still waiting to be sent must not borrow the same overdue
        // warning, otherwise the board asks users to chase payment before a
        // recipient has received anything.
        guard effectiveStatus == .pending || effectiveStatus == .overdue else {
            return false
        }
        return dueDate < Date()
    }

    /// Days until due (negative if overdue)
    public var daysUntilDue: Int? {
        guard let dueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day
    }

    /// Formatted invoice number for display
    public var formattedInvoiceNumber: String {
        invoiceNumber.isEmpty ? "Draft" : invoiceNumber
    }

    /// Returns a thread-safe snapshot of this invoice.
    public func snapshot() -> InvoiceSnapshot {
        InvoiceSnapshot(self)
    }

    /// Sorted array of invoice items by position
    public var itemsArray: [InvoiceItem] {
        (items ?? []).sorted { $0.position < $1.position }
    }
    
    /// Calculated subtotal from line items.
    public var subtotal: Decimal {
        financialTotals.subtotal
    }
    
    /// Calculated discount amount.
    public var discountAmount: Decimal {
        financialTotals.discount
    }
    
    /// Calculated tax amount after discount.
    public var taxAmount: Decimal {
        financialTotals.taxTotal
    }
    
    /// Calculated total amount.
    public var calculatedTotal: Decimal {
        financialTotals.grandTotal
    }

    /// Canonical totals for domain consumers. Legacy invoices with only a global tax rate
    /// continue to apply that rate until their line-item rates are persisted by the editor.
    public var financialTotals: InvoiceFinancialCalculator.Totals {
        let hasExplicitLineTax = itemsArray.contains { $0.taxRate != 0 }
        let lines = itemsArray.map { item in
            InvoiceFinancialCalculator.LineItem(
                quantity: item.quantity,
                unitPrice: item.rate,
                taxRate: hasExplicitLineTax ? item.taxRate : taxRate
            )
        }
        return InvoiceFinancialCalculator.calculate(
            lineItems: lines,
            fixedDiscount: invoiceEditorConfiguration.discountAmount,
            percentageDiscount: discount,
            creditApplied: creditApplied
        )
    }

    /// Synchronizes stored list/workflow total with line-item source of truth.
    @discardableResult
    public func recalculateStoredTotal(fixedDiscount: Decimal? = nil) -> Decimal {
        let hasExplicitLineTax = itemsArray.contains { $0.taxRate != 0 }
        let totals = InvoiceFinancialCalculator.calculate(
            lineItems: itemsArray.map { item in
                InvoiceFinancialCalculator.LineItem(
                    quantity: item.quantity,
                    unitPrice: item.rate,
                    taxRate: hasExplicitLineTax ? item.taxRate : taxRate
                )
            },
            fixedDiscount: fixedDiscount ?? invoiceEditorConfiguration.discountAmount,
            percentageDiscount: discount,
            creditApplied: creditApplied
        )
        totalAmount = totals.grandTotal
        return totals.grandTotal
    }

    /// Invalidates stale editor drafts after any non-editor mutation.
    public func markContentChanged() {
        invoiceEditorRevision += 1
    }
    
    /// Check if invoice is valid for saving
    public var isValid: Bool {
        !invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        client != nil &&
        calculatedTotal >= 0
    }
    
    // MARK: - Snapshot Methods
    
    /// Snapshot all related entity data into the invoice's own properties
    public func snapshotRelatedData(
        billingPlanManager: PlanManager? = nil,
        billingPayee: Payee? = nil
    ) {
        businessAddress = nil
        clientAddress = nil
        billToAddress = nil
        payeeAddress = nil

        // Snapshot business information
        if let business = business {
            businessName = business.name
            businessABN = business.abn
            businessEmail = business.email
            businessAddressSnapshot = Self.snapshotAddress(from: business.address)
            businessPhone = business.phone
        }
        
        // Snapshot client information
        if let client = client {
            clientName = client.fullName
            clientNDISNumber = client.ndisNumber
            clientEmail = client.email
            clientPhone = client.phone
            clientAddressSnapshot = Self.snapshotAddress(from: client.address)
        }
        
        // Snapshot billing information based on invoice billing authority, then client default.
        if let client = client {
            let authority = billingAuthority ?? client.billingAuthority
            billingAuthority = authority

            switch authority {
            case .parentGuardian:
                let payee = billingPayee ?? self.payee ?? client.payee
                if let payee {
                    billToName = payee.fullName
                    billToEmail = payee.email
                    billToAddressSnapshot = Self.snapshotAddress(from: payee.address)

                    payeeName = payee.fullName
                    payeeEmail = payee.email
                    payeePhone = payee.phone
                    payeeAddressSnapshot = Self.snapshotAddress(from: payee.address)
                }
            case .client:
                billToName = client.fullName
                billToEmail = client.email
                billToAddressSnapshot = Self.snapshotAddress(from: client.address)
            case .planManager:
                if let planManager = billingPlanManager ?? client.planManager {
                    billToName = planManager.name
                    billToEmail = planManager.email
                    billToAddressSnapshot = Self.snapshotAddress(from: planManager.address)
                }
            case .ndia, .none:
                break
            }
        }
        
        // Also snapshot payee data directly from payee relationship if it exists
        // This handles cases where payee is set directly on the invoice
        if let directPayee = payee {
            if payeeName == nil { payeeName = directPayee.fullName }
            if payeeEmail == nil { payeeEmail = directPayee.email }
            if payeePhone == nil { payeePhone = directPayee.phone }
            if payeeAddressSnapshot == nil {
                payeeAddressSnapshot = Self.snapshotAddress(from: directPayee.address)
            }
            
            // If billing authority suggests parent/guardian but billTo fields aren't set, populate them
            if (billingAuthority == .parentGuardian || billingAuthority == nil) && billToName == nil {
                billToName = directPayee.fullName
                billToEmail = directPayee.email
                billToAddressSnapshot = Self.snapshotAddress(from: directPayee.address)
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

    private static func snapshotAddress(from sourceAddress: Address?) -> AddressSnapshot? {
        guard let sourceAddress else { return nil }
        return AddressSnapshot(sourceAddress)
    }
}
