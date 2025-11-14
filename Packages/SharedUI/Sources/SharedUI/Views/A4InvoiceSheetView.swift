//
//  A4InvoiceSheetView.swift
//  SharedUI
//
//  Created by AI Assistant for Refactoring Initiative
//
import SwiftUI
import Core

/// Simple business information for invoice rendering
public struct BusinessInfo {
    public let name: String?
    public let abn: String?
    public let email: String?
    public let phone: String?
    public let address: String?
    public let bankName: String?
    public let bankAccountName: String?
    public let bankBSB: String?
    public let bankAccountNumber: String?
    
    public init(
        name: String? = nil,
        abn: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        address: String? = nil,
        bankName: String? = nil,
        bankAccountName: String? = nil,
        bankBSB: String? = nil,
        bankAccountNumber: String? = nil
    ) {
        self.name = name
        self.abn = abn
        self.email = email
        self.phone = phone
        self.address = address
        self.bankName = bankName
        self.bankAccountName = bankAccountName
        self.bankBSB = bankBSB
        self.bankAccountNumber = bankAccountNumber
    }
    
    /// Create BusinessInfo from Invoice snapshot data
    public static func from(invoice: Invoice) -> BusinessInfo {
        BusinessInfo(
            name: invoice.businessName,
            abn: invoice.businessABN,
            email: invoice.businessEmail,
            phone: invoice.businessPhone,
            address: invoice.businessAddress,
            bankName: invoice.bankName,
            bankAccountName: invoice.bankAccountName,
            bankBSB: invoice.bankBSB,
            bankAccountNumber: invoice.bankAccountNumber
        )
    }
}

/// A simplified A4 invoice sheet view for PDF rendering
public struct A4InvoiceSheetView: View {
    let invoice: Invoice
    let invoiceItems: [InvoiceItem]
    let business: BusinessInfo?
    
    public init(invoice: Invoice, invoiceItems: [InvoiceItem] = [], business: BusinessInfo? = nil) {
        self.invoice = invoice
        self.invoiceItems = invoiceItems
        // Use business parameter if provided, otherwise extract from invoice snapshot
        self.business = business ?? BusinessInfo.from(invoice: invoice)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("TAX INVOICE")
                    .font(.system(size: 24, weight: .bold))
                Spacer()
                VStack(alignment: .trailing) {
                    Text(business?.name ?? "Your Business")
                        .font(.system(size: 20, weight: .bold))
                    Text(business?.abn ?? "ABN: N/A")
                        .font(.system(size: 11))
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // Invoice details
            HStack {
                VStack(alignment: .leading) {
                    Text("Invoice #: \(invoice.invoiceNumber)")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Date: \(invoice.date, formatter: dateFormatter)")
                        .font(.system(size: 12))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Bill To:")
                        .font(.system(size: 12, weight: .semibold))
                    Text(invoice.clientName ?? invoice.billToName ?? "Unknown Client")
                        .font(.system(size: 12))
                }
            }
            .padding()
            
            // Items table
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Description")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Qty")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 60)
                    Text("Rate")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 80)
                    Text("Amount")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 80)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                
                // Items
                ForEach(Array(invoiceItems.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        Text(item.itemDescription)
                            .font(.system(size: 11))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(item.quantity, specifier: "%.0f")")
                            .font(.system(size: 11))
                            .frame(width: 60)
                        Text("$\(item.rate, specifier: "%.2f")")
                            .font(.system(size: 11))
                            .frame(width: 80)
                        Text("$\(item.lineTotal, specifier: "%.2f")")
                            .font(.system(size: 11))
                            .frame(width: 80)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
            .overlay(
                Rectangle()
                    .stroke(Color.gray, lineWidth: 1)
            )
            
            // Total
            HStack {
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Total: $\(invoice.totalAmount, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .padding()
            
            Spacer()
        }
        .frame(width: 595, height: 842) // A4 size
        .background(Color.white)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}
