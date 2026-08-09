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

    var summary: String {
        switch self {
        case .preparing: "Complete sessions, then organise them into client batches."
        case .processing: "Create, review, and approve invoices before they are sent."
        case .payment: "Record payments and keep completed billing easy to find."
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

    static func section(
        containing column: KanbanCardData.BillingColumnType
    ) -> Self? {
        allCases.first { $0.columns.contains(column) }
    }
}

struct BillingHubBoardFocusTarget: Equatable {
    let cardID: UUID
    let sectionID: BillingHubBoardSectionID
    let column: KanbanCardData.BillingColumnType
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
    let emptyStateMessage: String
    let content: BillingHubLaneContent

    var isInvoiceLane: Bool {
        id.isInvoiceLane
    }

    var helpSummary: String {
        if let total {
            return "\(title) · \(itemCountLabel) · \(total)"
        }
        return "\(title) · \(itemCountLabel)"
    }

    var itemCountLabel: String { BillingHubBoardCopy.itemCount(count) }
}

struct BillingHubBoardSectionPresentation: Identifiable {
    let id: BillingHubBoardSectionID
    let lanes: [BillingHubLanePresentation]

    var title: String { id.title }
    var summary: String { id.summary }
    var icon: String { id.icon }
    var tint: Color { id.tint }
    var count: Int { lanes.reduce(into: 0) { $0 += $1.count } }
    var itemCountLabel: String { BillingHubBoardCopy.itemCount(count) }
}

struct KanbanBoardView: View {
    let displayState: KanbanBoardDisplayState
    let actions: KanbanBoardActions
    let cardActions: KanbanCardActions
    let projection: BillingHubBoardProjection
    let boardRevision: Int
    @Binding var selectedCardID: UUID?
    let onOpenCard: (UUID) -> Void
    /// When set, horizontal board scrolls so the matching section/lane for this card is visible.
    var focusScrollID: UUID? = nil
    @State private var interactionState = BillingHubBoardInteractionState()
    @State private var collapsedSections: Set<BillingHubBoardSectionID> = []
    @State private var cachedSectionPresentations: [BillingHubBoardSectionPresentation] = []

    private var sectionPresentationsCacheKey: SectionPresentationsCacheKey {
        SectionPresentationsCacheKey(
            boardRevision: boardRevision,
            displayState: displayState,
            projectionFingerprint: projection.contentFingerprint
        )
    }

    var body: some View {
        ZStack {
            boardBackground.ignoresSafeArea()

            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    BillingHubBoardOverviewBar(
                        sections: sectionPresentations,
                        selectedSectionID: focusedCardTarget?.sectionID
                    ) { sectionID in
                        scrollToSection(sectionID, proxy: proxy)
                    }

                    Divider()

                    ScrollView(.horizontal, showsIndicators: true) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(sectionPresentations) { section in
                                BillingHubDemoSectionContainer(
                                    cardActions: cardActions,
                                    section: section,
                                    isCollapsed: collapseBinding(for: section.id),
                                    selectedCardID: $selectedCardID,
                                    interactionState: interactionState,
                                    onOpenCard: onOpenCard
                                )
                                .id(section.id)
                            }
                        }
                        .padding(BillingHubTheme.Dimensions.boardPadding)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onChange(of: focusedCardTarget) { _, target in
                    scrollToFocusedCard(target, proxy: proxy)
                }
                .onAppear {
                    scrollToFocusedCard(focusedCardTarget, proxy: proxy)
                }
            }
        }
        .billingHubBoardCleanup(interactionState: interactionState)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: sectionPresentationsCacheKey) {
            cachedSectionPresentations = BillingHubBoardSectionID.allCases.map(makeSectionPresentation(for:))
        }
    }

    private var sectionPresentations: [BillingHubBoardSectionPresentation] {
        cachedSectionPresentations.isEmpty
            ? BillingHubBoardSectionID.allCases.map(makeSectionPresentation(for:))
            : cachedSectionPresentations
    }

    private var focusedCardTarget: BillingHubBoardFocusTarget? {
        guard let focusScrollID,
              let card = projection.card(for: focusScrollID),
              let sectionID = BillingHubBoardSectionID.section(
                containing: card.columnType
              ) else { return nil }
        return BillingHubBoardFocusTarget(
            cardID: focusScrollID,
            sectionID: sectionID,
            column: card.columnType
        )
    }

    private func scrollToFocusedCard(
        _ target: BillingHubBoardFocusTarget?,
        proxy: ScrollViewProxy
    ) {
        guard let target else { return }
        scrollToSection(target.sectionID, proxy: proxy)
    }

    private func scrollToSection(
        _ sectionID: BillingHubBoardSectionID,
        proxy: ScrollViewProxy
    ) {
        withAnimation(.easeInOut(duration: 0.25)) {
            collapsedSections.remove(sectionID)
            proxy.scrollTo(sectionID, anchor: .center)
        }
    }

    private struct SectionPresentationsCacheKey: Equatable {
        let boardRevision: Int
        let displayState: KanbanBoardDisplayState
        let projectionFingerprint: Int
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
                total: actions.formattedTotal(column, projection)
            ) { sourceID, beforeTargetID in
                actions.reorderInvoices(
                    column,
                    sourceID,
                    beforeTargetID,
                    projection
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
            searchText: displayState.searchText,
            sortOption: actions.sortOption(column),
            onSortChange: { actions.setSortOption($0, column) },
            total: total,
            emptyStateMessage: BillingHubBoardCopy.emptyLaneMessage(
                for: column,
                hasActiveFilters: displayState.hasActiveFilters
            ),
            content: .cards(
                cards: cards,
                dropPolicy: dropPolicy,
                canAcceptDrop: { dragKind, beforeTargetID in
                    canAcceptCardDrop(dragKind, into: column, before: beforeTargetID)
                },
                onReorderBetween: { sourceID, beforeTargetID, _ in
                    // Validation already accepted this drop. End drag feedback immediately while
                    // persistence completes; the view model reports any eventual write failure.
                    if let card = projection.card(for: sourceID), card.columnType != column {
                        Task {
                            switch card {
                            case .session:
                                _ = await actions.moveSession(sourceID, column)
                            case .invoice:
                                _ = await actions.moveInvoice(sourceID, column)
                            }
                        }
                        return true
                    }
                    return onReorder(sourceID, beforeTargetID)
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
            searchText: displayState.searchText,
            sortOption: nil,
            onSortChange: nil,
            total: nil,
            emptyStateMessage: BillingHubBoardCopy.emptyLaneMessage(
                for: .grouped,
                hasActiveFilters: displayState.hasActiveFilters
            ),
            content: .grouped(
                groups: projection.groupedSessions,
                canReorderSessionInColumn: { sourceID, beforeClusterID in
                    canAcceptSessionDropInGroupedColumn(sourceID: sourceID, beforeClusterID: beforeClusterID)
                },
                onReorderSessionInColumn: { sourceID, _ in
                    // Cross-column move into Grouped. Validation already accepted the drop.
                    Task {
                        _ = await actions.moveSession(sourceID, .grouped)
                    }
                    return true
                },
                canReorderSessionInGroup: { sourceID, beforeTargetID, scopeGroupID in
                    canAcceptSessionDropInGroup(sourceID: sourceID, beforeTargetID: beforeTargetID, scopeGroupID: scopeGroupID)
                },
                onReorderSessionInGroup: { sourceID, _, scopeGroupID in
                    // Adding into a group (not reorder) is handled when canAccept is true for non-members.
                    guard let scopeGroupID else { return false }
                    Task {
                        await actions.addSessionToGroup(sourceID, scopeGroupID)
                    }
                    return true
                },
                canReorderGroup: { _, _ in
                    false
                },
                onReorderGroup: { _, _ in
                    false
                },
                canDropOnCard: { sourceID, targetID in
                    canAcceptSessionGrouping(sourceID: sourceID, targetID: targetID)
                },
                onDropOnCard: { sourceID, targetID in
                    guard canAcceptSessionGrouping(sourceID: sourceID, targetID: targetID) else {
                        return false
                    }
                    Task {
                        await actions.groupSessionsSmooth(sourceID, targetID)
                    }
                    return true
                },
                onAddSessionToGroup: { sessionID, groupID in
                    Task {
                        await actions.addSessionToGroup(sessionID, groupID)
                    }
                },
                canAddSessionToGroup: actions.canAddSessionToGroup
            )
        )
    }

    private func makeSessionReorderHandler(
        for column: KanbanCardData.BillingColumnType
    ) -> (UUID, UUID?) -> Bool {
        // Completed / Add Travel peer reindex not implemented — canAccept rejects same-column drops.
        switch column {
        case .completed, .addTravel, .grouped, .reviewDrafts, .readyToSend, .pending, .received:
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

    private func canAcceptSessionGrouping(sourceID: UUID, targetID: UUID) -> Bool {
        guard sourceID != targetID else { return false }
        guard let sourceCard = sessionCard(for: sourceID), let targetCard = sessionCard(for: targetID) else { return false }
        guard sourceCard.columnType.billingStatus != .grouped, targetCard.columnType.billingStatus != .grouped else { return false }
        guard let sourceClientID = sourceCard.clientID, let targetClientID = targetCard.clientID else { return false }
        return sourceClientID == targetClientID
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
