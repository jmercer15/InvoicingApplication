import SwiftUI
import SharedUI

@ViewBuilder
private func highlightedText(_ text: String, searchingFor query: String) -> some View {
    if !query.isEmpty, let range = text.range(of: query, options: .caseInsensitive) {
        let prefix = text[..<range.lowerBound]
        let match = text[range]
        let suffix = text[range.upperBound...]

        Text(
            "\(Text(String(prefix)))\(Text(String(match)).bold().foregroundStyle(Color.accentColor))\(Text(String(suffix)))"
        )
    } else {
        Text(text)
    }
}

struct KanbanCardView: View, Equatable {
    nonisolated static func == (lhs: KanbanCardView, rhs: KanbanCardView) -> Bool {
        lhs.card.id == rhs.card.id &&
        lhs.card.titleText == rhs.card.titleText &&
        lhs.card.subtitleText == rhs.card.subtitleText &&
        lhs.card.detailText == rhs.card.detailText &&
        lhs.card.statusText == rhs.card.statusText &&
        lhs.card.trailingMetadataSymbol == rhs.card.trailingMetadataSymbol &&
        lhs.card.accentColor == rhs.card.accentColor &&
        lhs.isSelected == rhs.isSelected &&
        lhs.searchText == rhs.searchText
    }

    let cardActions: KanbanCardActions
    let card: KanbanCardData
    let isSelected: Bool
    let onTap: () -> Void
    var onOpen: (() -> Void)? = nil
    var searchText: String = ""

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(card.accentColor)
                    .frame(width: BillingHubTheme.Dimensions.dragHandleWidth)
                    .frame(alignment: .leading)

                VStack(alignment: .leading, spacing: ListRowTokens.titleSubtitleSpacing + 4) {
                    highlightedText(card.titleText, searchingFor: searchText)
                        .font(BillingHubTheme.Typography.cardTitle)
                        .foregroundStyle(BillingHubTheme.Palette.textPrimary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)

                    highlightedText(card.subtitleText, searchingFor: searchText)
                        .font(BillingHubTheme.Typography.cardSubtitle)
                        .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: ListRowTokens.metadataSpacing + 2) {
                            metadataLeading

                            Spacer(minLength: 4)

                            metadataTrailing
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            metadataLeading
                            metadataTrailing
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(BillingHubTheme.Dimensions.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.cardCornerRadius)
                .strokeBorder(
                    isSelected
                        ? card.accentColor
                        : BillingHubTheme.Surfaces.cardStroke.opacity(BillingHubTheme.Surfaces.cardDefaultStrokeOpacity),
                    lineWidth: isSelected
                        ? BillingHubTheme.Surfaces.cardSelectedStrokeWidth
                        : BillingHubTheme.Surfaces.cardDefaultStrokeWidth
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.cardCornerRadius))
        .contextMenu {
            Button {
                onTap()
                onOpen?()
            } label: {
                Label("Open Details", systemImage: "pencil")
            }

            if let nextColumn = cardActions.nextColumn(card) {
                Divider()

                Button {
                    Task {
                        await cardActions.advanceCard(card)
                    }
                } label: {
                    Label("Move to \(nextColumn.menuTitle)", systemImage: "arrow.right.circle")
                }
            }
        }
        .onKeyPress(.return) {
            onTap()
            onOpen?()
            return .handled
        }
        .billingHubPointerStyle(.link)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Press Return or double click to open details.")
        .accessibilityAddTraits(
            isSelected ? [.isButton, .isSelected] : .isButton
        )
        .accessibilityAction(named: "Open Details") {
            onTap()
            onOpen?()
        }
    }

    private var accessibilitySummary: String {
        [
            card.titleText,
            card.subtitleText,
            card.columnType.laneTitle,
            card.detailText ?? "No date",
            card.statusText,
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }

    private var metadataLeading: some View {
        HStack(spacing: ListRowTokens.metadataSpacing) {
            Image(systemName: "calendar")
                .font(BillingHubTheme.Typography.cardMetadata)
                .foregroundStyle(BillingHubTheme.Palette.textSecondary)
            Text(card.detailText ?? "No date")
                .font(BillingHubTheme.Typography.cardMetadata)
                .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var metadataTrailing: some View {
        HStack(spacing: ListRowTokens.metadataSpacing) {
            Image(systemName: card.trailingMetadataSymbol)
                .font(BillingHubTheme.Typography.cardMetadata)
                .foregroundStyle(BillingHubTheme.Palette.textSecondary)
            Text(card.statusText ?? "No amount")
                .font(BillingHubTheme.Typography.cardMetadata)
                .fontWeight(.semibold)
                .foregroundStyle(BillingHubTheme.Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.cardCornerRadius, style: .continuous)
            .fill(BillingHubTheme.Surfaces.cardBase)
            .shadow(
                color: isSelected
                    ? card.accentColor.opacity(StyleGuide.Opacity.medium)
                    : StyleGuide.shadowColor.opacity(StyleGuide.Opacity.faint),
                radius: isSelected ? StyleGuide.Shadows.lightRadius + 2 : StyleGuide.Shadows.lightRadius,
                x: 0,
                y: isSelected ? StyleGuide.Shadows.lightOffsetY : 1
            )
            .drawingGroup()
    }
}
