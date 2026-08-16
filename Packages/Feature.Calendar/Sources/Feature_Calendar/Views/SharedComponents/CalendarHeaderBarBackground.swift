import SwiftUI
import SharedUI

/// Shared top-bar fill for week/month calendar header strips.
struct CalendarHeaderBarBackground: View {
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat =
        StyleGuide.Dimensions.cornerRadiusLarge + 4

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: cornerRadius,
            topTrailingRadius: cornerRadius
        )
        .fill(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.strong))
    }
}

/// Vertical weekday-column hairline used by week and month headers.
struct CalendarHeaderColumnDivider: View {
    var opacity: Double = 0.2

    var body: some View {
        Rectangle()
            .fill(StyleGuide.Colors.border.opacity(opacity))
            .frame(width: StyleGuide.Dimensions.hairlineWidth)
    }
}

/// Bottom edge under week/month header strips (call sites keep their fill/height).
struct CalendarHeaderBottomHairline: View {
    var fill: Color = StyleGuide.Colors.border.opacity(0.2)
    var height: CGFloat = StyleGuide.Dimensions.hairlineWidth

    var body: some View {
        Rectangle()
            .fill(fill)
            .frame(height: height)
    }
}
