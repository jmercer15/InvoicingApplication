import SwiftUI
import SharedUI

struct BillingHubReorderableColumn: View {
    let cardActions: KanbanCardActions
    let cards: [KanbanCardData]
    @Binding var selectedCardID: UUID?
    let interactionState: BillingHubBoardInteractionState
    let dropPolicy: BillingHubDropPolicy
    let canAcceptDrop: (BillingHubBoardDragKind, UUID?) -> Bool
    let onReorderBetween: (UUID, UUID?, UUID?) -> Bool
    let onOpenCard: (UUID) -> Void
    let searchText: String
    let emptyStateMessage: String

    @State private var targetedCardID: UUID?
    @State private var isTopTargeted = false
    @State private var isBottomTargeted = false

    private var isListDropActive: Bool {
        guard let dragKind = interactionState.activeDragKind else { return false }
        if acceptsItem(dragKind, before: nil) {
            return true
        }
        return cards.contains { acceptsItem(dragKind, before: $0.id) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                BillingHubCardInsertionSeparator(
                    isHighlighted: canAcceptTopDrop && isTopTargeted,
                    isVisible: isListDropActive && !cards.isEmpty
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .billingHubDropHandler(
                    targeted: $isTopTargeted,
                    interactionState: interactionState,
                    accepts: { acceptsItem($0, before: cards.first?.id) }
                ) { handleTopDrop($0) }
                .onChange(of: isTopTargeted) { _, targeted in
                    withAnimation(BillingHubBoardMotion.quick) {
                        if canAcceptTopDrop, targeted {
                            targetedCardID = cards.first?.id
                        } else if targetedCardID == cards.first?.id {
                            targetedCardID = nil
                        }
                    }
                }

                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    BillingHubCardItemWrapper(
                        cardActions: cardActions,
                        card: card,
                        targetedCardID: $targetedCardID,
                        interactionState: interactionState,
                        showsInsertionUI: isListDropActive,
                        showsInsertionSeparator: index < cards.count - 1,
                        shouldHighlightSeparator: shouldHighlightSeparator(for: index),
                        acceptsDrop: acceptsItem(_:before:),
                        onDrop: handleCardDrop,
                        selectedCardID: $selectedCardID,
                        onOpenCard: onOpenCard,
                        searchText: searchText
                    )
                    .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                    .padding(.vertical, StyleGuide.Dimensions.paddingTiny)
                }

                BillingHubBottomDropZone(
                    isTargeted: canAcceptBottomDrop && targetedCardID == nil && isBottomTargeted,
                    isEmpty: cards.isEmpty,
                    isVisible: isListDropActive || cards.isEmpty,
                    emptyLabel: emptyStateMessage,
                    targetedLabel: "Move to end"
                )
                .billingHubDropHandler(
                    targeted: $isBottomTargeted,
                    interactionState: interactionState,
                    accepts: { acceptsItem($0, before: nil) }
                ) { handleBottomDrop($0) }
                .onChange(of: isBottomTargeted) { _, targeted in
                    if canAcceptBottomDrop, targeted {
                        withAnimation(BillingHubBoardMotion.quick) { targetedCardID = nil }
                    }
                }
            }
            .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
        }
        .animation(BillingHubBoardMotion.quick, value: targetedCardID)
        .resetBillingHubTargetOnDragEnd(interactionState.isDragActive) {
            targetedCardID = nil
            isTopTargeted = false
            isBottomTargeted = false
        }
    }

    private func shouldHighlightSeparator(for index: Int) -> Bool {
        guard let targetedCardID, index < cards.count - 1 else { return false }
        return cards[index + 1].id == targetedCardID
    }

    private func acceptsItem(_ dragKind: BillingHubBoardDragKind, before targetID: UUID?) -> Bool {
        dropPolicy.allows(dragKind) && canAcceptDrop(dragKind, targetID)
    }

    private var canAcceptTopDrop: Bool {
        guard let dragKind = interactionState.activeDragKind else { return false }
        return acceptsItem(dragKind, before: cards.first?.id)
    }

    private var canAcceptBottomDrop: Bool {
        guard let dragKind = interactionState.activeDragKind else { return false }
        return acceptsItem(dragKind, before: nil)
    }

    @MainActor
    private func handleCardDrop(_ dragKind: BillingHubBoardDragKind, before targetID: UUID) {
        guard acceptsItem(dragKind, before: targetID) else { return }
        let accepted: Bool
        switch dragKind {
        case .session(let id) where dropPolicy.allows(dragKind):
            accepted = onReorderBetween(id, targetID, nil)
        case .invoice(let id) where dropPolicy.allows(dragKind):
            accepted = onReorderBetween(id, targetID, nil)
        default:
            accepted = false
        }
        if accepted {
            interactionState.endDrag()
        } else {
            interactionState.lastRejectedDropID = targetID
        }
    }

    @MainActor
    private func handleTopDrop(_ dragKind: BillingHubBoardDragKind) {
        guard let first = cards.first else { return handleBottomDrop(dragKind) }
        guard acceptsItem(dragKind, before: first.id) else { return }
        handleCardDrop(dragKind, before: first.id)
    }

    @MainActor
    private func handleBottomDrop(_ dragKind: BillingHubBoardDragKind) {
        guard acceptsItem(dragKind, before: nil) else { return }
        let accepted: Bool
        switch dragKind {
        case .session(let id) where dropPolicy.allows(dragKind):
            accepted = onReorderBetween(id, nil, nil)
        case .invoice(let id) where dropPolicy.allows(dragKind):
            accepted = onReorderBetween(id, nil, nil)
        default:
            accepted = false
        }
        if accepted {
            interactionState.endDrag()
        } else {
            interactionState.lastRejectedDropID = nil
        }
    }
}

struct BillingHubGroupedReorderableColumn: View {
    let cardActions: KanbanCardActions
    let groups: [SessionGroup]
    @Binding var selectedCardID: UUID?
    let interactionState: BillingHubBoardInteractionState
    let canReorderSessionInColumn: (UUID, UUID?) -> Bool
    let onReorderSessionInColumn: (UUID, UUID?) -> Bool
    let canReorderSessionInGroup: (UUID, UUID?, UUID?) -> Bool
    let onReorderSessionInGroup: (UUID, UUID?, UUID?) -> Bool
    let canReorderGroup: (UUID, UUID?) -> Bool
    let onReorderGroup: (UUID, UUID?) -> Bool
    let canDropOnCard: ((UUID, UUID) -> Bool)?
    let onDropOnCard: ((UUID, UUID) -> Bool)?
    let onAddSessionToGroup: (UUID, UUID) -> Void
    let canAddSessionToGroup: (UUID, UUID) -> Bool
    let onOpenCard: (UUID) -> Void
    let searchText: String
    let emptyStateMessage: String

    @State private var targetedGroupID: UUID?
    @State private var isTopTargeted = false
    @State private var isBottomTargeted = false

    private var isListDropActive: Bool {
        guard let dragKind = interactionState.activeDragKind else { return false }
        if acceptsGroupDrop(dragKind, before: nil) {
            return true
        }
        return groups.contains { acceptsGroupDrop(dragKind, before: dragIdentifier(for: $0)) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                BillingHubCardInsertionSeparator(
                    isHighlighted: canAcceptTopDrop && isTopTargeted,
                    isVisible: isListDropActive && !groups.isEmpty
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .billingHubDropHandler(
                    targeted: $isTopTargeted,
                    interactionState: interactionState,
                    accepts: { acceptsGroupDrop($0, before: groups.first.map(dragIdentifier(for:))) }
                ) { handleTopDrop($0) }
                .onChange(of: isTopTargeted) { _, targeted in
                    withAnimation(BillingHubBoardMotion.quick) {
                        if canAcceptTopDrop, targeted {
                            targetedGroupID = groups.first.map(dragIdentifier(for:))
                        } else if targetedGroupID == groups.first.map(dragIdentifier(for:)) {
                            targetedGroupID = nil
                        }
                    }
                }

                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    VStack(spacing: 0) {
                        BillingHubGroupItemWrapper(
                            cardActions: cardActions,
                            group: group,
                            targetedGroupID: $targetedGroupID,
                            interactionState: interactionState,
                            canAcceptGroupDrop: canReorderGroup,
                            onReorderSessionInGroup: onReorderSessionInGroup,
                            onReorderGroup: onReorderGroup,
                            canDropOnCard: canDropOnCard,
                            onDropOnCard: onDropOnCard,
                            onAddSessionToGroup: onAddSessionToGroup,
                            canAddSessionToGroup: canAddSessionToGroup,
                            selectedCardID: $selectedCardID,
                            onOpenCard: onOpenCard,
                            searchText: searchText
                        )
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)

                        if index < groups.count - 1 {
                            BillingHubGroupedColumnInsertionLane(
                                beforeTargetID: dragIdentifier(for: groups[index + 1]),
                                targetedGroupID: $targetedGroupID,
                                interactionState: interactionState,
                                acceptsDrop: acceptsGroupDrop(_:before:),
                                onDrop: handleGroupDrop
                            )
                        }
                    }
                }

                BillingHubBottomDropZone(
                    isTargeted: canAcceptBottomDrop && targetedGroupID == nil && isBottomTargeted,
                    isEmpty: groups.isEmpty,
                    isVisible: isListDropActive || groups.isEmpty,
                    emptyLabel: emptyStateMessage,
                    targetedLabel: "Move to end"
                )
                .billingHubDropHandler(
                    targeted: $isBottomTargeted,
                    interactionState: interactionState,
                    accepts: { acceptsGroupDrop($0, before: nil) }
                ) { handleBottomDrop($0) }
                .onChange(of: isBottomTargeted) { _, targeted in
                    if canAcceptBottomDrop, targeted {
                        withAnimation(BillingHubBoardMotion.quick) { targetedGroupID = nil }
                    }
                }
            }
            .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
        }
        .animation(BillingHubBoardMotion.quick, value: targetedGroupID)
        .resetBillingHubTargetOnDragEnd(interactionState.isDragActive) {
            targetedGroupID = nil
            isTopTargeted = false
            isBottomTargeted = false
        }
    }

    private func dragIdentifier(for group: SessionGroup) -> UUID {
        group.groupID ?? group.sessions.first?.id ?? group.id
    }

    private var canAcceptTopDrop: Bool {
        guard let dragKind = interactionState.activeDragKind else { return false }
        return acceptsGroupDrop(dragKind, before: groups.first.map(dragIdentifier(for:)))
    }

    private var canAcceptBottomDrop: Bool {
        guard let dragKind = interactionState.activeDragKind else { return false }
        return acceptsGroupDrop(dragKind, before: nil)
    }

    private func acceptsGroupDrop(_ dragKind: BillingHubBoardDragKind, before targetID: UUID?) -> Bool {
        switch dragKind {
        case .group(let groupID):
            return canReorderGroup(groupID, targetID)
        case .session(let sessionID):
            return canReorderSessionInColumn(sessionID, targetID)
        case .invoice:
            return false
        }
    }

    @MainActor
    private func handleTopDrop(_ dragKind: BillingHubBoardDragKind) {
        guard let first = groups.first else { return handleBottomDrop(dragKind) }
        guard acceptsGroupDrop(dragKind, before: dragIdentifier(for: first)) else { return }
        handleGroupDrop(dragKind, before: dragIdentifier(for: first))
    }

    @MainActor
    private func handleBottomDrop(_ dragKind: BillingHubBoardDragKind) {
        guard acceptsGroupDrop(dragKind, before: nil) else { return }
        handleGroupDrop(dragKind, before: nil)
    }

    @MainActor
    private func handleGroupDrop(_ dragKind: BillingHubBoardDragKind, before targetID: UUID?) {
        guard acceptsGroupDrop(dragKind, before: targetID) else { return }
        let accepted: Bool
        switch dragKind {
        case .group(let id):
            accepted = onReorderGroup(id, targetID)
        case .session(let id):
            accepted = onReorderSessionInColumn(id, targetID)
        case .invoice:
            accepted = false
        }
        if accepted {
            interactionState.endDrag()
        } else if let targetID {
            interactionState.lastRejectedDropID = targetID
        }
    }
}
