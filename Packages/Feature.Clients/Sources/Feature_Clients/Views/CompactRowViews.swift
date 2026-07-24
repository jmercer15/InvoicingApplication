import SwiftUI
import SwiftData
import Data
import Core
import SharedUI

// MARK: - Compact Row Views

struct CompactServiceRowView: View {
    let service: ClientService
    
    var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                Text(service.serviceName)
                    .font(StyleGuide.Typography.compactRowTitle)
                    .foregroundColor(StyleGuide.Colors.text)
                Text("\(service.unit) • $\(service.rate, specifier: "%.2f")")
                    .font(StyleGuide.Typography.caption)
                    .foregroundColor(StyleGuide.Colors.textSecondary)
            }
            
            Spacer()
            
            StatusBadge(status: service.status ?? "Active")
                .scaleEffect(0.8)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
        .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
    }
}

struct CompactInvoiceRowView: View {
    let invoice: Invoice
    
    var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                Text(invoice.invoiceNumber)
                    .font(StyleGuide.Typography.compactRowTitle)
                    .foregroundColor(StyleGuide.Colors.text)
                Text("$\(invoice.totalAmount, specifier: "%.2f") • \(invoice.issueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(StyleGuide.Typography.caption)
                    .foregroundColor(StyleGuide.Colors.textSecondary)
            }
            
            Spacer()
            
            StatusBadge(status: invoice.status?.rawValue ?? "")
                .scaleEffect(0.8)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
        .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
    }
}

struct CompactClientRowView: View {
    let client: Client
    
    var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.paddingXXSmall)
                .fill(ColorSystem.Client.color(for: client.id))
                .frame(
                    width: StyleGuide.Dimensions.accentBarWidth,
                    height: StyleGuide.Dimensions.fontSizeCompactTitle + StyleGuide.Dimensions.paddingXSmall
                )
            
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                Text(client.fullName)
                    .font(StyleGuide.Typography.compactRowTitle)
                    .foregroundColor(StyleGuide.Colors.text)
                if !client.ndisNumber.isEmpty {
                    Text("NDIS: \(client.ndisNumber)")
                        .font(StyleGuide.Typography.caption)
                        .foregroundColor(StyleGuide.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            StatusBadge(status: client.status?.rawValue ?? "")
                .scaleEffect(0.8)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
        .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
    }
}
