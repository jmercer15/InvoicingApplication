import SwiftUI

/// Shared breadcrumb chrome for hierarchical content panels.
public struct AppBreadcrumbBackButton: View {
    private let action: () -> Void

    @FocusState private var isFocused: Bool

    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = PanelShellTokens.panelCornerRadius
    @ScaledMetric(relativeTo: .body) private var buttonWidth: CGFloat = 42

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Button(action: action) {
            shape
                .fill(Color.accentColor.opacity(StyleGuide.Opacity.light))
                .frame(width: buttonWidth)
                .frame(maxHeight: .infinity)
                .overlay(
                    shape.stroke(isFocused ? ColorSystem.Primary.blue : Color.accentColor.opacity(0.45), lineWidth: isFocused ? 2 : 1)
                )
                .overlay(
                    Image(systemName: "chevron.backward")
                        .font(StyleGuide.Typography.breadcrumbIcon)
                        .foregroundStyle(Color.accentColor)
                )
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .focusable()
        .focused($isFocused)
        .accessibilityLabel("Back")
    }
}

public struct AppBreadcrumbSegmentButton: View {
    private let title: String
    private let count: Int
    private let indentLevel: Int
    private let backgroundColor: Color
    private let action: () -> Void

    @FocusState private var isFocused: Bool

    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = PanelShellTokens.panelCornerRadius
    @ScaledMetric(relativeTo: .body) private var verticalPadding: CGFloat = StyleGuide.Dimensions.paddingSmall
    @ScaledMetric(relativeTo: .body) private var horizontalPadding: CGFloat = StyleGuide.Dimensions.paddingXMedium + 4
    @ScaledMetric(relativeTo: .body) private var indentStep: CGFloat = StyleGuide.Dimensions.paddingXMedium + 4

    public init(
        title: String,
        count: Int,
        indentLevel: Int,
        backgroundColor: Color,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.count = count
        self.indentLevel = indentLevel
        self.backgroundColor = backgroundColor
        self.action = action
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Button(action: action) {
            HStack(spacing: StyleGuide.Dimensions.paddingMediumLarge) {
                Text(title)
                    .font(StyleGuide.Typography.breadcrumb)
                    .foregroundStyle(StyleGuide.Colors.text)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("\(count)")
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .padding(.leading, CGFloat(indentLevel) * indentStep)
            .background(
                shape
                    .fill(backgroundColor)
                    .overlay(
                        shape.stroke(isFocused ? ColorSystem.Primary.blue : Color.primary.opacity(StyleGuide.Opacity.light), lineWidth: isFocused ? 2 : 0.6)
                    )
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .focusable()
        .focused($isFocused)
    }
}

/// Standard breadcrumb bar layout: optional back button + stacked segment buttons.
public struct AppBreadcrumbBar<Segments: View>: View {
    private let showsBackButton: Bool
    private let onBack: () -> Void
    private let segments: Segments

    public init(
        showsBackButton: Bool,
        onBack: @escaping () -> Void,
        @ViewBuilder segments: () -> Segments
    ) {
        self.showsBackButton = showsBackButton
        self.onBack = onBack
        self.segments = segments()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: StyleGuide.Dimensions.paddingMedium) {
            if showsBackButton {
                AppBreadcrumbBackButton(action: onBack)
            }

            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
                segments
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .standardContentPanelBreadcrumbInsets()
    }
}
