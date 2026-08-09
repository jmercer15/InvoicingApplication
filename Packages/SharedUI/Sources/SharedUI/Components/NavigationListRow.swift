import SwiftUI

/// Shared navigation list row for hierarchical content panels (parent drill-down + leaf selection).
public struct NavigationListRow: View {
    public enum Style {
        case parent
        case leaf(entityType: String?, entityTint: Color)
    }

    let title: String
    let subtitle: String?
    let style: Style
    let isHighlighted: Bool
    let onTap: () -> Void

    public init(
        title: String,
        subtitle: String? = nil,
        style: Style,
        isHighlighted: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.isHighlighted = isHighlighted
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            Group {
                switch style {
                case .parent:
                    parentRow
                case .leaf(let entityType, let entityTint):
                    leafRow(entityType: entityType, entityTint: entityTint)
                }
            }
            .padding(ListRowTokens.rowPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: ListRowTokens.rowCornerRadius))
        }
        .buttonStyle(.plain)
        .focusable()
        .glassEffect(.regular.interactive(true), in: RoundedRectangle(cornerRadius: ListRowTokens.rowCornerRadius))
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }

    private var parentRow: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingLarge) {
            titleBlock(titleFont: StyleGuide.Typography.itemTitle, titleColor: StyleGuide.Colors.text)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
        }
    }

    private func leafRow(entityType: String?, entityTint: Color) -> some View {
        HStack(spacing: ListRowTokens.rowContentSpacing) {
            titleBlock(
                titleFont: StyleGuide.Typography.compactRowTitle,
                titleColor: StyleGuide.Colors.text
            )
            .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: isHighlighted)

            Spacer()

            if let entityType {
                HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                    Circle()
                        .fill(entityTint)
                        .frame(width: ListRowTokens.entityDotSize, height: ListRowTokens.entityDotSize)
                        .animation(.spring(response: 0.1, dampingFraction: 0.9), value: isHighlighted)

                    Text(entityType.capitalized)
                        .font(StyleGuide.Typography.caption)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                }
            }
        }
        .animation(.spring(response: 0.12, dampingFraction: 0.85), value: isHighlighted)
    }

    private func titleBlock(titleFont: Font, titleColor: Color) -> some View {
        VStack(alignment: .leading, spacing: ListRowTokens.titleSubtitleSpacing) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .help(title)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                    .lineLimit(1)
                    .help(subtitle)
                    .opacity(isHighlighted ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: isHighlighted)
            }
        }
    }
}
