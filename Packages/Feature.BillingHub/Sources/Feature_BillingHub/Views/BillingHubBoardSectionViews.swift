import SwiftUI
import SharedUI

struct BillingHubDemoSectionContainer: View {
    let viewModel: BillingHubViewModel
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
                    count: "\(section.count)",
                    isCollapsed: $isCollapsed
                )
            } else {
                VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
                    BillingHubDemoSectionHeader(
                        title: section.title,
                        icon: section.icon,
                        color: section.tint,
                        count: "\(section.count)",
                        isCollapsed: $isCollapsed
                    )

                    HStack(alignment: .top, spacing: BillingHubTheme.Dimensions.laneSpacing) {
                        ForEach(section.lanes) { lane in
                            BillingHubDemoLaneColumn(
                                viewModel: viewModel,
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
    let icon: String
    let color: Color
    let count: String
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
                Text("\(count) items")
                    .font(BillingHubTheme.Typography.sectionCount)
                    .foregroundStyle(BillingHubTheme.Palette.textSecondary)
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
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingXSmall)
    }
}

private struct BillingHubDemoCollapsedSectionBar: View {
    let title: String
    let icon: String
    let color: Color
    let count: String
    @Binding var isCollapsed: Bool

    var body: some View {
        let characters = Array(title.reversed()).map(String.init)

        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                isCollapsed = false
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(BillingHubTheme.Typography.collapsedBarIcon)
                    .foregroundStyle(color)

                VStack(spacing: -4) {
                    ForEach(Array(characters.enumerated()), id: \.offset) { _, character in
                        Text(character)
                            .rotationEffect(.degrees(-90))
                    }
                }
                .font(BillingHubTheme.Typography.sectionTitle)
                .foregroundStyle(BillingHubTheme.Palette.textPrimary.opacity(0.85))
                .fixedSize(horizontal: true, vertical: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text(count)
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
    let viewModel: BillingHubViewModel
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
    }

    @ViewBuilder
    private var laneContent: some View {
        switch lane.content {
        case let .cards(cards, dropPolicy, canAcceptDrop, onReorderBetween):
            BillingHubReorderableColumn(
                viewModel: viewModel,
                cards: cards,
                selectedCardID: $selectedCardID,
                interactionState: interactionState,
                dropPolicy: dropPolicy,
                canAcceptDrop: canAcceptDrop,
                onReorderBetween: onReorderBetween,
                onOpenCard: onOpenCard,
                searchText: lane.searchText
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
                viewModel: viewModel,
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
                searchText: lane.searchText
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

            Text(lane.title)
                .font(BillingHubTheme.Typography.sectionTitle)
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
        .help("Sort lane")
    }

    private func isOptionVisible(_ option: ColumnSortOption) -> Bool {
        isInvoiceLane ? option.applicableToInvoices : option.applicableToSessions
    }
}
