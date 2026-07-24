import SwiftUI
import SharedUI

@ViewBuilder
private func highlightedText(_ text: String, searchingFor query: String) -> some View {
    if !query.isEmpty, let range = text.range(of: query, options: .caseInsensitive) {
        let prefix = text[..<range.lowerBound]
        let match = text[range]
        let suffix = text[range.upperBound...]

        Text(
            "\(Text(String(prefix)))" +
            "\(Text(String(match)).bold().foregroundColor(.accentColor))" +
            "\(Text(String(suffix)))"
        )
    } else {
        Text(text)
    }
}

struct KanbanCardView: View, Equatable {
    nonisolated static func == (lhs: KanbanCardView, rhs: KanbanCardView) -> Bool {
        MainActor.assumeIsolated {
            lhs.card.id == rhs.card.id &&
            lhs.card.titleText == rhs.card.titleText &&
            lhs.card.subtitleText == rhs.card.subtitleText &&
            lhs.card.detailText == rhs.card.detailText &&
            lhs.card.statusText == rhs.card.statusText &&
            lhs.card.accentColor == rhs.card.accentColor &&
            lhs.isSelected == rhs.isSelected &&
            lhs.searchText == rhs.searchText
        }
    }

    let viewModel: BillingHubViewModel
    let card: KanbanCardData
    @Binding var isSelected: Bool
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
                        .foregroundColor(BillingHubTheme.Palette.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)

                    highlightedText(card.subtitleText, searchingFor: searchText)
                        .font(BillingHubTheme.Typography.cardSubtitle)
                        .foregroundColor(BillingHubTheme.Palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .truncationMode(.tail)

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
                        ? Color.accentColor
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

            if let nextColumn = viewModel.nextColumn(for: card) {
                Divider()

                Button {
                    Task {
                        _ = await viewModel.advanceCard(card)
                    }
                } label: {
                    Label("Move to \(nextColumn.menuTitle)", systemImage: "arrow.right.circle")
                }
            }
        }
        .billingHubPointerStyle(.link)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.titleText), \(card.subtitleText), \(card.detailText ?? "No date"), \(card.statusText ?? "")")
        .accessibilityHint("Double click to open details.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Open Details") {
            onTap()
            onOpen?()
        }
    }

    private var metadataLeading: some View {
        HStack(spacing: ListRowTokens.metadataSpacing) {
            Image(systemName: "calendar")
                .font(BillingHubTheme.Typography.cardMetadata)
                .foregroundColor(BillingHubTheme.Palette.textSecondary)
            Text(card.detailText ?? "No date")
                .font(BillingHubTheme.Typography.cardMetadata)
                .foregroundColor(BillingHubTheme.Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .truncationMode(.tail)
        }
    }

    private var metadataTrailing: some View {
        HStack(spacing: ListRowTokens.metadataSpacing) {
            Image(systemName: card.trailingMetadataSymbol)
                .font(BillingHubTheme.Typography.cardMetadata)
                .foregroundColor(BillingHubTheme.Palette.textSecondary)
            Text(card.statusText ?? "No amount")
                .font(BillingHubTheme.Typography.cardMetadata)
                .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .truncationMode(.tail)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.cardCornerRadius, style: .continuous)
            .fill(BillingHubTheme.Surfaces.cardBase)
            .shadow(
                color: isSelected
                    ? Color.accentColor.opacity(StyleGuide.Opacity.medium)
                    : StyleGuide.shadowColor.opacity(StyleGuide.Opacity.faint),
                radius: isSelected ? StyleGuide.Shadows.lightRadius + 2 : StyleGuide.Shadows.lightRadius,
                x: 0,
                y: isSelected ? StyleGuide.Shadows.lightOffsetY : 1
            )
            .drawingGroup()
    }
}
