import SwiftUI
import Core
import SharedUI

public struct RevenueAnalyticsSummaryView: View {
    public let summary: RevenueAnalyticsSummary
    @State private var selectedCurrencyIndex: Int = 0

    public init(summary: RevenueAnalyticsSummary) {
        self.summary = summary
    }

    public var body: some View {
        if !summary.currencySummaries.isEmpty {
            let summaries = summary.currencySummaries
            let activeSummary = summaries.indices.contains(selectedCurrencyIndex)
                ? summaries[selectedCurrencyIndex]
                : summaries[0]

            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingSmall) {
                if summaries.count > 1 {
                    Picker("Currency", selection: $selectedCurrencyIndex) {
                        ForEach(Array(summaries.enumerated()), id: \.offset) { index, item in
                            Text(item.currencyCode).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                }

                HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                    metricCard(
                        title: "Total Billed",
                        amount: activeSummary.totalBilled,
                        currency: activeSummary.currencyCode,
                        icon: "dollarsign.circle.fill",
                        color: StyleGuide.Colors.primary
                    )

                    metricCard(
                        title: "Received",
                        amount: activeSummary.totalReceived,
                        currency: activeSummary.currencyCode,
                        icon: "checkmark.circle.fill",
                        color: .green
                    )

                    metricCard(
                        title: "Outstanding",
                        amount: activeSummary.totalOutstanding,
                        currency: activeSummary.currencyCode,
                        subtitle: activeSummary.totalOverdue > 0
                            ? "Overdue: \(formatAmount(activeSummary.totalOverdue, currency: activeSummary.currencyCode))"
                            : nil,
                        icon: "exclamationmark.triangle.fill",
                        color: activeSummary.totalOverdue > 0 ? .red : .orange
                    )

                    draftCard(count: activeSummary.draftCount)
                }
            }
            .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
            .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
            .background(ColorSystem.Neutral.gray50.opacity(0.6))
            .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
        }
    }

    private func metricCard(
        title: String,
        amount: Double,
        currency: String,
        subtitle: String? = nil,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(title)
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }
            Text(formatAmount(amount, currency: currency))
                .font(StyleGuide.Typography.bodyMedium)
                .bold()
                .foregroundStyle(StyleGuide.Colors.text)
                .monospacedDigit()

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(StyleGuide.Dimensions.paddingSmall)
        .background(ColorSystem.Neutral.white)
        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
    }

    private func draftCard(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text.fill")
                    .font(.caption2)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                Text("Drafts")
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }
            Text("\(count)")
                .font(StyleGuide.Typography.bodyMedium)
                .bold()
                .foregroundStyle(StyleGuide.Colors.text)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(StyleGuide.Dimensions.paddingSmall)
        .background(ColorSystem.Neutral.white)
        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
    }

    private func formatAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}
