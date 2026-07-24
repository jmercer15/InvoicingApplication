import SwiftUI

/// Shared detail-card layout used by feature detail views.
/// Uses deterministic column calculation to avoid adaptive-grid jitter.
public struct DetailCardsLayout<Content: View>: View {
    private let minCardWidth: CGFloat
    private let spacing: CGFloat
    private let horizontalInset: CGFloat
    private let verticalInset: CGFloat
    private let content: () -> Content

    public init(
        minCardWidth: CGFloat = 320,
        spacing: CGFloat = PanelShellTokens.contentListGridSpacing,
        horizontalInset: CGFloat = PanelShellTokens.contentListHorizontalInset,
        verticalInset: CGFloat = PanelShellTokens.contentListVerticalInset,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.minCardWidth = minCardWidth
        self.spacing = spacing
        self.horizontalInset = horizontalInset
        self.verticalInset = verticalInset
        self.content = content
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: minCardWidth), spacing: spacing, alignment: .top)],
                alignment: .leading,
                spacing: spacing
            ) {
                content()
            }
            .padding(.horizontal, horizontalInset)
            .padding(.vertical, verticalInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

