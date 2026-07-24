import SwiftUI

/// Compact icon + label + value chip for summary metrics in detail and workflow panels.
public struct InfoChip: View {
    public let icon: String
    public let label: String
    public let value: String
    public let color: Color

    public init(icon: String, label: String, value: String, color: Color) {
        self.icon = icon
        self.label = label
        self.value = value
        self.color = color
    }

    public var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(StyleGuide.Typography.infoChipLabel)
                .frame(
                    width: StyleGuide.Dimensions.infoChipIconSize,
                    height: StyleGuide.Dimensions.infoChipIconSize
                )
                .background(color.opacity(StyleGuide.Opacity.light))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                Text(label.uppercased())
                    .font(StyleGuide.Typography.infoChipLabel)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)

                Text(value)
                    .font(StyleGuide.Typography.infoChipValue)
                    .foregroundStyle(StyleGuide.Colors.text)
            }
        }
        .padding(.trailing, StyleGuide.Dimensions.paddingMediumLarge)
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous)
                .stroke(StyleGuide.Colors.border.opacity(StyleGuide.Opacity.light), lineWidth: 1)
        )
    }
}
