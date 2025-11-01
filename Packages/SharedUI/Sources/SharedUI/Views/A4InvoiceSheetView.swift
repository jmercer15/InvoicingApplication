//
//  A4InvoiceSheetView.swift
//  SharedUI
//
//  Created by AI Assistant for Refactoring Initiative
//
import SwiftUI
import Data
import Core

/// A simplified A4 invoice sheet view for PDF rendering
public struct A4InvoiceSheetView: View {
    let invoice: InvoiceEntity
    let business: BusinessEntity?
    
    public init(invoice: InvoiceEntity, business: BusinessEntity?) {
        self.invoice = invoice
        self.business = business
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
                    Text(invoice.client?.fullName ?? "Unknown Client")
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
                ForEach(Array(invoice.items.enumerated()), id: \.offset) { index, item in
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
                        Text("$\(item.amount, specifier: "%.2f")")
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
