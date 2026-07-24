import SwiftUI

public struct CompactRowStyle: ViewModifier {
    let isHovering: Bool

    public init(isHovering: Bool) {
        self.isHovering = isHovering
    }

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
            .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
            .contentShape(.rect(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact))
            .background(
                Color.primary.opacity(isHovering ? StyleGuide.Opacity.light : StyleGuide.Opacity.faint - 0.02),
                in: RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact)
                    .stroke(ColorSystem.Neutral.gray500.opacity(StyleGuide.Opacity.medium), lineWidth: 1)
            )
            .padding(EdgeInsets(
                top: StyleGuide.Dimensions.paddingXXSmall,
                leading: StyleGuide.Dimensions.paddingXXSmall,
                bottom: StyleGuide.Dimensions.paddingXXSmall,
                trailing: StyleGuide.Dimensions.paddingXXSmall
            ))
    }
}

public extension View {
    func compactRowStyle(isHovering: Bool) -> some View {
        modifier(CompactRowStyle(isHovering: isHovering))
    }
}
