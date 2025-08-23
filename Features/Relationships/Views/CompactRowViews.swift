import SwiftUI
import SwiftData

// MARK: - Compact Row Views

struct CompactServiceRowView: View {
    @Bindable var service: ClientServiceEntity
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(service.serviceName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text("\(service.unit) • $\(service.rate, specifier: "%.2f")")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            StatusBadge(status: service.status ?? "Active")
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 6))
    }
}

struct CompactInvoiceRowView: View {
    let invoice: InvoiceEntity
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(invoice.invoiceNumber)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text("$\(invoice.totalAmount, specifier: "%.2f") • \(invoice.issueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            StatusBadge(status: invoice.status ?? "Draft")
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 6))
    }
}

struct CompactClientRowView: View {
    let client: ClientEntity
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: client.colorHex))
                .frame(width: 3, height: 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(client.fullName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                if !client.ndisNumber.isEmpty {
                    Text("NDIS: \(client.ndisNumber)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            StatusBadge(status: client.status)
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 6))
    }
} 