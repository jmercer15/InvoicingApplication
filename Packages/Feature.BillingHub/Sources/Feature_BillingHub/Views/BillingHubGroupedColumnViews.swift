import SwiftUI
import SharedUI

struct BillingHubGroupItemWrapper: View {
    let cardActions: KanbanCardActions
    let group: SessionGroup
    @Binding var targetedGroupID: UUID?
    let interactionState: BillingHubBoardInteractionState
    let canAcceptGroupDrop: (UUID, UUID?) -> Bool
    let onReorderSessionInGroup: (UUID, UUID?, UUID?) -> Bool
    let onReorderGroup: (UUID, UUID?) -> Bool
    let canDropOnCard: ((UUID, UUID) -> Bool)?
    let onDropOnCard: ((UUID, UUID) -> Bool)?
    let onAddSessionToGroup: (UUID, UUID) -> Void
    let canAddSessionToGroup: (UUID, UUID) -> Bool
    @Binding var selectedCardID: UUID?
    let onOpenCard: (UUID) -> Void
    let searchText: String

    @State private var isItemTargeted = false

    private var dragIdentifier: UUID {
        group.groupID ?? group.sessions.first?.id ?? group.id
    }

    private var isListDropActive: Bool {
        guard case let .group(groupID) = interactionState.activeDragKind else { return false }
        return canAcceptGroupDrop(groupID, dragIdentifier)
    }

    var body: some View {
        BillingHubGroupView(
            cardActions: cardActions,
            group: group,
            selectedCardID: $selectedCardID,
            isDropTargeted: isListDropActive && isItemTargeted,
            interactionState: interactionState,
            canDropOnCard: canDropOnCard,
            canReorderSessionInGroup: onReorderSessionInGroup,
            onReorderSessionInGroup: onReorderSessionInGroup,
            onDropOnCard: onDropOnCard,
            onAddSessionToGroup: onAddSessionToGroup,
            canAddSessionToGroup: canAddSessionToGroup,
            onOpenCard: onOpenCard,
            searchText: searchText
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .billingHubDropHandler(
            targeted: $isItemTargeted,
            interactionState: interactionState,
            accepts: acceptsItem(_:)
        ) { dragKind in
            handleDrop(dragKind)
        }
        .onChange(of: isItemTargeted) { _, targeted in
            withAnimation(BillingHubBoardMotion.quick) {
                if isListDropActive, targeted {
                    targetedGroupID = dragIdentifier
                } else if targetedGroupID == dragIdentifier {
                    targetedGroupID = nil
                }
            }
        }
        .resetBillingHubTargetOnDragEnd(interactionState.isDragActive) {
            isItemTargeted = false
            if targetedGroupID == dragIdentifier {
                targetedGroupID = nil
            }
        }
    }

    private func acceptsItem(_ dragKind: BillingHubBoardDragKind) -> Bool {
        switch dragKind {
        case .group(let groupID):
            return canAcceptGroupDrop(groupID, dragIdentifier)
        case .session:
            return false
        case .invoice:
            return false
        }
    }

    @MainActor
    private func handleDrop(_ dragKind: BillingHubBoardDragKind) {
        let accepted: Bool
        switch dragKind {
        case .group(let id):
            accepted = onReorderGroup(id, dragIdentifier)
        case .session(let id):
            _ = id
            accepted = false
        case .invoice:
            accepted = false
        }
        if accepted {
            interactionState.endDrag()
        } else {
            interactionState.lastRejectedDropID = dragIdentifier
        }
    }
}

struct BillingHubGroupedColumnInsertionLane: View {
    let beforeTargetID: UUID
    @Binding var targetedGroupID: UUID?
    let interactionState: BillingHubBoardInteractionState
    let acceptsDrop: (BillingHubBoardDragKind, UUID?) -> Bool
    let onDrop: (BillingHubBoardDragKind, UUID?) -> Void

    @State private var isTargeted = false

    private var isVisible: Bool {
        acceptsCurrentDrop
    }

    private var isHighlighted: Bool {
        acceptsCurrentDrop && (isTargeted || targetedGroupID == beforeTargetID)
    }

    var body: some View {
        BillingHubCardInsertionSeparator(
            isHighlighted: isHighlighted,
            isVisible: isVisible
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .billingHubDropHandler(
            targeted: $isTargeted,
            interactionState: interactionState,
            accepts: { acceptsDrop($0, beforeTargetID) }
        ) { dragKind in
            onDrop(dragKind, beforeTargetID)
        }
        .onChange(of: isTargeted) { _, targeted in
            withAnimation(BillingHubBoardMotion.quick) {
                if acceptsCurrentDrop, targeted {
                    targetedGroupID = beforeTargetID
                } else if targetedGroupID == beforeTargetID {
                    targetedGroupID = nil
                }
            }
        }
        .resetBillingHubTargetOnDragEnd(interactionState.isDragActive) {
            isTargeted = false
            if targetedGroupID == beforeTargetID {
                targetedGroupID = nil
            }
        }
    }

    private var acceptsCurrentDrop: Bool {
        guard let dragKind = interactionState.activeDragKind else { return false }
        return acceptsDrop(dragKind, beforeTargetID)
    }
}

struct BillingHubGroupView: View {
    let cardActions: KanbanCardActions
    let group: SessionGroup
    @Binding var selectedCardID: UUID?
    let isDropTargeted: Bool
    let interactionState: BillingHubBoardInteractionState
    let canDropOnCard: ((UUID, UUID) -> Bool)?
    let canReorderSessionInGroup: (UUID, UUID?, UUID?) -> Bool
    let onReorderSessionInGroup: (UUID, UUID?, UUID?) -> Bool
    let onDropOnCard: ((UUID, UUID) -> Bool)?
    let onAddSessionToGroup: (UUID, UUID) -> Void
    let canAddSessionToGroup: (UUID, UUID) -> Bool
    let onOpenCard: (UUID) -> Void
    let searchText: String

    private var previewItem: BillingHubBoardTransferItem {
        BillingHubBoardTransferItem.previewItem(for: group)
    }

    private var dragKind: BillingHubBoardDragKind {
        previewItem.dragKind
    }

    private var isBeingDragged: Bool {
        interactionState.activeDragKind == dragKind
    }

    private var hostID: UUID {
        group.groupID ?? group.sessions.first?.id ?? group.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BillingHubGroupSessionSection(
                cardActions: cardActions,
                group: group,
                selectedCardID: $selectedCardID,
                interactionState: interactionState,
                hostID: hostID,
                canDropOnCard: canDropOnCard,
                canReorderSessionInGroup: canReorderSessionInGroup,
                onReorderSessionInGroup: onReorderSessionInGroup,
                onDropOnCard: onDropOnCard,
                onAddSessionToGroup: onAddSessionToGroup,
                canAddSessionToGroup: canAddSessionToGroup,
                onOpenCard: onOpenCard,
                searchText: searchText
            )
        }
        .padding(StyleGuide.Dimensions.paddingMedium)
        .background(cardBackground)
        .opacity(isBeingDragged ? 0.55 : 1)
        .billingHubDragPointerStyle(isBeingDragged: isBeingDragged, interactionState: interactionState)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .billingHubDragSource(
            interactionState: interactionState,
            dragKind: dragKind,
            provider: {
                BillingHubBoardTransfer.provider(for: previewItem.itemID, type: dragKind.contentType)
            }
        ) {
            BillingHubBoardDragPreview(item: previewItem)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.columnCornerRadius, style: .continuous)
            .fill(
                isDropTargeted
                    ? Color.accentColor.opacity(0.08)
                    : BillingHubTheme.Surfaces.subcolumnBase
            )
            .shadow(
                color: isDropTargeted
                    ? Color.accentColor.opacity(0.12)
                    : .black.opacity(isBeingDragged ? 0.03 : 0.06),
                radius: isDropTargeted ? 5 : (isBeingDragged ? 1.5 : 2),
                x: 0,
                y: isDropTargeted ? 2 : (isBeingDragged ? 0.5 : 1)
            )
            .overlay {
                RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.columnCornerRadius, style: .continuous)
                    .stroke(
                        isDropTargeted ? Color.accentColor.opacity(0.50) : BillingHubTheme.Surfaces.cardStroke.opacity(0.35),
                        lineWidth: isDropTargeted ? 1.25 : 1
                    )
            }
    }
}

struct BillingHubGroupSessionSection: View {
    let cardActions: KanbanCardActions
    let group: SessionGroup
    @Binding var selectedCardID: UUID?
    let interactionState: BillingHubBoardInteractionState
    let hostID: UUID
    let canDropOnCard: ((UUID, UUID) -> Bool)?
    let canReorderSessionInGroup: (UUID, UUID?, UUID?) -> Bool
    let onReorderSessionInGroup: (UUID, UUID?, UUID?) -> Bool
    let onDropOnCard: ((UUID, UUID) -> Bool)?
    let onAddSessionToGroup: (UUID, UUID) -> Void
    let canAddSessionToGroup: (UUID, UUID) -> Bool
    let onOpenCard: (UUID) -> Void
    let searchText: String

    @State private var targetedSessionID: UUID?
    @State private var isTopSessionTargeted = false
    @State private var isBottomSessionTargeted = false

    private var activeDraggedSessionID: UUID? {
        guard case let .session(sessionID) = interactionState.activeDragKind else { return nil }
        return sessionID
    }

    private var shouldDisplaySessionInsertionUI: Bool {
        canAcceptCurrentSessionDrop
    }

    private var canAcceptCurrentSessionDrop: Bool {
        guard let sessionID = activeDraggedSessionID else { return false }
        if let groupID = group.groupID {
            return canReorderSessionInGroup(sessionID, nil, groupID)
        }
        guard let anchorSessionID = group.sessions.first?.id else { return false }
        return canDropOnCard?(sessionID, anchorSessionID) ?? false
    }

    private var isGroupHostActive: Bool {
        interactionState.activeGroupHostID == hostID
    }

    private var shouldShowSessionInsertionUI: Bool {
        shouldDisplaySessionInsertionUI && (interactionState.activeGroupHostID == nil || isGroupHostActive)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BillingHubGroupSessionInsertionSeparator(
                isHighlighted: canAcceptTopInsertion && shouldHighlightTopSessionSeparator,
                isVisible: shouldShowSessionInsertionUI
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .billingHubDropHandler(
                targeted: $isTopSessionTargeted,
                interactionState: interactionState,
                accepts: { acceptsDrop($0, insertIndex: 0) }
            ) { handleDrop($0, insertIndex: 0) }
            .onChange(of: isTopSessionTargeted) { _, targeted in
                updateTargetedSession(canAcceptTopInsertion && targeted, sessionID: group.sessions.first?.id)
            }

            ForEach(Array(group.sessions.enumerated()), id: \.element.id) { index, session in
                BillingHubGroupedSessionItemRow(
                    cardActions: cardActions,
                    session: session,
                    selectedCardID: $selectedCardID,
                    interactionState: interactionState,
                    showsInsertionSeparator: index < group.sessions.count - 1,
                    isInsertionSeparatorHighlighted: shouldHighlightSessionSeparator(after: index),
                    showsInsertionUI: shouldShowSessionInsertionUI,
                    insertIndex: index,
                    acceptsDrop: acceptsDrop(_:insertIndex:),
                    onInsert: handleDrop,
                    onTargetingChanged: { updateTargetedSession($0, sessionID: session.id) },
                    onOpenCard: onOpenCard,
                    searchText: searchText
                )
            }

            BillingHubGroupSessionDropZone(
                isTargeted: $isBottomSessionTargeted,
                isVisible: shouldShowSessionInsertionUI,
                acceptsDrop: acceptsAppendDrop,
                onAdd: handleAppendDrop,
                interactionState: interactionState
            )
            .onChange(of: isBottomSessionTargeted) { _, targeted in
                if canAcceptAppendInsertion && targeted { targetedSessionID = nil }
                updateGroupHostTarget()
            }
        }
        .resetBillingHubTargetOnDragEnd(interactionState.isDragActive) {
            targetedSessionID = nil
            isTopSessionTargeted = false
            isBottomSessionTargeted = false
        }
    }

    private func updateTargetedSession(_ isTargeted: Bool, sessionID: UUID?) {
        if shouldDisplaySessionInsertionUI, isTargeted {
            targetedSessionID = sessionID
        } else if targetedSessionID == sessionID {
            targetedSessionID = nil
        }
        updateGroupHostTarget()
    }

    private func updateGroupHostTarget() {
        let active = isTopSessionTargeted || isBottomSessionTargeted || targetedSessionID != nil
        if active {
            interactionState.setActiveGroupHost(hostID)
        } else if interactionState.activeGroupHostID == hostID {
            interactionState.setActiveGroupHost(nil)
        }
    }

    private func shouldHighlightSessionSeparator(after index: Int) -> Bool {
        guard shouldShowSessionInsertionUI, let targetedSessionID, index < group.sessions.count - 1 else { return false }
        return group.sessions[index + 1].id == targetedSessionID
    }

    private var shouldHighlightTopSessionSeparator: Bool {
        guard shouldShowSessionInsertionUI else { return false }
        guard let firstID = group.sessions.first?.id else { return isTopSessionTargeted }
        return isTopSessionTargeted || targetedSessionID == firstID
    }

    private var canAcceptTopInsertion: Bool {
        guard let dragKind = interactionState.activeDragKind else { return false }
        return acceptsDrop(dragKind, insertIndex: 0)
    }

    private var canAcceptAppendInsertion: Bool {
        guard let dragKind = interactionState.activeDragKind else { return false }
        return acceptsAppendDrop(dragKind)
    }

    private func acceptsDrop(_ dragKind: BillingHubBoardDragKind, insertIndex: Int) -> Bool {
        guard case let .session(sessionID) = dragKind else { return false }
        if let groupID = group.groupID {
            let beforeTargetID = insertIndex < group.sessions.count ? group.sessions[insertIndex].id : nil
            return canReorderSessionInGroup(sessionID, beforeTargetID, groupID)
        }
        guard let anchorSessionID = group.sessions.first?.id else { return false }
        return canDropOnCard?(sessionID, anchorSessionID) ?? false
    }

    private func acceptsAppendDrop(_ dragKind: BillingHubBoardDragKind) -> Bool {
        acceptsDrop(dragKind, insertIndex: group.sessions.count)
    }

    private func handleDrop(_ dragKind: BillingHubBoardDragKind, insertIndex: Int) {
        performDrop(dragKind, placement: .index(insertIndex))
    }

    private func handleAppendDrop(_ dragKind: BillingHubBoardDragKind) {
        performDrop(dragKind, placement: .end)
    }

    private func performDrop(_ dragKind: BillingHubBoardDragKind, placement: BillingHubGroupDropPlacement) {
        guard case let .session(sessionID) = dragKind else { return }

        let accepted: Bool
        if let groupID = group.groupID {
            let insertionIndex = placement.resolvedIndex(for: group.sessions.count)
            let beforeTargetID = insertionIndex < group.sessions.count ? group.sessions[insertionIndex].id : nil
            guard canReorderSessionInGroup(sessionID, beforeTargetID, groupID) else { return }
            accepted = onReorderSessionInGroup(sessionID, beforeTargetID, groupID)
        } else if let anchorSessionID = group.sessions.first?.id, sessionID != anchorSessionID {
            guard canDropOnCard?(sessionID, anchorSessionID) ?? false else { return }
            accepted = onDropOnCard?(sessionID, anchorSessionID) ?? false
        } else {
            accepted = false
        }

        if accepted {
            interactionState.endDrag()
        } else {
            interactionState.lastRejectedDropID = sessionID
        }
    }
}
