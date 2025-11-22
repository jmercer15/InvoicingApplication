//
//  KanbanBoardView.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import SwiftUI
import SwiftData
import SharedUI
import Core


struct KanbanBoardView: View {
    @ObservedObject var viewModel: BillingHubViewModel
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    // Collapsible sections
    @State private var preparingCollapsed: Bool = false
    @State private var processingCollapsed: Bool = false
    @State private var paymentCollapsed: Bool = false

    var body: some View {
        // Precompute lightweight counts to keep body simple
        let completedSessionsCount = viewModel.sessionsByStatus[.completed]?.count ?? 0
        let groupedSessionsCount = viewModel.sessionsByStatus[.grouped]?.count ?? 0
        let addTravelSessionsCount = viewModel.sessionsByStatus[.addTravel]?.count ?? 0
        let reviewDraftsInvoicesCount = viewModel.invoicesByStatus[.reviewDrafts]?.count ?? 0
        let readyToSendInvoicesCount = viewModel.invoicesByStatus[.readyToSend]?.count ?? 0
        let pendingInvoicesCount = viewModel.invoicesByStatus[.pending]?.count ?? 0
        let receivedInvoicesCount = viewModel.invoicesByStatus[.received]?.count ?? 0

        return GeometryReader { _ in
            VStack(spacing: 0) {
                GeometryReader { columnsGeometry in
                    let totalWidth = columnsGeometry.size.width
                    let collapsedWidth: CGFloat = 60

                    // Weights reflect updated proportions after removing Assign Services column
                    // Left: 2 columns, Middle: 3 columns, Right: 2 columns
                    let leftWeight: CGFloat = 2
                    let middleWeight: CGFloat = 3
                    let rightWeight: CGFloat = 2

                    let collapsedCount = [preparingCollapsed, processingCollapsed, paymentCollapsed].filter { $0 }.count
                    let reservedForCollapsed = CGFloat(collapsedCount) * collapsedWidth
                    let available = max(0, totalWidth - reservedForCollapsed)

                    let activeWeight = (preparingCollapsed ? 0 : leftWeight) + (processingCollapsed ? 0 : middleWeight) + (paymentCollapsed ? 0 : rightWeight)

                    let leftWidth: CGFloat = preparingCollapsed ? collapsedWidth : (activeWeight > 0 ? available * (leftWeight / activeWeight) : collapsedWidth)
                    let middleWidth: CGFloat = processingCollapsed ? collapsedWidth : (activeWeight > 0 ? available * (middleWeight / activeWeight) : collapsedWidth)
                    let rightWidth: CGFloat = paymentCollapsed ? collapsedWidth : (activeWeight > 0 ? available * (rightWeight / activeWeight) : collapsedWidth)

                    Grid(alignment: .top, horizontalSpacing: 0, verticalSpacing: 0) {
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
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            }
            .background(.clear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
        .overlay(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
                .stroke(StyleGuide.Colors.border.opacity(0.6), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium))
        .padding(.top)
        .padding(.horizontal)
    }
}

// Preview helpers moved to KanbanBoardView+Preview.swift to isolate Data import



// Narrow vertical bar shown when a primary column is collapsed
private struct CollapsedColumnBar: View {
    var title: String
    var icon: String
    var color: Color
    var count: String? = nil
    @Binding var isCollapsed: Bool
    @State private var isHovered: Bool = false
    // Simple collapsed placeholder bar layout

    var body: some View {
        
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)

                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.85))
                    .lineLimit(1)
                    //.fixedSize() // prevent compression that shrinks font size
                    .rotationEffect(.degrees(-90))
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
            .contentShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium))
            .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium))
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    isCollapsed = false
                }
            }
        .background(color.opacity(isHovered ? 0.32 : 0.24))
        .pointerStyle(.pointingHand)
#if os(macOS)
        .help("Expand \(title)")
#endif
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
    }
}

// (VerticalText removed; using rotated Text(title) instead)

// MARK: - Extracted Columns for Simpler Type-Checking

struct PreparingSessionsColumn: View {
    @ObservedObject var viewModel: BillingHubViewModel
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let completedSessionsCount: Int
    let groupedSessionsCount: Int
    let width: CGFloat
    @Binding var isCollapsed: Bool

    init(
        viewModel: BillingHubViewModel,
        selectedCard: Binding<KanbanCardData?>,
        isEditingPanelVisible: Binding<Bool>,
        completedSessionsCount: Int,
        groupedSessionsCount: Int,
        width: CGFloat,
        isCollapsed: Binding<Bool>
    ) {
        self.viewModel = viewModel
        self._selectedCard = selectedCard
        self._isEditingPanelVisible = isEditingPanelVisible
        self.completedSessionsCount = completedSessionsCount
        self.groupedSessionsCount = groupedSessionsCount
        self.width = width
        self._isCollapsed = isCollapsed
    }

    var body: some View {
        Group {
            if isCollapsed {
                CollapsedColumnBar(
                    title: "Preparing",
                    icon: "calendar.badge.plus",
                    color: Color(hex: "5856D6"),
                    count: "\(completedSessionsCount + groupedSessionsCount)",
                    isCollapsed: $isCollapsed
                )
            } else {
                VStack(spacing: 0) {
                    KanbanSectionHeader(
                        title: "Preparing Sessions",
                        icon: "calendar.badge.plus",
                        color: Color(hex: "5856D6"),
                        count: "\(completedSessionsCount + groupedSessionsCount)",
                        isCollapsed: $isCollapsed
                    )
                    Grid(alignment: .top, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    // Completed
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Completed",
                            icon: "calendar.badge.checkmark",
                            color: Color(hex: "5856D6"),
                            count: "\(completedSessionsCount)"
                        )

                        CustomKanbanColumn(
                            cards: viewModel.sessionsByStatus[.completed] ?? [],
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            columnType: .completed,
                            onReorderBetween: { sourceID, beforeTargetID, _ in
                                return viewModel.reorderInCompleted(sourceID: sourceID, beforeTargetID: beforeTargetID)
                            },
                            betweenAccentColor: Color(hex: "5856D6")
                        )
                        .background(Color.black.opacity(0.04))
                    }
                    .overlay(
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(StyleGuide.Colors.border),
                        alignment: .trailing
                    )

                    // Grouped
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Grouped",
                            icon: "rectangle.on.rectangle.badge.gearshape",
                            color: Color(hex: "5856D6"),
                            count: "\(groupedSessionsCount)"
                        )

                        GroupedKanbanColumn(
                            groups: viewModel.groupedSessions,
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            columnType: .grouped,
                            onReorderBetween: { sourceID, beforeTargetID, scopeGroupID in
                                return viewModel.reorderInGrouped(sourceID: sourceID, beforeTargetID: beforeTargetID, scopeGroupID: scopeGroupID)
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
                            betweenAccentColor: Color(hex: "5856D6")
                        )
                        .background(Color.black.opacity(0.04))
                    }
                }
                    }
                }
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(StyleGuide.Colors.border),
            alignment: .trailing
        )
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
        Group {
            if isCollapsed {
                CollapsedColumnBar(
                    title: "Processing",
                    icon: "document.badge.gearshape.fill",
                    color: Color(hex: "007AFF"),
                    count: "\(addTravelSessionsCount + reviewDraftsInvoicesCount + readyToSendInvoicesCount)",
                    isCollapsed: $isCollapsed
                )
            } else {
                VStack(spacing: 0) {
                    KanbanSectionHeader(
                        title: "Processing",
                        icon: "document.badge.gearshape.fill",
                        color: Color(hex: "007AFF"),
                        count: "\(addTravelSessionsCount + reviewDraftsInvoicesCount + readyToSendInvoicesCount)",
                        isCollapsed: $isCollapsed
                    )

                    Grid(alignment: .top, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    // Add Travel

                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Add Travel",
                            icon: "car",
                            color: Color(hex: "007AFF"),
                            count: "\(addTravelSessionsCount)"
                        )

                        CustomKanbanColumn(
                            cards: viewModel.sessionsByStatus[.addTravel] ?? [],
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            columnType: .addTravel,
                            onReorderBetween: { sourceID, beforeTargetID, _ in
                                return viewModel.reorderInAddTravel(sourceID: sourceID, beforeTargetID: beforeTargetID, scopeGroupID: nil)
                            },
                            betweenAccentColor: Color(hex: "007AFF")
                        )
                        .background(Color.black.opacity(0.04))
                    }
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .overlay(
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(StyleGuide.Colors.border),
                        alignment: .trailing
                    )

                    // Review Drafts
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Review Drafts",
                            icon: "doc.text.magnifyingglass",
                            color: Color(hex: "007AFF"),
                            count: "\(reviewDraftsInvoicesCount)"
                        )

                        CustomKanbanColumn(
                            cards: viewModel.invoicesByStatus[.reviewDrafts] ?? [],
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            columnType: .reviewDrafts,
                            onReorderBetween: { sourceID, beforeTargetID, _ in
                                viewModel.reorderInvoices(in: .reviewDrafts, sourceID: sourceID, beforeTargetID: beforeTargetID)
                            },
                            betweenAccentColor: Color(hex: "007AFF")
                        )
                        .background(Color.black.opacity(0.04))
                    }
                    .overlay(
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(StyleGuide.Colors.border),
                        alignment: .trailing
                    )

                    // Ready to Send
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Ready to Send",
                            icon: "square.and.arrow.up.badge.clock",
                            color: Color(hex: "007AFF"),
                            count: "\(readyToSendInvoicesCount)"
                        )

                        CustomKanbanColumn(
                            cards: viewModel.invoicesByStatus[.readyToSend] ?? [],
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            columnType: .readyToSend,
                            onReorderBetween: { sourceID, beforeTargetID, _ in
                                viewModel.reorderInvoices(in: .readyToSend, sourceID: sourceID, beforeTargetID: beforeTargetID)
                            },
                            betweenAccentColor: Color(hex: "007AFF")
                        )
                        .background(Color.black.opacity(0.04))
                    }
                }
                    }
                }
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(StyleGuide.Colors.border),
            alignment: .trailing
        )
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
        Group {
            if isCollapsed {
                CollapsedColumnBar(
                    title: "Payment",
                    icon: "dollarsign.circle.fill",
                    color: Color(hex: "00FF88"),
                    count: "\(pendingInvoicesCount + receivedInvoicesCount)",
                    isCollapsed: $isCollapsed
                )
            } else {
                VStack(spacing: 0) {
                    KanbanSectionHeader(
                        title: "Payment",
                        icon: "dollarsign.circle.fill",
                        color: Color(hex: "00FF88"),
                        count: "\(pendingInvoicesCount + receivedInvoicesCount)",
                        isCollapsed: $isCollapsed
                    )

                    Grid(alignment: .top, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                    // Pending
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Pending",
                            icon: "clock",
                            color: Color(hex: "00FF88"),
                            count: "\(pendingInvoicesCount)"
                        )

                        CustomKanbanColumn(
                            cards: viewModel.invoicesByStatus[.pending] ?? [],
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            columnType: .pending,
                            onReorderBetween: { sourceID, beforeTargetID, _ in
                                viewModel.reorderInvoices(in: .pending, sourceID: sourceID, beforeTargetID: beforeTargetID)
                            },
                            betweenAccentColor: Color(hex: "00FF88")
                        )
                        .background(Color.black.opacity(0.04))

                    }
                    .overlay(
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(StyleGuide.Colors.border),
                        alignment: .trailing
                    )

                    // Received
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Received",
                            icon: "checkmark.circle",
                            color: Color(hex: "00FF88"),
                            count: "\(receivedInvoicesCount)"
                        )
                        CustomKanbanColumn(
                            cards: viewModel.invoicesByStatus[.received] ?? [],
                            selectedCard: $selectedCard,
                            isEditingPanelVisible: $isEditingPanelVisible,
                            columnType: .received,
                            onReorderBetween: { sourceID, beforeTargetID, _ in
                                viewModel.reorderInvoices(in: .received, sourceID: sourceID, beforeTargetID: beforeTargetID)
                            },
                            betweenAccentColor: Color(hex: "00FF88")
                        )
                        .background(Color.black.opacity(0.04))
                    }
                }
                    }
                }
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}
