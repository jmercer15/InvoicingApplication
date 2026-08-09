import SwiftUI
import SharedUI

struct BillingHubBoardOverviewBar: View {
    let sections: [BillingHubBoardSectionPresentation]
    let selectedSectionID: BillingHubBoardSectionID?
    let onSelect: (BillingHubBoardSectionID) -> Void

    var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
            Label("Pipeline", systemImage: "arrow.right.circle")
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                .fixedSize()
                .accessibilityHidden(true)

            ForEach(sections) { section in
                Button {
                    onSelect(section.id)
                } label: {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
                            Image(systemName: section.icon)
                            Text(section.title)
                                .lineLimit(1)
                            Spacer(minLength: StyleGuide.Dimensions.paddingTiny)
                            countBadge(section.count, tint: section.tint)
                        }

                        HStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
                            Image(systemName: section.icon)
                            countBadge(section.count, tint: section.tint)
                        }
                    }
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(
                        selectedSectionID == section.id
                            ? section.tint
                            : BillingHubTheme.Palette.textSecondary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
                    .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                    .background {
                        RoundedRectangle(
                            cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall,
                            style: .continuous
                        )
                        .fill(
                            section.tint.opacity(
                                selectedSectionID == section.id ? 0.14 : 0.05
                            )
                        )
                    }
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall,
                            style: .continuous
                        )
                        .strokeBorder(
                            section.tint.opacity(
                                selectedSectionID == section.id ? 0.34 : 0.10
                            )
                        )
                    }
                }
                .buttonStyle(.plain)
                .billingHubPointerStyle(.link)
                .help("Show \(section.title): \(section.summary)")
                .accessibilityLabel(
                    "\(section.title), \(section.itemCountLabel)"
                )
                .accessibilityHint("Scrolls to this billing stage and expands it.")
            }
        }
        .padding(.horizontal, BillingHubTheme.Dimensions.boardPadding)
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .background(BillingHubTheme.Surfaces.panelBase.opacity(0.72))
        .accessibilityElement(children: .contain)
    }

    private func countBadge(_ count: Int, tint: Color) -> some View {
        Text("\(count)")
            .font(BillingHubTheme.Typography.cardMetadata.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, StyleGuide.Dimensions.paddingXSmall)
            .padding(.vertical, 2)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

struct BillingHubDemoSectionContainer: View {
    let cardActions: KanbanCardActions
    let section: BillingHubBoardSectionPresentation
    @Binding var isCollapsed: Bool
    @Binding var selectedCardID: UUID?
    let interactionState: BillingHubBoardInteractionState
    let onOpenCard: (UUID) -> Void

    var body: some View {
        Group {
            if isCollapsed {
                BillingHubDemoCollapsedSectionBar(
                    title: section.title,
                    icon: section.icon,
                    color: section.tint,
                    count: section.count,
                    isCollapsed: $isCollapsed
                )
            } else {
                VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
                    BillingHubDemoSectionHeader(
                        title: section.title,
                        summary: section.summary,
                        icon: section.icon,
                        color: section.tint,
                        count: section.count,
                        isCollapsed: $isCollapsed
                    )

                    HStack(alignment: .top, spacing: BillingHubTheme.Dimensions.laneSpacing) {
                        ForEach(section.lanes) { lane in
                            BillingHubDemoLaneColumn(
                                cardActions: cardActions,
                                lane: lane,
                                selectedCardID: $selectedCardID,
                                interactionState: interactionState,
                                onOpenCard: onOpenCard
                            )
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

private struct BillingHubDemoSectionHeader: View {
    let title: String
    let summary: String
    let icon: String
    let color: Color
    let count: Int
    @Binding var isCollapsed: Bool

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.columnCornerRadius - 2, style: .continuous)
                .fill(color.opacity(0.14))
                .frame(width: BillingHubTheme.Dimensions.sectionIconSize, height: BillingHubTheme.Dimensions.sectionIconSize)
                .overlay {
                    Image(systemName: icon)
                        .font(BillingHubTheme.Typography.cardTitle)
                        .foregroundStyle(color)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BillingHubTheme.Typography.sectionTitle)
                Text(summary)
                    .font(BillingHubTheme.Typography.sectionCount)
                    .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                    .lineLimit(2)
                Text(BillingHubBoardCopy.itemCount(count))
                    .font(BillingHubTheme.Typography.cardMetadata)
                    .foregroundStyle(color)
            }

            Spacer(minLength: 12)

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    isCollapsed = true
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(BillingHubTheme.Typography.collapseChevron)
                    .foregroundStyle(color)
                    .frame(width: BillingHubTheme.Dimensions.collapseButtonSize, height: BillingHubTheme.Dimensions.collapseButtonSize)
                    .background {
                        Circle()
                            .fill(color.opacity(0.10))
                    }
            }
            .buttonStyle(.plain)
            .billingHubPointerStyle(.link)
            .accessibilityLabel("Collapse \(title) section")
            .accessibilityHint("Hides this section’s billing lanes.")
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingXSmall)
    }
}

private struct BillingHubDemoCollapsedSectionBar: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int
    @Binding var isCollapsed: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                isCollapsed = false
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(BillingHubTheme.Typography.collapsedBarIcon)
                    .foregroundStyle(color)

                Text(title)
                .font(BillingHubTheme.Typography.sectionTitle)
                .foregroundStyle(BillingHubTheme.Palette.textPrimary.opacity(0.85))
                .lineLimit(1)
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text("\(count)")
                    .font(BillingHubTheme.Typography.collapsedBarCount)
                    .foregroundStyle(color)

                Image(systemName: "chevron.right")
                    .font(BillingHubTheme.Typography.collapsedBarChevron)
                    .foregroundStyle(color.opacity(0.9))
            }
            .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
            .frame(width: BillingHubTheme.Dimensions.collapsedBarWidth)
            .frame(maxHeight: .infinity)
            .background(background)
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.collapsedBarCornerRadius, style: .continuous))
        .billingHubPointerStyle(.link)
        .accessibilityLabel("Expand \(title) section, \(BillingHubBoardCopy.itemCount(count))")
        .accessibilityHint("Shows this section’s billing lanes.")
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.collapsedBarCornerRadius, style: .continuous)
            .fill(BillingHubTheme.Surfaces.subcolumnBase.opacity(0.92))
            .overlay {
                RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.collapsedBarCornerRadius, style: .continuous)
                    .stroke(color.opacity(0.20), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 2)
    }
}

private struct BillingHubDemoLaneColumn: View {
    let cardActions: KanbanCardActions
    let lane: BillingHubLanePresentation
    @Binding var selectedCardID: UUID?
    let interactionState: BillingHubBoardInteractionState
    let onOpenCard: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            BillingHubDemoLaneHeader(lane: lane)
                .help(lane.helpSummary)

            laneContent
        }
        .padding(StyleGuide.Dimensions.paddingMedium)
        .frame(width: BillingHubTheme.Dimensions.laneWidth, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(laneBackground)
        .focusSection()
    }

    @ViewBuilder
    private var laneContent: some View {
        switch lane.content {
        case let .cards(cards, dropPolicy, canAcceptDrop, onReorderBetween):
            BillingHubReorderableColumn(
                cardActions: cardActions,
                cards: cards,
                selectedCardID: $selectedCardID,
                interactionState: interactionState,
                dropPolicy: dropPolicy,
                canAcceptDrop: canAcceptDrop,
                onReorderBetween: onReorderBetween,
                onOpenCard: onOpenCard,
                searchText: lane.searchText,
                emptyStateMessage: lane.emptyStateMessage
            )
        case let .grouped(
            groups,
            canReorderSessionInColumn,
            onReorderSessionInColumn,
            canReorderSessionInGroup,
            onReorderSessionInGroup,
            canReorderGroup,
            onReorderGroup,
            canDropOnCard,
            onDropOnCard,
            onAddSessionToGroup,
            canAddSessionToGroup
        ):
            BillingHubGroupedReorderableColumn(
                cardActions: cardActions,
                groups: groups,
                selectedCardID: $selectedCardID,
                interactionState: interactionState,
                canReorderSessionInColumn: canReorderSessionInColumn,
                onReorderSessionInColumn: onReorderSessionInColumn,
                canReorderSessionInGroup: canReorderSessionInGroup,
                onReorderSessionInGroup: onReorderSessionInGroup,
                canReorderGroup: canReorderGroup,
                onReorderGroup: onReorderGroup,
                canDropOnCard: canDropOnCard,
                onDropOnCard: onDropOnCard,
                onAddSessionToGroup: onAddSessionToGroup,
                canAddSessionToGroup: canAddSessionToGroup,
                onOpenCard: onOpenCard,
                searchText: lane.searchText,
                emptyStateMessage: lane.emptyStateMessage
            )
        }
    }

    private var laneBackground: some View {
        RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.columnShellCornerRadius, style: .continuous)
            .fill(BillingHubTheme.Surfaces.subcolumnBase.opacity(0.82))
            .overlay {
                RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.columnShellCornerRadius, style: .continuous)
                    .stroke(BillingHubTheme.Surfaces.subcolumnStroke.opacity(0.85), lineWidth: 1)
            }
    }
}

private struct BillingHubDemoLaneHeader: View {
    let lane: BillingHubLanePresentation

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.laneHeaderCornerRadius, style: .continuous)
                .fill(lane.tint.opacity(0.14))
                .frame(width: BillingHubTheme.Dimensions.laneHeaderIconSize, height: BillingHubTheme.Dimensions.laneHeaderIconSize)
                .overlay {
                    Image(systemName: lane.icon)
                        .font(BillingHubTheme.Typography.laneHeaderIcon)
                        .foregroundStyle(lane.tint)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(lane.title)
                    .font(BillingHubTheme.Typography.sectionTitle)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    Text(lane.itemCountLabel)
                        .font(BillingHubTheme.Typography.cardMetadata.weight(.bold))
                    if let total = lane.total {
                        Text(total)
                            .font(BillingHubTheme.Typography.cardMetadata)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(BillingHubTheme.Palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let sortOption = lane.sortOption, let onSortChange = lane.onSortChange {
                BillingHubLaneSortMenu(
                    tint: lane.tint,
                    sortOption: sortOption,
                    isInvoiceLane: lane.isInvoiceLane,
                    onChange: onSortChange
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BillingHubLaneSortMenu: View {
    let tint: Color
    let sortOption: ColumnSortOption
    let isInvoiceLane: Bool
    let onChange: (ColumnSortOption) -> Void

    var body: some View {
        Menu {
            ForEach(ColumnSortOption.allCases, id: \.self) { option in
                if isOptionVisible(option) {
                    Button {
                        onChange(option)
                    } label: {
                        if option == sortOption {
                            Label(option.displayName, systemImage: "checkmark")
                        } else {
                            Text(option.displayName)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: sortOption == .manual ? "arrow.up.arrow.down" : sortOption.icon)
                .font(BillingHubTheme.Typography.sortMenuIcon)
                .foregroundStyle(sortOption == .manual ? BillingHubTheme.Palette.textSecondary : tint)
                .padding(BillingHubTheme.Dimensions.sortButtonPadding)
                .background {
                    RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.cardCornerRadius, style: .continuous)
                        .fill(sortOption == .manual ? tint.opacity(0.08) : tint.opacity(0.12))
                }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Sort lane. Current: \(sortOption.displayName)")
        .accessibilityLabel("Sort lane")
        .accessibilityValue(sortOption.displayName)
    }

    private func isOptionVisible(_ option: ColumnSortOption) -> Bool {
        isInvoiceLane ? option.applicableToInvoices : option.applicableToSessions
    }
}
