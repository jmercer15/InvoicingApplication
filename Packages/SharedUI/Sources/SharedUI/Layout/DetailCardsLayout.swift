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
        spacing: CGFloat = 20,
        horizontalInset: CGFloat = 24,
        verticalInset: CGFloat = 24,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.minCardWidth = minCardWidth
        self.spacing = spacing
        self.horizontalInset = horizontalInset
        self.verticalInset = verticalInset
        self.content = content
    }

    public var body: some View {
        GeometryReader { geometry in
            let columns = gridColumns(for: geometry.size.width)

            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
                    content()
                }
                .padding(.horizontal, horizontalInset)
                .padding(.vertical, verticalInset)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func gridColumns(for totalWidth: CGFloat) -> [GridItem] {
        let insets = horizontalInset * 2
        let availableWidth = max(0, totalWidth - insets)
        let columnCount = max(1, Int((availableWidth + spacing) / (minCardWidth + spacing)))
        let enforcedColumnMinWidth = max(0, min(minCardWidth, availableWidth))

        return Array(
            repeating: GridItem(
                .flexible(minimum: enforcedColumnMinWidth, maximum: .infinity),
                spacing: spacing,
                alignment: .top
            ),
            count: columnCount
        )
    }
}

