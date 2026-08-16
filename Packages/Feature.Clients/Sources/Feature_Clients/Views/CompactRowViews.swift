import SwiftUI
import SwiftData
import Core
import PersistenceModels
import SharedUI

// MARK: - Compact Row Views

private struct CompactStatusRow<Leading: View, Content: View>: View {
    let badgeStatus: String
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            leading()
            content()
            Spacer()
            StatusBadge(status: badgeStatus)
                .scaleEffect(0.8)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
        .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
    }
}

struct CompactServiceRowView: View {
    let service: ClientService

    var body: some View {
        CompactStatusRow(badgeStatus: service.status ?? "Active") {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                Text(service.serviceName)
                    .font(StyleGuide.Typography.compactRowTitle)
                    .foregroundColor(StyleGuide.Colors.text)
                Text("\(service.unit) • \(CurrencyFormatting.display(service.rate))")
                    .font(StyleGuide.Typography.caption)
                    .foregroundColor(StyleGuide.Colors.textSecondary)
                if let months = service.consecutiveMonths {
                    Text("Establishment fee: \(months) consecutive month\(months == 1 ? "" : "s")")
                        .font(StyleGuide.Typography.caption)
                        .foregroundColor(StyleGuide.Colors.textSecondary)
                }
            }
        }
    }
}

struct CompactInvoiceRowView: View {
    let invoice: Invoice

    var body: some View {
        CompactStatusRow(badgeStatus: invoice.status?.rawValue ?? "") {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                Text(invoice.invoiceNumber)
                    .font(StyleGuide.Typography.compactRowTitle)
                    .foregroundColor(StyleGuide.Colors.text)
                Text("\(CurrencyFormatting.display(invoice.totalAmount)) • \(DateFormatting.mediumDate(invoice.issueDate))")
                    .font(StyleGuide.Typography.caption)
                    .foregroundColor(StyleGuide.Colors.textSecondary)
            }
        }
    }
}

struct CompactClientRowView: View {
    let client: Client

    var body: some View {
        CompactStatusRow(badgeStatus: client.status?.rawValue ?? "") {
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.paddingXXSmall)
                .fill(ColorSystem.Client.color(for: client.id))
                .frame(
                    width: StyleGuide.Dimensions.accentBarWidth,
                    height: StyleGuide.Dimensions.fontSizeCompactTitle + StyleGuide.Dimensions.paddingXSmall
                )
        } content: {
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
        }
    }
}
