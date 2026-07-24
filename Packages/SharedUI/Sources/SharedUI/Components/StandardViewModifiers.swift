import SwiftUI

// MARK: - Card & Section Surfaces

private struct StandardCardStyleModifier: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = StyleGuide.Dimensions.cornerRadiusSmall
    @ScaledMetric(relativeTo: .body) private var padding: CGFloat = StyleGuide.Dimensions.paddingLarge

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(StyleGuide.Colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(StyleGuide.Colors.border, lineWidth: 0.6)
                    )
            )
    }
}

private struct StandardSectionStyleModifier: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = StyleGuide.Dimensions.cornerRadiusSmall
    @ScaledMetric(relativeTo: .body) private var padding: CGFloat = StyleGuide.Dimensions.paddingXXLarge - 12

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(StyleGuide.Colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(StyleGuide.Colors.border, lineWidth: 0.6)
                    )
            )
    }
}

// MARK: - Form Typography

private struct FormDescriptionStyleModifier: ViewModifier {
    @ScaledMetric(relativeTo: .footnote) private var leadingInset: CGFloat = StyleGuide.Dimensions.paddingXXLarge - 12

    func body(content: Content) -> some View {
        content
            .font(.footnote)
            .foregroundStyle(StyleGuide.Colors.textSecondary)
            .padding(.leading, leadingInset)
            .lineSpacing(1.5)
    }
}

private struct FormErrorStyleModifier: ViewModifier {
    @ScaledMetric(relativeTo: .footnote) private var leadingInset: CGFloat = StyleGuide.Dimensions.paddingXXLarge - 12

    func body(content: Content) -> some View {
        content
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(ColorSystem.Status.error)
            .padding(.leading, leadingInset)
    }
}

private struct FormSectionTitleStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(StyleGuide.Typography.sectionTitle)
            .padding(.bottom, StyleGuide.Dimensions.paddingXSmall)
    }
}

public extension View {
    /// Compact bordered card surface for grouped settings or detail blocks.
    func standardCardStyle() -> some View {
        modifier(StandardCardStyleModifier())
    }

    /// Roomier bordered section surface for settings pages.
    func standardSectionStyle() -> some View {
        modifier(StandardSectionStyleModifier())
    }

    func formDescriptionStyle() -> some View {
        modifier(FormDescriptionStyleModifier())
    }

    func formErrorStyle() -> some View {
        modifier(FormErrorStyleModifier())
    }

    func formSectionTitleStyle() -> some View {
        modifier(FormSectionTitleStyleModifier())
    }
}
