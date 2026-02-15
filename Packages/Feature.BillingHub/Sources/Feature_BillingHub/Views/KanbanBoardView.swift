import SwiftUI
import SharedUI
import Core

private extension View {
    func kanbanSubcolumnSurface() -> some View {
        let shape = RoundedRectangle(
            cornerRadius: BillingHubTheme.Surfaces.subcolumnCornerRadius,
            style: .continuous
        )

        return self
            .glassEffect(.regular, in: shape)
            .clipShape(shape)
    }
}

struct KanbanBoardView: View {
    @ObservedObject var viewModel: BillingHubViewModel
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    @State private var preparingCollapsed: Bool = false
    @State private var processingCollapsed: Bool = false
    @State private var paymentCollapsed: Bool = false

    var body: some View {
        let completedSessionsCount = viewModel.sessionsByStatus[.completed]?.count ?? 0
        let groupedSessionsCount = viewModel.sessionsByStatus[.grouped]?.count ?? 0
        let addTravelSessionsCount = viewModel.sessionsByStatus[.addTravel]?.count ?? 0
        let reviewDraftsInvoicesCount = viewModel.invoicesByStatus[.reviewDrafts]?.count ?? 0
        let readyToSendInvoicesCount = viewModel.invoicesByStatus[.readyToSend]?.count ?? 0
        let pendingInvoicesCount = viewModel.invoicesByStatus[.pending]?.count ?? 0
        let receivedInvoicesCount = viewModel.invoicesByStatus[.received]?.count ?? 0

        return GeometryReader { geometry in
            let viewportWidth = geometry.size.width
            let collapsedWidth: CGFloat = 60
            let primaryColumnGap = BillingHubTheme.Surfaces.primaryColumnGap
            let sectionGapTotal = primaryColumnGap * 2

            let minimumLeftWidth: CGFloat = 320
            let minimumMiddleWidth: CGFloat = 480
            let minimumRightWidth: CGFloat = 320
            let minimumBoardWidth =
                (preparingCollapsed ? collapsedWidth : minimumLeftWidth) +
                (processingCollapsed ? collapsedWidth : minimumMiddleWidth) +
                (paymentCollapsed ? collapsedWidth : minimumRightWidth) +
                sectionGapTotal

            let totalWidth = max(viewportWidth, minimumBoardWidth)

            let leftWeight: CGFloat = 2
            let middleWeight: CGFloat = 3
            let rightWeight: CGFloat = 2

            let collapsedCount = [preparingCollapsed, processingCollapsed, paymentCollapsed].filter { $0 }.count
            let reservedForCollapsed = CGFloat(collapsedCount) * collapsedWidth
            let available = max(0, totalWidth - reservedForCollapsed - sectionGapTotal)

            let activeWeight = (preparingCollapsed ? 0 : leftWeight) + (processingCollapsed ? 0 : middleWeight) + (paymentCollapsed ? 0 : rightWeight)

            let leftWidth: CGFloat = preparingCollapsed ? collapsedWidth : (activeWeight > 0 ? available * (leftWeight / activeWeight) : collapsedWidth)
            let middleWidth: CGFloat = processingCollapsed ? collapsedWidth : (activeWeight > 0 ? available * (middleWeight / activeWeight) : collapsedWidth)
            let rightWidth: CGFloat = paymentCollapsed ? collapsedWidth : (activeWeight > 0 ? available * (rightWeight / activeWeight) : collapsedWidth)

            ScrollView(.horizontal, showsIndicators: totalWidth > viewportWidth) {
                Grid(alignment: .top, horizontalSpacing: primaryColumnGap, verticalSpacing: 0) {
                    GridRow {
                        PreparingSessionsColumn(
                            viewModel: viewModel,
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            completedSessionsCount: completedSessionsCount,
                            groupedSessionsCount: groupedSessionsCount,
                            width: leftWidth,
                            isCollapsed: $preparingCollapsed
                        )

                        ProcessingColumn(
                            viewModel: viewModel,
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            addTravelSessionsCount: addTravelSessionsCount,
                            reviewDraftsInvoicesCount: reviewDraftsInvoicesCount,
                            readyToSendInvoicesCount: readyToSendInvoicesCount,
                            width: middleWidth,
                            isCollapsed: $processingCollapsed
                        )

                        PaymentColumn(
                            viewModel: viewModel,
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            pendingInvoicesCount: pendingInvoicesCount,
                            receivedInvoicesCount: receivedInvoicesCount,
                            width: rightWidth,
                            isCollapsed: $paymentCollapsed
                        )
                    }
                }
                .frame(width: totalWidth, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CollapsedColumnBar: View {
    var title: String
    var icon: String
    var color: Color
    var count: String? = nil
    @Binding var isCollapsed: Bool
    @State private var isHovered: Bool = false

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: BillingHubTheme.Surfaces.subcolumnCornerRadius,
            style: .continuous
        )
        let reversedCharacters = Array(title.reversed()).map(String.init)

        return VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)

                VStack(spacing: -4) {
                    ForEach(Array(reversedCharacters.enumerated()), id: \.offset) { _, character in
                        Text(character)
                            .rotationEffect(.degrees(-90))
                    }
                }
                    .font(.title3.weight(.semibold))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.85))
                    .fixedSize(horizontal: true, vertical: true)
                    .layoutPriority(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let count {
                    Text(count)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color.opacity(0.9))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    isCollapsed = false
                }
            }
        .glassEffect(.regular.tint(color.opacity(0.45)).interactive(isHovered), in: shape)
        .clipShape(shape)
        .pointerStyle(.link)
#if os(macOS)
        .help("Expand \(title)")
#endif
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
    }
}

struct PreparingSessionsColumn: View {
    @ObservedObject var viewModel: BillingHubViewModel
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let completedSessionsCount: Int
    let groupedSessionsCount: Int
    let width: CGFloat
    @Binding var isCollapsed: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isCollapsed {
                CollapsedColumnBar(
                    title: "Prepare",
                    icon: "calendar.badge.plus",
                    color: BillingHubTheme.Columns.preparing,
                    count: "\(completedSessionsCount + groupedSessionsCount)",
                    isCollapsed: $isCollapsed
                )
            } else {
                VStack(spacing: 0) {
                    KanbanSectionHeader(
                        title: "Prepare",
                        icon: "calendar.badge.plus",
                        color: BillingHubTheme.Columns.preparing,
                        count: "\(completedSessionsCount + groupedSessionsCount)",
                        isCollapsed: $isCollapsed
                    )
                    Grid(alignment: .top, horizontalSpacing: BillingHubTheme.Surfaces.subcolumnGap, verticalSpacing: 0) {
                GridRow {
                    // Completed
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Completed",
                            icon: "calendar.badge.checkmark",
                            color: BillingHubTheme.Columns.preparing,
                            count: "\(completedSessionsCount)",
                            sortOption: viewModel.sortOption(for: .completed),
                            onSortChange: { viewModel.setSortOption($0, for: .completed) }
                        )

                        CustomKanbanColumn(
                            cards: viewModel.sessionsByStatus[.completed] ?? [],
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            columnType: .completed,
                            onReorderBetween: { sourceID, beforeTargetID, _ in
                                return viewModel.reorderInCompleted(sourceID: sourceID, beforeTargetID: beforeTargetID)
                            },
                            dropPolicy: .sessionsOnly,
                            emptyStateIcon: "checkmark.circle",
                            emptyStateMessage: "All sessions processed",
                            searchText: viewModel.searchText
                        )
                    }
                    .kanbanSubcolumnSurface()

                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Grouped",
                            icon: "rectangle.on.rectangle.badge.gearshape",
                            color: BillingHubTheme.Columns.preparing,
                            count: "\(groupedSessionsCount)"
                            // Grouped column is strictly manual sort based on groupedPosition
                        )

                        GroupedKanbanColumn(
                            groups: viewModel.groupedSessions,
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            onReorderBetween: { sourceID, beforeTargetID, scopeGroupID in
                                return viewModel.reorderInGrouped(sourceID: sourceID, beforeTargetID: beforeTargetID, scopeGroupID: scopeGroupID)
                            },
                            onReorderGroup: { groupID, beforeTargetID in
                                return viewModel.reorderGroupInGroupedColumn(sourceGroupID: groupID, beforeTargetID: beforeTargetID)
                            },
                            onDropOnCard: { sourceID, targetID in
                                guard sourceID != targetID,
                                      viewModel.fetchSession(byID: sourceID) != nil,
                                      viewModel.fetchSession(byID: targetID) != nil else { return false }
                                _ = viewModel.groupSessionsSmooth(sourceID: sourceID, targetID: targetID)
                                return true
                            },
                            onAddSessionToGroup: { sessionID, groupID in
                                _ = viewModel.addSessionToGroup(sessionID: sessionID, groupID: groupID)
                            },
                            canAddSessionToGroup: { sessionID, groupID in
                                return viewModel.canAddSessionToGroup(sessionID: sessionID, groupID: groupID)
                            },
                            searchText: viewModel.searchText
                        )
                    }
                    .kanbanSubcolumnSurface()
                }
                    }
                    .padding(.horizontal, BillingHubTheme.Surfaces.subcolumnShadowClearance)
                }
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
    }
}

private struct ProcessingColumn: View {
    @ObservedObject var viewModel: BillingHubViewModel
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let addTravelSessionsCount: Int
    let reviewDraftsInvoicesCount: Int
    let readyToSendInvoicesCount: Int
    let width: CGFloat
    @Binding var isCollapsed: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isCollapsed {
                CollapsedColumnBar(
                    title: "Process",
                    icon: "document.badge.gearshape.fill",
                    color: BillingHubTheme.Columns.processing,
                    count: "\(addTravelSessionsCount + reviewDraftsInvoicesCount + readyToSendInvoicesCount)",
                    isCollapsed: $isCollapsed
                )
            } else {
                VStack(spacing: 0) {
                    KanbanSectionHeader(
                        title: "Process",
                        icon: "document.badge.gearshape.fill",
                        color: BillingHubTheme.Columns.processing,
                        count: "\(addTravelSessionsCount + reviewDraftsInvoicesCount + readyToSendInvoicesCount)",
                        isCollapsed: $isCollapsed
                    )

                    Grid(alignment: .top, horizontalSpacing: BillingHubTheme.Surfaces.subcolumnGap, verticalSpacing: 0) {
                GridRow {
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Add Travel",
                            icon: "car",
                            color: BillingHubTheme.Columns.processing,
                            count: "\(addTravelSessionsCount)",
                            sortOption: viewModel.sortOption(for: .addTravel),
                            onSortChange: { viewModel.setSortOption($0, for: .addTravel) }
                        )

                        CustomKanbanColumn(
                            cards: viewModel.sessionsByStatus[.addTravel] ?? [],
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            columnType: .addTravel,
                            onReorderBetween: { sourceID, beforeTargetID, _ in
                                return viewModel.reorderInAddTravel(sourceID: sourceID, beforeTargetID: beforeTargetID, scopeGroupID: nil)
                            },
                            dropPolicy: .sessionsOnly,
                            emptyStateIcon: "car.circle",
                            emptyStateMessage: "No travel needed",
                            searchText: viewModel.searchText
                        )
                    }
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .kanbanSubcolumnSurface()

                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Review Drafts",
                            icon: "doc.text.magnifyingglass",
                            color: BillingHubTheme.Columns.processing,
                            count: "\(reviewDraftsInvoicesCount)",
                            total: viewModel.formattedTotal(for: .reviewDrafts),
                            sortOption: viewModel.sortOption(for: .reviewDrafts),
                            onSortChange: { viewModel.setSortOption($0, for: .reviewDrafts) }
                        )

                        CustomKanbanColumn(
                            cards: viewModel.invoicesByStatus[.reviewDrafts] ?? [],
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            columnType: .reviewDrafts,
                            onReorderBetween: { sourceID, beforeTargetID, _ in
                                viewModel.reorderInvoices(in: .reviewDrafts, sourceID: sourceID, beforeTargetID: beforeTargetID)
                            },
                            dropPolicy: .invoicesOnly,
                            emptyStateIcon: "doc.text",
                            emptyStateMessage: "No drafts to review",
                            searchText: viewModel.searchText
                        )
                    }
                    .kanbanSubcolumnSurface()

                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Ready to Send",
                            icon: "square.and.arrow.up.badge.clock",
                            color: BillingHubTheme.Columns.processing,
                            count: "\(readyToSendInvoicesCount)",
                            total: viewModel.formattedTotal(for: .readyToSend),
                            sortOption: viewModel.sortOption(for: .readyToSend),
                            onSortChange: { viewModel.setSortOption($0, for: .readyToSend) }
                        )

                        CustomKanbanColumn(
                            cards: viewModel.invoicesByStatus[.readyToSend] ?? [],
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            columnType: .readyToSend,
                            onReorderBetween: { sourceID, beforeTargetID, _ in
                                viewModel.reorderInvoices(in: .readyToSend, sourceID: sourceID, beforeTargetID: beforeTargetID)
                            },
                            dropPolicy: .invoicesOnly,
                            emptyStateIcon: "paperplane",
                            emptyStateMessage: "All invoices sent!",
                            searchText: viewModel.searchText
                        )
                    }
                    .kanbanSubcolumnSurface()
                }
                    }
                    .padding(.horizontal, BillingHubTheme.Surfaces.subcolumnShadowClearance)
                }
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
    }
}

private struct PaymentColumn: View {
    @ObservedObject var viewModel: BillingHubViewModel
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let pendingInvoicesCount: Int
    let receivedInvoicesCount: Int
    let width: CGFloat
    @Binding var isCollapsed: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isCollapsed {
                CollapsedColumnBar(
                    title: "Payment",
                    icon: "dollarsign.circle.fill",
                    color: BillingHubTheme.Columns.payment,
                    count: "\(pendingInvoicesCount + receivedInvoicesCount)",
                    isCollapsed: $isCollapsed
                )
            } else {
                VStack(spacing: 0) {
                    KanbanSectionHeader(
                        title: "Payment",
                        icon: "dollarsign.circle.fill",
                        color: BillingHubTheme.Columns.payment,
                        count: "\(pendingInvoicesCount + receivedInvoicesCount)",
                        isCollapsed: $isCollapsed
                    )

                    Grid(alignment: .top, horizontalSpacing: BillingHubTheme.Surfaces.subcolumnGap, verticalSpacing: 0) {
                GridRow {
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Sent",
                            icon: "paperplane",
                            color: BillingHubTheme.Columns.payment,
                            count: "\(pendingInvoicesCount)",
                            total: viewModel.formattedTotal(for: .pending),
                            sortOption: viewModel.sortOption(for: .pending),
                            onSortChange: { viewModel.setSortOption($0, for: .pending) }
                        )

                        CustomKanbanColumn(
                            cards: viewModel.invoicesByStatus[.pending] ?? [],
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            columnType: .pending,
                            onReorderBetween: { sourceID, beforeTargetID, _ in
                                viewModel.reorderInvoices(in: .pending, sourceID: sourceID, beforeTargetID: beforeTargetID)
                            },
                            dropPolicy: .invoicesOnly,
                            emptyStateIcon: "clock",
                            emptyStateMessage: "No pending payments",
                            searchText: viewModel.searchText
                        )

                    }
                    .kanbanSubcolumnSurface()

                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Completed",
                            icon: "checkmark.seal",
                            color: BillingHubTheme.Columns.payment,
                            count: "\(receivedInvoicesCount)",
                            total: viewModel.formattedTotal(for: .received),
                            sortOption: viewModel.sortOption(for: .received),
                            onSortChange: { viewModel.setSortOption($0, for: .received) }
                        )
                        CustomKanbanColumn(
                            cards: viewModel.invoicesByStatus[.received] ?? [],
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            columnType: .received,
                            onReorderBetween: { sourceID, beforeTargetID, _ in
                                viewModel.reorderInvoices(in: .received, sourceID: sourceID, beforeTargetID: beforeTargetID)
                            },
                            dropPolicy: .invoicesOnly,
                            emptyStateIcon: "dollarsign.circle",
                            emptyStateMessage: "Start invoicing!",
                            searchText: viewModel.searchText
                        )
                    }
                    .kanbanSubcolumnSurface()
                }
                    }
                    .padding(.horizontal, BillingHubTheme.Surfaces.subcolumnShadowClearance)
                }
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
    }
}
