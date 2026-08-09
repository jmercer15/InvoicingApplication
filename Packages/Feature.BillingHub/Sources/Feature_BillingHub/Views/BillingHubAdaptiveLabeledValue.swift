import SwiftUI
import SharedUI

/// Keeps short metadata compact, then reflows long values below their label instead of
/// compressing or silently truncating billing-critical text.
struct BillingHubAdaptiveLabeledValue: View {
    let label: String
    let value: String
    var help: String? = nil

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: StyleGuide.Dimensions.paddingMedium) {
                labelText
                Spacer(minLength: StyleGuide.Dimensions.paddingMedium)
                valueText
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                labelText
                valueText
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(OptionalHelpModifier(helpText: help))
    }

    private var labelText: some View {
        Text(label)
            .font(StyleGuide.Typography.bodyMedium)
            .foregroundStyle(BillingHubTheme.Palette.textSecondary)
    }

    private var valueText: some View {
        Text(value)
            .textSelection(.enabled)
            .truncationMode(.tail)
    }
}

private struct OptionalHelpModifier: ViewModifier {
    let helpText: String?

    func body(content: Content) -> some View {
        if let helpText {
            content.help(helpText)
        } else {
            content
        }
    }
}
