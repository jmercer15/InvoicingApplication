import SwiftUI
import SharedUI
import Core
import Observation

enum BillingHubBoardSectionID: String, CaseIterable, Identifiable {
    case preparing
    case processing
    case payment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preparing: "Prepare"
        case .processing: "Process"
        case .payment: "Payment"
        }
    }

    var icon: String {
        switch self {
        case .preparing: "calendar.badge.plus"
        case .processing: "document.badge.gearshape.fill"
        case .payment: "dollarsign.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .preparing: BillingHubTheme.Columns.preparing
        case .processing: BillingHubTheme.Columns.processing
        case .payment: BillingHubTheme.Columns.payment
        }
    }

    var columns: [KanbanCardData.BillingColumnType] {
        switch self {
        case .preparing:
            return [.completed, .grouped]
        case .processing:
            return [.addTravel, .reviewDrafts, .readyToSend]
        case .payment:
            return [.pending, .received]
        }
    }
}

enum BillingHubLaneContent {
    case cards(
        cards: [KanbanCardData],
        dropPolicy: BillingHubDropPolicy,
        canAcceptDrop: (BillingHubBoardDragKind, UUID?) -> Bool,
        onReorderBetween: (UUID, UUID?, UUID?) -> Bool
    )
    case grouped(
        groups: [SessionGroup],
        canReorderSessionInColumn: (UUID, UUID?) -> Bool,
        onReorderSessionInColumn: (UUID, UUID?) -> Bool,
        canReorderSessionInGroup: (UUID, UUID?, UUID?) -> Bool,
        onReorderSessionInGroup: (UUID, UUID?, UUID?) -> Bool,
        canReorderGroup: (UUID, UUID?) -> Bool,
        onReorderGroup: (UUID, UUID?) -> Bool,
        canDropOnCard: ((UUID, UUID) -> Bool)?,
        onDropOnCard: ((UUID, UUID) -> Bool)?,
        onAddSessionToGroup: (UUID, UUID) -> Void,
        canAddSessionToGroup: (UUID, UUID) -> Bool
    )
}

struct BillingHubLanePresentation: Identifiable {
    let id: KanbanCardData.BillingColumnType
    let title: String
    let icon: String
    let tint: Color
    let count: Int
    let searchText: String
    let sortOption: ColumnSortOption?
    let onSortChange: ((ColumnSortOption) -> Void)?
    let total: String?
    let content: BillingHubLaneContent

    var isInvoiceLane: Bool {
        id.isInvoiceLane
    }

    var helpSummary: String {
        if let total {
            return "\(title) · \(count) items · \(total)"
        }
        return "\(title) · \(count) items"
    }
}

struct BillingHubBoardSectionPresentation: Identifiable {
    let id: BillingHubBoardSectionID
    let lanes: [BillingHubLanePresentation]

    var title: String { id.title }
    var icon: String { id.icon }
    var tint: Color { id.tint }
    var count: Int { lanes.reduce(into: 0) { $0 += $1.count } }
}

struct KanbanBoardView: View {
    @Bindable var viewModel: BillingHubViewModel
    let projection: BillingHubBoardProjection
    @Binding var selectedCardID: UUID?
    let onOpenCard: (UUID) -> Void
    @State private var interactionState = BillingHubBoardInteractionState()
    @State private var collapsedSections: Set<BillingHubBoardSectionID> = []

    var body: some View {
        ZStack {
            boardBackground.ignoresSafeArea()

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(sectionPresentations) { section in
                        BillingHubDemoSectionContainer(
                            viewModel: viewModel,
                            section: section,
                            isCollapsed: collapseBinding(for: section.id),
                            selectedCardID: $selectedCardID,
                            interactionState: interactionState,
                            onOpenCard: onOpenCard
                        )
                    }
                }
                .padding(BillingHubTheme.Dimensions.boardPadding)
                .frame(maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .billingHubBoardCleanup(interactionState: interactionState)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sectionPresentations: [BillingHubBoardSectionPresentation] {
        BillingHubBoardSectionID.allCases.map(makeSectionPresentation(for:))
    }

    private func collapseBinding(for sectionID: BillingHubBoardSectionID) -> Binding<Bool> {
        Binding(
            get: { collapsedSections.contains(sectionID) },
            set: { isCollapsed in
                if isCollapsed {
                    collapsedSections.insert(sectionID)
                } else {
                    collapsedSections.remove(sectionID)
                }
            }
        )
    }

    private func makeSectionPresentation(for sectionID: BillingHubBoardSectionID) -> BillingHubBoardSectionPresentation {
        BillingHubBoardSectionPresentation(
            id: sectionID,
            lanes: sectionID.columns.map(makeLanePresentation(for:))
        )
    }

    private func makeLanePresentation(for column: KanbanCardData.BillingColumnType) -> BillingHubLanePresentation {
        switch column {
        case .completed:
            return makeCardLane(
                column: column,
                cards: projection.sessionsByStatus[column] ?? [],
                dropPolicy: .sessionsOnly,
                total: nil,
                onReorder: makeSessionReorderHandler(for: column)
            )

        case .grouped:
            return makeGroupedLane()

        case .addTravel:
            return makeCardLane(
                column: column,
                cards: projection.sessionsByStatus[column] ?? [],
                dropPolicy: .sessionsOnly,
                total: nil,
                onReorder: makeSessionReorderHandler(for: column)
            )

        case .reviewDrafts, .readyToSend, .pending, .received:
            return makeCardLane(
                column: column,
                cards: projection.invoicesByStatus[column] ?? [],
                dropPolicy: .invoicesOnly,
                total: viewModel.formattedTotal(for: column, in: projection)
            ) { sourceID, beforeTargetID in
                viewModel.reorderInvoices(
                    in: column,
                    sourceID: sourceID,
                    beforeTargetID: beforeTargetID,
                    projection: projection
                )
                return true
            }
        }
    }

    private func makeCardLane(
        column: KanbanCardData.BillingColumnType,
        cards: [KanbanCardData],
        dropPolicy: BillingHubDropPolicy,
        total: String?,
        onReorder: @escaping (UUID, UUID?) -> Bool
    ) -> BillingHubLanePresentation {
        BillingHubLanePresentation(
            id: column,
            title: column.laneTitle,
            icon: column.laneIcon,
            tint: column.laneTint,
            count: cards.count,
            searchText: viewModel.searchText,
            sortOption: viewModel.sortOption(for: column),
            onSortChange: { viewModel.setSortOption($0, for: column) },
            total: total,
            content: .cards(
                cards: cards,
                dropPolicy: dropPolicy,
                canAcceptDrop: { dragKind, beforeTargetID in
                    canAcceptCardDrop(dragKind, into: column, before: beforeTargetID)
                },
                onReorderBetween: { sourceID, beforeTargetID, _ in
                    onReorder(sourceID, beforeTargetID)
                }
            )
        )
    }

    private func makeGroupedLane() -> BillingHubLanePresentation {
        BillingHubLanePresentation(
            id: .grouped,
            title: KanbanCardData.BillingColumnType.grouped.laneTitle,
            icon: KanbanCardData.BillingColumnType.grouped.laneIcon,
            tint: KanbanCardData.BillingColumnType.grouped.laneTint,
            count: projection.sessionsByStatus[.grouped]?.count ?? 0,
            searchText: viewModel.searchText,
            sortOption: nil,
            onSortChange: nil,
            total: nil,
            content: .grouped(
                groups: projection.groupedSessions,
                canReorderSessionInColumn: { sourceID, beforeClusterID in
                    canAcceptSessionDropInGroupedColumn(sourceID: sourceID, beforeClusterID: beforeClusterID)
                },
                onReorderSessionInColumn: { sourceID, beforeClusterID in
                    viewModel.reorderSessionInGroupedColumn(sourceID: sourceID, beforeClusterID: beforeClusterID)
                    return true
                },
                canReorderSessionInGroup: { sourceID, beforeTargetID, scopeGroupID in
                    canAcceptSessionDropInGroup(sourceID: sourceID, beforeTargetID: beforeTargetID, scopeGroupID: scopeGroupID)
                },
                onReorderSessionInGroup: { sourceID, beforeTargetID, scopeGroupID in
                    viewModel.reorderInGrouped(sourceID: sourceID, beforeTargetID: beforeTargetID, scopeGroupID: scopeGroupID)
                    return true
                },
                canReorderGroup: { groupID, beforeTargetID in
                    canAcceptGroupDropInGroupedColumn(sourceGroupID: groupID, beforeTargetID: beforeTargetID)
                },
                onReorderGroup: { groupID, beforeTargetID in
                    viewModel.reorderGroupInGroupedColumn(sourceGroupID: groupID, beforeTargetID: beforeTargetID)
                    return true
                },
                canDropOnCard: { sourceID, targetID in
                    canAcceptSessionGrouping(sourceID: sourceID, targetID: targetID)
                },
                onDropOnCard: { sourceID, targetID in
                    guard canAcceptSessionGrouping(sourceID: sourceID, targetID: targetID) else {
                        return false
                    }
                    _ = viewModel.groupSessionsSmooth(sourceID: sourceID, targetID: targetID)
                    return true
                },
                onAddSessionToGroup: { sessionID, groupID in
                    _ = viewModel.addSessionToGroup(sessionID: sessionID, groupID: groupID)
                },
                canAddSessionToGroup: { sessionID, groupID in
                    viewModel.canAddSessionToGroup(sourceID: sessionID, groupID: groupID)
                }
            )
        )
    }

    private func makeSessionReorderHandler(
        for column: KanbanCardData.BillingColumnType
    ) -> (UUID, UUID?) -> Bool {
        switch column {
        case .completed:
            return { sourceID, beforeTargetID in
                viewModel.reorderInCompleted(sourceID: sourceID, beforeTargetID: beforeTargetID)
                return true
            }
        case .addTravel:
            return { sourceID, beforeTargetID in
                viewModel.reorderInAddTravel(sourceID: sourceID, beforeTargetID: beforeTargetID)
                return true
            }
        case .grouped, .reviewDrafts, .readyToSend, .pending, .received:
            return { _, _ in false }
        }
    }

    private var coordinator: BillingHubDragDropCoordinator {
        BillingHubDragDropCoordinator(projection: projection)
    }

    private func canAcceptCardDrop(
        _ dragKind: BillingHubBoardDragKind,
        into column: KanbanCardData.BillingColumnType,
        before targetID: UUID?
    ) -> Bool {
        coordinator.canAcceptCardDrop(dragKind, into: column, before: targetID)
    }

    private func canAcceptSessionDropInGroupedColumn(sourceID: UUID, beforeClusterID: UUID?) -> Bool {
        coordinator.canAcceptSessionDropInGroupedColumn(sourceID: sourceID, beforeClusterID: beforeClusterID)
    }

    private func canAcceptSessionDropInGroup(
        sourceID: UUID,
        beforeTargetID: UUID?,
        scopeGroupID: UUID?
    ) -> Bool {
        coordinator.canAcceptSessionDropInGroup(sourceID: sourceID, beforeTargetID: beforeTargetID, scopeGroupID: scopeGroupID)
    }

    private func canAcceptGroupDropInGroupedColumn(sourceGroupID: UUID, beforeTargetID _: UUID?) -> Bool {
        // Coordinator doesn't have this yet, let's keep it here or add it.
        // For now, simple implementation:
        projection.groupedSessions.contains(where: { $0.groupID == sourceGroupID })
    }

    private func canAcceptSessionGrouping(sourceID: UUID, targetID: UUID) -> Bool {
        guard sourceID != targetID else { return false }
        guard let sourceCard = sessionCard(for: sourceID), let targetCard = sessionCard(for: targetID) else { return false }
        // We'll delegate client matching to the coordinator if possible, 
        // but for now we have the logic in the coordinator's canAcceptSessionDropInGroup or similar.
        // Let's just use the basic rule here.
        return sourceCard.columnType.billingStatus != .grouped && targetCard.columnType.billingStatus != .grouped
    }

    private func sessionCard(for id: UUID) -> SessionKanbanCardData? {
        guard case .session(let data) = projection.card(for: id) else { return nil }
        return data
    }

    /// Static window-spanning gradient. The previous decorative variant
    /// composited three large `RoundedRectangle.blur(radius: 90/100/110)`
    /// layers on top of the gradient, which forced an off-screen blur pass on
    /// every scroll/resize tick. Replaced with a flat gradient — same surface
    /// tokens, no per-frame blur cost.
    private var boardBackground: some View {
        LinearGradient(
            colors: [
                BillingHubTheme.Surfaces.boardBase,
                BillingHubTheme.Surfaces.subcolumnBase.opacity(0.96),
                BillingHubTheme.Surfaces.boardUnderpage,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
