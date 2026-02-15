import SwiftUI
import SwiftData
import Data
import Core
import SharedUI

// MARK: - Compact Row Views

struct CompactServiceRowView: View {
    let service: ClientService
    @State private var isHovering = false
    
    private let rowInsets = EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(service.serviceName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                Text("\(service.unit) • $\(service.rate, specifier: "%.2f")")
                    .font(.system(size: 11))
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            
            Spacer()
            
            StatusBadge(status: service.status ?? "Active")
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .contentShape(.rect(cornerRadius: 6))
        .background(Color.primary.opacity(isHovering ? 0.1 : 0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(rowInsets)
    }
}

struct CompactInvoiceRowView: View {
    let invoice: Invoice
    @State private var isHovering = false
    
    private let rowInsets = EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(invoice.invoiceNumber)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                Text("$\(invoice.totalAmount, specifier: "%.2f") • \(invoice.issueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 11))
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            
            Spacer()
            
            StatusBadge(status: invoice.status)
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .contentShape(.rect(cornerRadius: 6))
        .background(Color.primary.opacity(isHovering ? 0.1 : 0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(rowInsets)
    }
}

struct CompactClientRowView: View {
    let client: Client
    @State private var isHovering = false
    
    private let rowInsets = EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(ColorSystem.Client.color(for: client.id))
                .frame(width: 3, height: 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(client.fullName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                if !client.ndisNumber.isEmpty {
                    Text("NDIS: \(client.ndisNumber)")
                        .font(.system(size: 11))
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
            }
            
            Spacer()
            
            StatusBadge(status: client.status)
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .contentShape(.rect(cornerRadius: 6))
        .background(Color.primary.opacity(isHovering ? 0.1 : 0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(rowInsets)
    }
} 
