import SwiftUI
import SharedUI

/// Payment-vs-invoice comparison chip for Pending Payment and Payment Received panels.
struct BillingHubPaymentComparisonLabel: View {
    enum Style {
        /// Short labels while entering an amount (includes match confirmation).
        case entry
        /// Narrative labels after payment is recorded (hides exact matches).
        case recorded
    }

    let comparison: BillingHubPaymentAmount.Comparison?
    let style: Style

    var body: some View {
        switch (style, comparison) {
        case (.entry, .matches):
            Label("Matches invoice total", systemImage: "checkmark.circle.fill")
                .foregroundStyle(ColorSystem.Status.success)
        case (.entry, .underpayment(let difference)):
            Label(
                "\(BillingHubPaymentAmount.currencyText(difference)) outstanding",
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(ColorSystem.Status.warning)
        case (.entry, .overpayment(let difference)):
            Label(
                "\(BillingHubPaymentAmount.currencyText(difference)) overpayment",
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(ColorSystem.Status.warning)
        case (.recorded, .underpayment(let difference)):
            Label(
                "Partial payment · \(BillingHubPaymentAmount.currencyText(difference)) remains outstanding.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(StyleGuide.Typography.itemSubtitle)
            .foregroundStyle(ColorSystem.Status.warning)
        case (.recorded, .overpayment(let difference)):
            Label(
                "Overpayment recorded · \(BillingHubPaymentAmount.currencyText(difference)) above invoice total.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(StyleGuide.Typography.itemSubtitle)
            .foregroundStyle(ColorSystem.Status.warning)
        case (.recorded, .matches), (_, nil):
            EmptyView()
        }
    }
}
