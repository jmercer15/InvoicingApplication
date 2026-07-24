import SwiftUI

/// Title + optional subtitle + trailing badge/action group for detail toolbars and headers.
public struct DetailToolbarTitleStack<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let titleFont: Font
    let subtitleFont: Font
    @ViewBuilder let trailing: () -> Trailing

    public init(
        title: String,
        subtitle: String? = nil,
        titleFont: Font = .headline,
        subtitleFont: Font = .caption2,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.titleFont = titleFont
        self.subtitleFont = subtitleFont
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: DetailToolbarTokens.titleBadgeSpacing) {
            VStack(alignment: .leading, spacing: DetailToolbarTokens.titleSubtitleSpacing) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(StyleGuide.Colors.text)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(subtitleFont)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                }
            }

            trailing()
        }
    }
}

public extension DetailToolbarTitleStack where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        titleFont: Font = .headline,
        subtitleFont: Font = .caption2
    ) {
        self.title = title
        self.subtitle = subtitle
        self.titleFont = titleFont
        self.subtitleFont = subtitleFont
        self.trailing = { EmptyView() }
    }
}
