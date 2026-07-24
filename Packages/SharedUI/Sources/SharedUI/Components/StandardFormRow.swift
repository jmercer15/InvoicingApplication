import SwiftUI

public struct StandardFormRow<Content: View>: View {
    let label: String
    let labelWidth: CGFloat
    let content: Content

    public init(
        _ label: String,
        labelWidth: CGFloat = 120,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.labelWidth = labelWidth
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: StyleGuide.Dimensions.paddingMediumLarge) {
            Text(label)
                .font(StyleGuide.Typography.bodyMedium)
                .foregroundStyle(StyleGuide.Colors.text)
                .frame(width: labelWidth, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: true, vertical: false) // Ensure width is respected

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
